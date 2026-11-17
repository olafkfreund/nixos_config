#!/usr/bin/env python3
"""Allow only local, pinned-model chat traffic to Ollama."""

import argparse
import http.client
import http.server
import json
import os
import socket
import socketserver
import sys
import tempfile
import threading


UPSTREAM = ("127.0.0.1", 11434)
MAX_BODY = 32 * 1024 * 1024


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def invalid_constant(_value):
    raise ValueError("non-JSON number")


def upstream(method, path, body=None, headers=None):
    connection = http.client.HTTPConnection(*UPSTREAM, timeout=600)
    try:
        connection.request(
            method, path, body=body, headers={**(headers or {}), "Connection": "close"}
        )
        return connection, connection.getresponse()
    except Exception:
        connection.close()
        raise


def local_model_ok(name):
    connection, response = upstream("GET", "/api/tags")
    try:
        if response.status != 200:
            return False
        models = json.load(response)
    finally:
        connection.close()
    listed = any(
        model.get("name") == name and model.get("size", 0) > 1024**3
        for model in models.get("models", [])
    )
    body = json.dumps({"name": name}).encode()
    connection, response = upstream(
        "POST",
        "/api/show",
        body,
        {"Content-Type": "application/json", "Content-Length": str(len(body))},
    )
    try:
        if response.status != 200:
            return False
        model = json.load(response)
        return (
            listed
            and model.get("details", {}).get("format") == "gguf"
            and not model.get("remote_host")
        )
    finally:
        connection.close()


class Proxy(socketserver.StreamRequestHandler):
    def reply(self, status, body=b"", content_type="application/json"):
        self.status = status
        self.wfile.write(
            (
                f"HTTP/1.1 {status} {http.client.responses[status]}\r\n"
                f"Content-Type: {content_type}\r\nConnection: close\r\n"
                f"Content-Length: {len(body)}\r\n\r\n"
            ).encode()
        )
        self.wfile.write(body)

    def handle(self):
        # One line per request; never bodies, which hold private text.
        self.status, self.request_line, self.model_name = None, "-", "-"
        try:
            self._handle()
        finally:
            print(
                f"llm-docs-proxy: {self.request_line} model={self.model_name} "
                f"status={self.status}",
                file=sys.stderr,
                flush=True,
            )

    def _handle(self):
        self.connection.settimeout(30)
        line = self.rfile.readline(8193)
        if len(line) > 8192 or not line.endswith(b"\r\n"):
            self.reply(400)
            return
        try:
            method, path, version = line[:-2].decode("ascii").split(" ")
            self.request_line = f"{method} {path.split('?', 1)[0][:64]}"
        except (UnicodeDecodeError, ValueError):
            self.reply(400)
            return
        if version != "HTTP/1.1":
            self.reply(400)
            return
        headers = {}
        for _ in range(100):
            line = self.rfile.readline(8193)
            if len(line) > 8192 or not line.endswith(b"\r\n"):
                self.reply(400)
                return
            if line == b"\r\n":
                break
            try:
                key, value = line[:-2].decode("ascii").split(":", 1)
            except (UnicodeDecodeError, ValueError):
                self.reply(400)
                return
            key = key.strip().lower()
            if not key or key in headers:
                self.reply(400)
                return
            headers[key] = value.strip()
        else:
            self.reply(400)
            return

        if method == "GET" and path == "/v1/models":
            body = json.dumps(
                {
                    "object": "list",
                    "data": [{"id": self.server.model, "object": "model"}],
                }
            ).encode()
            self.reply(200, body)
            return
        if method != "POST" or path != "/v1/chat/completions":
            self.reply(403)
            return
        if "transfer-encoding" in headers:
            self.reply(400)
            return
        try:
            raw = headers["content-length"]
            if not raw.isdigit():
                raise ValueError("bad Content-Length")
            length = int(raw)
        except (KeyError, ValueError):
            self.reply(400)
            return
        if length < 0:
            self.reply(400)
            return
        if length > MAX_BODY:
            self.reply(413)
            return
        try:
            body = self.rfile.read(length)
            if len(body) != length:
                self.reply(400)
                return
            data = json.loads(
                body, object_pairs_hook=unique_object, parse_constant=invalid_constant
            )
        except (ValueError, UnicodeDecodeError):
            self.reply(400)
            return
        if not isinstance(data, dict):
            self.reply(400)
            return
        self.model_name = repr(data.get("model"))[:64]
        if data.get("model") != self.server.model:
            self.reply(403)
            return
        try:
            if not local_model_ok(self.server.model):
                self.reply(503)
                return
            body = json.dumps(data, separators=(",", ":")).encode()
            connection, response = upstream(
                "POST",
                path,
                body,
                {
                    "Content-Type": "application/json",
                    "Content-Length": str(len(body)),
                    "Accept": "text/event-stream, application/json",
                },
            )
        except (
            OSError,
            http.client.HTTPException,
            ValueError,
            TypeError,
            AttributeError,
        ):
            self.reply(502)
            return
        try:
            if 300 <= response.status < 400:
                self.reply(502)
                return
            self.status = response.status
            content_type = response.getheader("Content-Type", "application/json")
            self.wfile.write(
                (
                    f"HTTP/1.1 {response.status} "
                    f"{http.client.responses.get(response.status, 'Upstream')}\r\n"
                    f"Content-Type: {content_type}\r\n"
                    "Connection: close\r\n\r\n"
                ).encode()
            )
            while chunk := response.read1(65536):
                self.wfile.write(chunk)
                self.wfile.flush()
        finally:
            connection.close()


class Server(socketserver.ThreadingUnixStreamServer):
    daemon_threads = True


def serve(path, model):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    with Server(path, Proxy) as server:
        server.model = model
        try:
            server.serve_forever()
        finally:
            os.unlink(path)


def self_test():
    global UPSTREAM
    requests = []
    state = {
        "format": "gguf",
        "size": 2 * 1024**3,
        "remote_host": None,
        "answer": "plain",
    }
    model = "qwen3.8:27b"

    class Fake(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def answer(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
            requests.append((self.command, self.path, dict(self.headers), body))
            if self.path == "/api/tags":
                result = {"models": [{"name": model, "size": state["size"]}]}
            elif self.path == "/api/show":
                result = {
                    "details": {"format": state["format"]},
                    "remote_host": state["remote_host"],
                }
            else:
                result = None
            if result is None:
                payload = (
                    b"data: one\n\ndata: two\n\n"
                    if state["answer"] == "stream"
                    else b'{"answer":"plain"}'
                )
                content_type = (
                    "text/event-stream"
                    if state["answer"] == "stream"
                    else "application/json"
                )
            else:
                payload = json.dumps(result).encode()
                content_type = "application/json"
            self.send_response(
                302 if state["answer"] == "redirect" and result is None else 200
            )
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        do_GET = answer
        do_POST = answer

    with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Fake) as fake:
        UPSTREAM = fake.server_address
        threading.Thread(target=fake.serve_forever, daemon=True).start()
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "proxy.sock")
            server = Server(path, Proxy)
            server.model = model
            threading.Thread(target=server.serve_forever, daemon=True).start()

            def check(
                method,
                target,
                data=b"",
                headers=(),
                status=200,
                paths=(),
                expected=None,
                content_type=None,
            ):
                requests.clear()
                with socket.socket(socket.AF_UNIX) as client:
                    client.connect(path)
                    fields = "".join(f"{key}: {value}\r\n" for key, value in headers)
                    client.sendall(
                        (
                            f"{method} {target} HTTP/1.1\r\nHost: localhost\r\n"
                            f"{fields}\r\n"
                        ).encode()
                        + data
                    )
                    chunks = []
                    while chunk := client.recv(65536):
                        chunks.append(chunk)
                head, body = b"".join(chunks).split(b"\r\n\r\n", 1)
                assert head.startswith(f"HTTP/1.1 {status} ".encode()), head
                assert [item[1] for item in requests] == list(paths), requests
                if expected is not None:
                    assert body == expected, body
                if content_type is not None:
                    assert f"Content-Type: {content_type}".encode() in head, head
                return body

            valid = json.dumps({"model": model, "messages": []}).encode()
            post = (("Content-Length", str(len(valid))),)
            for answer, expected, content_type in (
                ("plain", b'{"answer":"plain"}', "application/json"),
                ("stream", b"data: one\n\ndata: two\n\n", "text/event-stream"),
            ):
                state["answer"] = answer
                check(
                    "POST",
                    "/v1/chat/completions",
                    valid,
                    post,
                    paths=("/api/tags", "/api/show", "/v1/chat/completions"),
                    expected=expected,
                    content_type=content_type,
                )
                forwarded = requests[-1]
                assert json.loads(forwarded[3]) == json.loads(valid)
                assert forwarded[2]["Content-Type"] == "application/json"
                assert forwarded[2]["Accept"] == "text/event-stream, application/json"
                assert forwarded[2]["Connection"] == "close"
                assert int(forwarded[2]["Content-Length"]) == len(forwarded[3])

            def invalid(data, status):
                check(
                    "POST",
                    "/v1/chat/completions",
                    data,
                    (("Content-Length", str(len(data))),),
                    status=status,
                )

            invalid(b'{"model":"other"}', 403)
            invalid((b'{"model":"' + model.encode() + b'","model":"other"}'), 400)
            invalid((b'{"model":"' + model.encode() + b'","x":{"a":1,"a":2}}'), 400)
            invalid((b'{"model":"' + model.encode() + b'","x":NaN}'), 400)
            check(
                "POST",
                "/v1/chat/completions",
                valid,
                post + (("Transfer-Encoding", "chunked"),),
                status=400,
            )
            check(
                "POST",
                "/v1/chat/completions",
                b"",
                (("Content-Length", str(MAX_BODY + 1)),),
                status=413,
            )
            invalid(b"{broken", 400)
            for method, target in (
                ("POST", "/api/pull"),
                ("POST", "/api/chat"),
                ("GET", "/v1/chat/completions"),
                ("POST", "/v1/chat/completions?x=1"),
            ):
                check(method, target, status=403)
            for key, value in (
                ("format", "safetensors"),
                ("size", 123),
                ("remote_host", "example.com"),
            ):
                old = state[key]
                state[key] = value
                check(
                    "POST",
                    "/v1/chat/completions",
                    valid,
                    post,
                    status=503,
                    paths=("/api/tags", "/api/show"),
                )
                state[key] = old
            state["answer"] = "redirect"
            check(
                "POST",
                "/v1/chat/completions",
                valid,
                post,
                status=502,
                paths=("/api/tags", "/api/show", "/v1/chat/completions"),
            )
            state["answer"] = "plain"
            models = check("GET", "/v1/models")
            assert [item["id"] for item in json.loads(models)["data"]] == [model]
            old_upstream = UPSTREAM
            UPSTREAM = ("127.0.0.1", 0)
            try:
                check("POST", "/v1/chat/completions", valid, post, status=502)
            finally:
                UPSTREAM = old_upstream
            server.shutdown()
            server.server_close()
        fake.shutdown()
    print("proxy self-test passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket")
    parser.add_argument("--model")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        if args.socket or args.model:
            parser.error("--self-test takes no other arguments")
        self_test()
    elif args.socket and args.model:
        serve(args.socket, args.model)
    else:
        parser.error("--socket and --model are required")
