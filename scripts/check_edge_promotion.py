#!/usr/bin/env python3
"""Require a successful main run's promotion artifact for the current edge head."""

import io
import json
import os
import sys
import urllib.parse
import urllib.request
import zipfile


API = "https://api.github.com/repos/olafkfreund/nixarchy"


class DropAuthOffGitHub(urllib.request.HTTPRedirectHandler):
    """An artifact download redirects to a pre-signed blob URL, which refuses a
    request that also carries the GitHub token (HTTP 401). Keep the header only
    while the redirect stays on api.github.com."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if (
            new is not None
            and urllib.parse.urlsplit(newurl).hostname != "api.github.com"
        ):
            new.remove_header("Authorization")
        return new


OPENER = urllib.request.build_opener(DropAuthOffGitHub)


def get(path):
    request = urllib.request.Request(
        API + path,
        headers={
            "Authorization": "Bearer " + os.environ["GH_TOKEN"],
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with OPENER.open(request, timeout=30) as response:
        return response.read()


def promoted(edge, runs, artifacts):
    for run in runs:
        if (
            run.get("head_branch") != "main"
            or run.get("status") != "completed"
            or run.get("conclusion") != "success"
            or run.get("event") not in ("schedule", "workflow_dispatch", "push")
        ):
            continue
        for artifact in artifacts.get(run["id"], []):
            if artifact.get("candidate_sha") == edge and artifact.get(
                "run_attempt"
            ) == run.get("run_attempt"):
                return True
    return False


def main():
    edge = json.loads(get("/git/ref/heads/edge"))["object"]["sha"]
    runs = json.loads(
        get("/actions/workflows/omarchy-edge.yml/runs?branch=main&per_page=100")
    )["workflow_runs"]
    evidence = {}
    for run in runs:
        if run.get("conclusion") != "success" or run.get("head_branch") != "main":
            continue
        items = json.loads(get(f"/actions/runs/{run['id']}/artifacts"))["artifacts"]
        for item in items:
            if item["name"] != "edge-promotion" or item["expired"]:
                continue
            archive = zipfile.ZipFile(
                io.BytesIO(get(f"/actions/artifacts/{item['id']}/zip"))
            )
            with archive.open("promotion.json") as f:
                evidence.setdefault(run["id"], []).append(json.load(f))
    if not promoted(edge, runs, evidence):
        raise SystemExit("no successful main promotion artifact matches edge")
    expected = sys.argv[1] if len(sys.argv) > 1 else None
    if expected and edge != expected:
        raise SystemExit("edge advanced or lock pin differs from promotion")
    print(edge)


if __name__ == "__main__":
    main()
