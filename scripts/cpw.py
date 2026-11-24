#!/usr/bin/env python3
"""Create, test and submit competitive programming workspaces."""
from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
from urllib.parse import urlparse


class UserError(Exception):
    pass


def validate_url(url):
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise UserError("Use an HTTPS problem URL without embedded credentials.")
    return url


def problem_name(url):
    parts = [x for x in urlparse(url).path.split("/") if x]
    if "codeforces.com" == urlparse(url).hostname:
        if "problem" in parts and "problemset" in parts:
            result = "cf-" + "-".join(parts[-2:])
        elif "problem" in parts:
            index = parts.index("problem")
            result = "cf-" + parts[index - 1] + "-" + parts[index + 1]
        else:
            raise UserError("Use a Codeforces problem URL, for example /contest/1/problem/A.")
    else:
        result = "-".join(parts[-2:]) or "problem"
    result = re.sub(r"[^A-Za-z0-9_.-]", "-", result).strip(".-")[:120]
    if not result:
        raise UserError("Could not derive a safe problem directory name.")
    return result


def create_problem(directory, url, template, tests=None):
    validate_url(url)
    directory = Path(directory)
    # Never replace an existing directory or source file.
    directory.mkdir(parents=True, exist_ok=False)
    (directory / "main.cpp").write_text(Path(template).read_text())
    (directory / ".cpw.json").write_text(json.dumps({"url": url, "language": "C++"}, indent=2) + "\n")
    (directory / ".gitignore").write_text(".build/\n.submitter_cookies.json\n.kattisrc\n.env\n")
    if tests is not None:
        write_samples(directory, tests)
    return directory.resolve()


def write_samples(directory, tests):
    if not isinstance(tests, list) or any(not isinstance(case, dict) or
        not isinstance(case.get("input"), str) or not isinstance(case.get("output"), str) for case in tests):
        raise UserError("Invalid sample test cases")
    target = Path(directory) / "test"
    target.mkdir(exist_ok=True)
    for i, case in enumerate(tests, 1):
        for key, suffix in (("input", "in"), ("output", "out")):
            (target / f"sample-{i}.{suffix}").write_text(case[key])


def import_companion(directory, url, template, tests):
    validate_url(url)
    directory = Path(directory)
    if not directory.exists():
        return create_problem(directory, url, template, tests)
    try:
        metadata = json.loads((directory / ".cpw.json").read_text())
    except (OSError, ValueError):
        raise UserError("Existing directory is not a CP workspace; refusing to overwrite it.") from None
    if metadata.get("url") != url:
        raise UserError("Existing workspace belongs to a different problem; refusing to overwrite it.")
    write_samples(directory, tests)
    return directory.resolve()


class Commands:
    def __init__(self, prefix):
        self.prefix = Path(prefix)
        try:
            self.config = json.loads((self.prefix / "config.json").read_text())
        except FileNotFoundError:
            raise UserError("Installation not found. Run bash setup.sh first.") from None
        self.env = os.environ.copy()
        self.env["PATH"] = os.pathsep.join(self.config.get("extra_paths", [])) + os.pathsep + self.env.get("PATH", "")

    def call(self, command, cwd=None):
        return subprocess.call([str(x) for x in command], cwd=cwd, env=self.env)

    def metadata(self):
        try:
            return json.loads(Path(".cpw.json").read_text())
        except FileNotFoundError:
            raise UserError("Run this command inside a directory created by cpw new or cpw receive.") from None

    def samples(self, args):
        url = validate_url(self.metadata()["url"])
        code = self.call([self.config["oj"], "download", url, "-d", "test"])
        if code:
            print("Sample download failed. For browser-protected pages, use cpw receive with Competitive Companion.", file=sys.stderr)
        return code

    def new(self, args):
        url = validate_url(args.url)
        directory = create_problem(args.directory or problem_name(url), url, self.prefix / "share/main.cpp")
        print(f"Created {directory}", flush=True)
        if args.no_download:
            return 0
        code = self.call([self.config["oj"], "download", url, "-d", directory / "test"])
        if code:
            print("Workspace kept. Import samples with cpw receive, or retry cpw samples in this directory.", file=sys.stderr)
        return code

    def test(self, args):
        self.metadata()
        if not Path("test").is_dir() or not list(Path("test").glob("*.in")):
            raise UserError("No sample inputs. Run cpw samples or cpw receive first.")
        build = Path(".build")
        build.mkdir(exist_ok=True)
        binary = (build / ("main.exe" if os.name == "nt" else "main")).resolve()
        flags = ["-std=c++17", "-Wall", "-Wextra", "-Wshadow"]
        if args.sanitize:
            if os.name == "nt":
                raise UserError("This sanitizer mode requires Linux/macOS; on Windows use WSL.")
            flags += ["-g", "-O1", "-fsanitize=address,undefined", "-fno-omit-frame-pointer"]
        else:
            flags += ["-O2"]
        compiler = shlex.split(os.environ["CPW_CXX"]) if "CPW_CXX" in os.environ else [self.config["compiler"]]
        code = self.call(compiler + flags + ["main.cpp", "-o", str(binary)])
        if code:
            return code
        command = subprocess.list2cmdline([str(binary)]) if os.name == "nt" else shlex.quote(str(binary))
        return self.call([self.config["oj"], "test", "-d", "test", "-c", command, "-t", str(args.timeout)])

    def submit(self, args):
        meta = self.metadata()
        source = Path(args.file).resolve()
        if not source.is_file():
            raise UserError(f"Source file not found: {source}")
        # Use the same private working directory for login and submission credentials.
        return self.call([self.config["submitter"], validate_url(meta["url"]),
                          args.language or meta["language"], source], cwd=self.prefix / "state")

    def login(self, args):
        return self.call([self.config["submitter"], "login", args.site], cwd=self.prefix / "state")

    def forward(self, args):
        if args.command == "cf":
            if "cf" not in self.config:
                raise UserError("cf-tool is omitted by --minimal. Rerun setup without --minimal.")
            command = [self.config["cf"]]
        elif args.command == "kattis":
            command = [self.config["python"], self.config["kattis"]]
        else:
            if "bridge_cli" not in self.config:
                raise UserError("Chrome bridge requires the full setup profile.")
            command = [self.config["node"], self.config["bridge_cli"]]
        return self.call(command + args.arguments)

    def doctor(self, args):
        missing = []
        for key in ("compiler", "python", "oj", "submitter", "kattis"):
            exists = Path(self.config[key]).is_file()
            print(f"{'OK     ' if exists else 'MISSING'} {key}: {self.config[key]}")
            if not exists:
                missing.append(key)
        for key in ("cf", "bridge_cli", "submitter_extension", "chrome_extension"):
            if key in self.config:
                exists = Path(self.config[key]).exists()
                print(f"{'OK     ' if exists else 'MISSING'} {key}: {self.config[key]}")
                if not exists:
                    missing.append(key)
        print("Account login and browser activation are separate steps; see NEXT_STEPS.txt.")
        if args.browser:
            if "cf" not in self.config:
                raise UserError("Browser check requires the full setup profile.")
            if self.call([self.config["cf"], "mcp-ping"]):
                missing.append("browser connection")
        return 1 if missing else 0

    def receive(self, args):
        """Listen on loopback for Competitive Companion; imports samples without scraping."""
        commands = self
        base = Path(args.directory).resolve()

        class Receiver(BaseHTTPRequestHandler):
            def do_POST(self):
                try:
                    size = int(self.headers.get("Content-Length", "0"))
                except ValueError:
                    self.send_error(400, "Invalid Content-Length")
                    return
                if size <= 0 or size > 4 * 1024 * 1024:
                    self.send_error(413, "Expected JSON, maximum 4 MiB")
                    return
                try:
                    data = json.loads(self.rfile.read(size))
                    url = validate_url(data["url"])
                    cases = data["tests"]
                    target = (base / problem_name(url)).resolve()
                    if not target.is_relative_to(base):
                        raise UserError("Import destination must stay inside the selected directory")
                    directory = import_companion(target, url, commands.prefix / "share/main.cpp", cases)
                except (ValueError, KeyError, TypeError, IndexError, UserError, OSError) as error:
                    self.send_error(400, str(error))
                    return
                print(f"Imported {directory}", flush=True)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"ok":true}')

            def log_message(self, format, *values):
                pass  # Never log problem content or cookies.

        print(f"Listening on 127.0.0.1:{args.port}. Add port {args.port} to Competitive Companion Custom ports.", flush=True)
        print(f"Import destination: {base}. Ctrl+C to stop.", flush=True)
        with HTTPServer(("127.0.0.1", args.port), Receiver) as server:
            if args.once:
                server.handle_request()
            else:
                server.serve_forever()
        return 0


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    new = commands.add_parser("new", help="Create a problem workspace and download samples")
    new.add_argument("url")
    new.add_argument("directory", nargs="?")
    new.add_argument("--no-download", action="store_true")
    commands.add_parser("samples", help="Download samples for this workspace")
    test = commands.add_parser("test", help="Compile C++17 and run local samples")
    test.add_argument("--sanitize", action="store_true")
    test.add_argument("--timeout", type=float, default=2)
    submit = commands.add_parser("submit", help="Submit this workspace with submitter")
    submit.add_argument("file", nargs="?", default="main.cpp")
    submit.add_argument("--language", help='Judge/compiler language, for example "C++"')
    login = commands.add_parser("login", help="Authenticate interactively; secrets stay outside the repo")
    login.add_argument("site")
    doctor = commands.add_parser("doctor", help="Check installed files; optionally check browser bridge")
    doctor.add_argument("--browser", action="store_true")
    receiver = commands.add_parser("receive", help="Receive samples from Competitive Companion")
    receiver.add_argument("--directory", default=".")
    receiver.add_argument("--port", type=int, default=10043)
    receiver.add_argument("--once", action="store_true")
    for name in ("cf", "kattis", "bridge"):
        forward = commands.add_parser(name, help=f"Forward arguments to {name}")
        forward.add_argument("arguments", nargs=argparse.REMAINDER)
    return result


def main(argv=None, prefix=None):
    args = parser().parse_args(argv)
    try:
        commands = Commands(prefix or Path(__file__).resolve().parents[1])
        method = "forward" if args.command in ("cf", "kattis", "bridge") else args.command
        return getattr(commands, method)(args)
    except (UserError, OSError, ValueError, KeyError, IndexError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
