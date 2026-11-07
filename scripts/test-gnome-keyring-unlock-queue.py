#!/usr/bin/env python3
"""Isolated D-Bus reproducer for gnome-keyring's unlock prompt queue."""

import argparse
import asyncio
import base64
import configparser
import os
from pathlib import Path
import re
import signal
import sys

from cryptography.hazmat.primitives import hashes, padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from dbus_next import Message, MessageFlag, MessageType, Variant
from dbus_next.aio import MessageBus

SERVICE = "org.freedesktop.secrets"
PATH = "/org/freedesktop/secrets"
PROMPTER = "org.gnome.keyring.SystemPrompter"
PROMPTER_PATH = "/org/gnome/keyring/Prompter"
PROMPTER_IFACE = "org.gnome.keyring.internal.Prompter"
CALLBACK_IFACE = "org.gnome.keyring.internal.Prompter.Callback"
INTERNAL = "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface"
PASSWORD = b"queue-lab-password"
# RFC 3526 group 5, also egg-dh.c's ietf-ike-grp-modp-1536.
PRIME = int(
    """FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E08
8A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B
0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B
0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45
B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DC
A3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08
CA237327FFFFFFFFFFFFFFFF""".replace("\n", ""),
    16,
)


def exchange_data(**fields):
    return "[sx-aes-1]\n" + "".join(
        f"{key}={base64.b64encode(value).decode()}\n" for key, value in fields.items()
    )


def exchange_public(data):
    parser = configparser.ConfigParser(interpolation=None)
    parser.read_string(data)
    return int.from_bytes(base64.b64decode(parser["sx-aes-1"]["public"]), "big")


class Exchange:
    def __init__(self):
        self.private = int.from_bytes(os.urandom(192), "big") % (PRIME - 2) + 2
        public = pow(2, self.private, PRIME)
        self.public = public.to_bytes((public.bit_length() + 7) // 8, "big")

    def begin(self):
        return exchange_data(public=self.public)

    def answer(self, peer_data, password=None):
        peer = exchange_public(peer_data)
        if not 2 <= peer <= PRIME - 2:
            raise ValueError("invalid secret exchange public key")
        shared = pow(peer, self.private, PRIME)
        raw = shared.to_bytes((shared.bit_length() + 7) // 8, "big")
        key = HKDF(algorithm=hashes.SHA256(), length=16, salt=None, info=None).derive(
            raw
        )
        if password is None:
            return self.begin()
        iv = os.urandom(16)
        padder = padding.PKCS7(128).padder()
        padded = padder.update(password) + padder.finalize()
        encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
        secret = encryptor.update(padded) + encryptor.finalize()
        return exchange_data(public=self.public, secret=secret, iv=iv)


class Lab:
    def __init__(self, bus, process):
        self.bus = bus
        self.process = process
        self.owner = None
        self.dialogs = asyncio.Queue()
        self.active = None
        self.waiting = []
        self.exchanges = {}
        self.completed = {}
        self.prompts = {}
        self.collections = {}
        self.errors = []
        self.dialog_count = 0
        bus.add_message_handler(self.on_message)

    async def call(self, destination, path, interface, member, signature="", body=None):
        reply = await asyncio.wait_for(
            self.bus.call(
                Message(
                    destination=destination,
                    path=path,
                    interface=interface,
                    member=member,
                    signature=signature,
                    body=body or [],
                    flags=MessageFlag.NO_AUTOSTART,
                )
            ),
            10,
        )
        if reply is None or reply.message_type == MessageType.ERROR:
            raise RuntimeError(f"{member}: {reply.error_name if reply else 'no reply'}")
        return reply.body

    async def secret_call(self, path, interface, member, signature="", body=None):
        return await self.call(SERVICE, path, interface, member, signature, body)

    async def callback(self, sender, path, member, signature="", body=None):
        await self.call(sender, path, CALLBACK_IFACE, member, signature, body)

    def on_message(self, message):
        if (
            message.message_type == MessageType.SIGNAL
            and message.interface == "org.freedesktop.Secret.Prompt"
            and message.member == "Completed"
        ):
            if message.path in self.completed:
                self.errors.append("duplicate Completed")
            self.completed[message.path] = message.body[0]
            return False
        if (
            message.message_type != MessageType.METHOD_CALL
            or message.path != PROMPTER_PATH
            or message.interface != PROMPTER_IFACE
        ):
            return False
        asyncio.create_task(self.handle_prompter(message))
        return True

    async def handle_prompter(self, message):
        try:
            sender = message.sender
            path = message.body[0]
            self.bus.send(Message.new_method_return(message))
            if message.member == "BeginPrompting":
                self.waiting.append((sender, path))
                await self.next_ready()
            elif message.member == "PerformPrompt":
                if self.active != (sender, path) or message.body[1] != "password":
                    raise ValueError("unexpected or overlapping dialog")
                self.dialog_count += 1
                self.dialogs.put_nowait((sender, path, message.body[3]))
            elif message.member == "StopPrompting":
                if self.active == (sender, path):
                    self.active = None
                else:
                    self.waiting.remove((sender, path))
                self.exchanges.pop((sender, path), None)
                try:
                    await self.callback(sender, path, "PromptDone")
                except RuntimeError:
                    pass  # as gcr's prompter: the callback may already be gone
                await self.next_ready()
            else:
                raise ValueError(f"unexpected prompter method {message.member}")
        except Exception as exc:
            self.errors.append(str(exc))

    async def next_ready(self):
        if self.active is not None or not self.waiting:
            return
        self.active = self.waiting.pop(0)
        self.exchanges[self.active] = Exchange()
        sender, path = self.active
        await self.callback(
            sender,
            path,
            "PromptReady",
            "sa{sv}s",
            ["", {}, self.exchanges[self.active].begin()],
        )

    async def dialog(self):
        return await asyncio.wait_for(self.dialogs.get(), 10)

    async def answer(self, dialog, cancel=False):
        sender, path, exchange = dialog
        if self.active != (sender, path):
            raise ValueError("dialog is no longer active")
        reply = self.exchanges[self.active].answer(
            exchange, None if cancel else PASSWORD
        )
        await self.callback(
            sender,
            path,
            "PromptReady",
            "sa{sv}s",
            ["no" if cancel else "yes", {}, reply],
        )

    async def wait_completed(self, path, dismissed):
        for _ in range(100):
            if path in self.completed:
                if self.completed[path] != dismissed:
                    raise ValueError(f"wrong dismissed value for {path}")
                return
            if self.errors:
                raise ValueError(self.errors[0])
            await asyncio.sleep(0.1)
        raise TimeoutError(f"missing Completed for {path}")

    async def setup(self):
        for _ in range(100):
            if self.process.returncode is not None:
                raise RuntimeError("daemon exited before owning its bus name")
            try:
                self.owner = (
                    await self.call(
                        "org.freedesktop.DBus",
                        "/org/freedesktop/DBus",
                        "org.freedesktop.DBus",
                        "GetNameOwner",
                        "s",
                        [SERVICE],
                    )
                )[0]
                break
            except RuntimeError:
                await asyncio.sleep(0.1)
        if self.owner is None:
            raise TimeoutError("daemon did not acquire bus name")
        pid = (
            await self.call(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                "GetConnectionUnixProcessID",
                "s",
                [self.owner],
            )
        )[0]
        if pid != self.process.pid:
            raise ValueError(
                f"bus name owned by PID {pid}, daemon is {self.process.pid}"
            )
        await self.call(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "RequestName",
            "su",
            [PROMPTER, 4],
        )
        await self.call(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "AddMatch",
            "s",
            [
                f"type='signal',sender='{self.owner}',interface='org.freedesktop.Secret.Prompt',member='Completed'"
            ],
        )
        session = (
            await self.secret_call(
                PATH,
                "org.freedesktop.Secret.Service",
                "OpenSession",
                "sv",
                ["plain", Variant("s", "")],
            )
        )[1]
        master = [session, b"", PASSWORD, "text/plain"]
        self.master = master
        collection = await self.create_collection("login")
        locked, prompt = await self.secret_call(
            PATH, "org.freedesktop.Secret.Service", "Lock", "ao", [[collection]]
        )
        if collection not in locked or prompt != "/":
            raise ValueError("collection was not locked immediately")
        self.collection = collection

    async def create_collection(self, label):
        collection = (
            await self.secret_call(
                PATH,
                INTERNAL,
                "CreateWithMasterPassword",
                "a{sv}(oayays)",
                [
                    {"org.freedesktop.Secret.Collection.Label": Variant("s", label)},
                    self.master,
                ],
            )
        )[0]
        if collection == "/":
            raise ValueError(f"{label} collection was not created")
        if label != "login":
            locked, prompt = await self.secret_call(
                PATH, "org.freedesktop.Secret.Service", "Lock", "ao", [[collection]]
            )
            if collection not in locked or prompt != "/":
                raise ValueError(f"{label} collection was not locked")
        return collection

    async def new_prompt(self, label):
        collection = self.collections.get(label, self.collection)
        unlocked, path = await self.secret_call(
            PATH, "org.freedesktop.Secret.Service", "Unlock", "ao", [[collection]]
        )
        if unlocked or path == "/":
            raise ValueError(f"{label} did not receive a prompt")
        self.prompts[label] = path
        return path

    async def start_prompt(self, label):
        path = self.prompts[label]
        await self.secret_call(
            path, "org.freedesktop.Secret.Prompt", "Prompt", "s", [""]
        )

    async def external_unlock(self):
        await self.secret_call(
            PATH,
            INTERNAL,
            "UnlockWithMasterPassword",
            "o(oayays)",
            [self.collection, self.master],
        )

    async def check_unlocked(self):
        value = (
            await self.secret_call(
                self.collection,
                "org.freedesktop.DBus.Properties",
                "Get",
                "ss",
                ["org.freedesktop.Secret.Collection", "Locked"],
            )
        )[0]
        if value.value:
            raise ValueError("login remains locked")

    async def scenario(self, name):
        await self.setup()
        await self.new_prompt("A")
        await self.start_prompt("A")
        first = await self.dialog()
        if name == "normal":
            await self.answer(first)
            await self.wait_completed(self.prompts["A"], False)
            await self.check_unlocked()
        elif name == "abort":
            await self.new_prompt("B")
            await self.external_unlock()
            await self.start_prompt("B")
            await self.wait_completed(self.prompts["B"], False)
            if self.active != first[:2]:
                raise ValueError("A dialog closed before B completed")
            await self.answer(first)
            await self.wait_completed(self.prompts["A"], False)
        elif name == "hang":
            for label in ("B", "C"):
                self.collections[label] = await self.create_collection(label)
                await self.new_prompt(label)
                await self.start_prompt(label)
            await self.answer(first, cancel=True)
            await self.wait_completed(self.prompts["A"], True)
            for label in ("B", "C"):
                dialog = await self.dialog()
                if not self.dialogs.empty():
                    raise ValueError("two dialogs appeared together")
                await self.answer(dialog)
                await self.wait_completed(self.prompts[label], False)
        elif name == "dismiss":
            # B needs its own collection, or A's late unlock would satisfy it without a dialog.
            self.collections["B"] = await self.create_collection("B")
            await self.new_prompt("B")
            await self.start_prompt("B")
            await self.secret_call(
                self.prompts["A"], "org.freedesktop.Secret.Prompt", "Dismiss"
            )
            await self.wait_completed(self.prompts["A"], True)
            # Dismiss cannot close a dialog already shown; answering it now is a late success.
            if self.active == first[:2]:
                await self.answer(first)
            await self.answer(await self.dialog())
            await self.wait_completed(self.prompts["B"], False)
        elif name == "many":
            for index in range(20):
                label = f"B{index}"
                await self.new_prompt(label)
                await self.start_prompt(label)
            await self.external_unlock()
            await self.answer(first)
            for path in self.prompts.values():
                await self.wait_completed(path, False)
            if self.dialog_count != 1:
                raise ValueError("unexpected additional dialog")
        else:
            raise ValueError(f"unknown scenario {name}")
        if self.errors:
            raise ValueError(self.errors[0])
        if self.process.returncode is not None:
            raise ValueError("daemon exited unexpectedly")


def classify(process, log, lab, error):
    if process.returncode == -signal.SIGABRT and re.search(
        r"perform_next_unlock|!self->current", log
    ):
        return "ABORT"
    if error is None:
        return "OK"
    if (
        isinstance(error, TimeoutError)
        and process.returncode is None
        and lab is not None
        and lab.active is None
        and lab.dialogs.empty()
        and len(lab.completed) < len(lab.prompts)
    ):
        return "HANG"
    print(f"lab: {error}", file=sys.stderr)
    return "INCONCLUSIVE"


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("keyring")
    parser.add_argument(
        "scenario", choices=("abort", "hang", "dismiss", "many", "normal")
    )
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    lab = bus = process = None
    error = None
    with args.log.open("w") as log_file:
        try:
            process = await asyncio.create_subprocess_exec(
                f"{args.keyring}/bin/gnome-keyring-daemon",
                "--start",
                "--foreground",
                "--components=secrets",
                stdout=log_file,
                stderr=log_file,
            )
            bus = await MessageBus().connect()
            lab = Lab(bus, process)
            await lab.scenario(args.scenario)
        except Exception as exc:
            error = exc
        finally:
            if process is not None and process.returncode is None:
                try:
                    await asyncio.wait_for(process.wait(), 0.2)
                except asyncio.TimeoutError:
                    pass
            contents = args.log.read_text(errors="replace")
            result = (
                classify(process, contents, lab, error)
                if process is not None
                else "INCONCLUSIVE"
            )
            if process is not None and process.returncode is None:
                process.terminate()
                try:
                    await asyncio.wait_for(process.wait(), 2)
                except asyncio.TimeoutError:
                    process.kill()
                    await process.wait()
            if bus is not None:
                bus.disconnect()
            print(f"result={result}")


if __name__ == "__main__":
    asyncio.run(main())
