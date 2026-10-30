#!/usr/bin/env python3
"""
Push the current branch to GitHub using the REST API instead of git's transport.

Why this exists: on this network `github.com:443` is blocked (git push and even
`curl https://github.com` time out), while `api.github.com` responds normally.
`git push` cannot work, but the same content can be written through the Git Data
API: blobs -> tree -> commit -> update ref.

It compares *tree contents*, not commit ancestry, so it keeps working even though
API-created commits have different SHAs than the local ones.

Requirements:
  - `gh` installed and authenticated with `repo` scope (it already is)
  - `api.github.com` reachable

Usage:
  ./scripts/api-push.py --dry-run     # show what would change
  ./scripts/api-push.py               # push

Caveat: commits created this way get new SHAs, so local history and remote history
diverge. Content stays identical. The moment you are on a network where git works,
run `git fetch origin && git reset --hard origin/main` once and go back to normal
git.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.request

API = "https://api.github.com"


def run(*args: str, binary: bool = False):
    result = subprocess.run(args, capture_output=True)
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise SystemExit(f"command failed: {' '.join(args)}\n{message}")
    return result.stdout if binary else result.stdout.decode("utf-8", "replace")


def api(method: str, path: str, token: str, payload: dict | None = None):
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(
        f"{API}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
            "User-Agent": "bias-api-push",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        raise SystemExit(f"{method} {path} -> HTTP {error.code}\n{detail}")


def local_files() -> dict[str, tuple[str, str]]:
    """path -> (mode, blob sha) for every file in HEAD."""
    raw = run("git", "ls-tree", "-r", "-z", "HEAD", binary=True)
    files: dict[str, tuple[str, str]] = {}
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        meta, path = entry.split(b"\t", 1)
        mode, _kind, sha = meta.decode().split(" ")
        files[path.decode("utf-8")] = (mode, sha)
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    token = run("gh", "auth", "token").strip()
    owner = run("gh", "repo", "view", "--json", "owner", "--jq", ".owner.login").strip()
    repo = run("gh", "repo", "view", "--json", "name", "--jq", ".name").strip()
    branch = run("git", "rev-parse", "--abbrev-ref", "HEAD").strip()
    head = run("git", "rev-parse", "HEAD").strip()
    local_tree = run("git", "rev-parse", "HEAD^{tree}").strip()

    print(f"repo:   {owner}/{repo}@{branch}")
    print(f"local:  {head[:8]}  tree {local_tree[:8]}")

    remote_ref = api("GET", f"/repos/{owner}/{repo}/git/ref/heads/{branch}", token)
    parent = remote_ref["object"]["sha"]
    base_tree = api("GET", f"/repos/{owner}/{repo}/git/commits/{parent}", token)["tree"]["sha"]
    print(f"remote: {parent[:8]}  tree {base_tree[:8]}")

    if local_tree == base_tree:
        print("\nnothing to push — content already matches the remote")
        return 0

    remote_raw = api("GET", f"/repos/{owner}/{repo}/git/trees/{base_tree}?recursive=1", token)
    remote_files = {
        item["path"]: item["sha"]
        for item in remote_raw.get("tree", [])
        if item["type"] == "blob"
    }

    local = local_files()
    changed = sorted(p for p, (_, sha) in local.items() if remote_files.get(p) != sha)
    deleted = sorted(p for p in remote_files if p not in local)

    message = run("git", "log", "-1", "--pretty=%B", head).strip()
    print(f"commit: {message.splitlines()[0]}")
    for path in changed:
        print(f"  M {path}")
    for path in deleted:
        print(f"  D {path}")

    if not changed and not deleted:
        print("\nno file-level differences; remote content is already identical")
        return 0

    if args.dry_run:
        print("\n(dry run, nothing sent)")
        return 0

    entries = []
    for path in changed:
        content = run("git", "show", f"HEAD:{path}", binary=True)
        mode = local[path][0]
        blob = api("POST", f"/repos/{owner}/{repo}/git/blobs", token, {
            "content": content.decode("utf-8"),
            "encoding": "utf-8",
        })
        entries.append({"path": path, "mode": mode, "type": "blob", "sha": blob["sha"]})
    for path in deleted:
        entries.append({"path": path, "mode": "100644", "type": "blob", "sha": None})

    tree = api("POST", f"/repos/{owner}/{repo}/git/trees", token, {
        "base_tree": base_tree,
        "tree": entries,
    })
    commit = api("POST", f"/repos/{owner}/{repo}/git/commits", token, {
        "message": message,
        "tree": tree["sha"],
        "parents": [parent],
    })
    api("PATCH", f"/repos/{owner}/{repo}/git/refs/heads/{branch}", token, {
        "sha": commit["sha"],
        "force": False,
    })

    print(f"\npushed {commit['sha'][:8]} — CI should pick this up in a moment")
    return 0


if __name__ == "__main__":
    sys.exit(main())
