#!/usr/bin/env python3
"""Cross-platform installer. Only the main entry point has side effects."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import stat
import ssl
import datetime
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSIONS = json.loads((ROOT / "config/versions.json").read_text())
MARK_START = "# >>> cp-terminal-setup >>>"
MARK_END = "# <<< cp-terminal-setup <<<"


def host_info(system=None, machine=None):
    system = system or platform.system()
    machine = (machine or platform.machine()).lower()
    host = {"Linux": "linux", "Darwin": "darwin", "Windows": "windows"}.get(system)
    arch = {"x86_64": "amd64", "amd64": "amd64", "aarch64": "arm64", "arm64": "arm64"}.get(machine)
    if not host or not arch or (host == "windows" and arch != "amd64"):
        raise RuntimeError("Supported: Linux/macOS x64 or ARM64; Windows x64 Git Bash. For Windows ARM use ARM64 WSL.")
    return host, arch


def linux_packages(manager):
    packages = {
        "apt-get": ["git", "curl", "build-essential", "pkg-config", "libssl-dev", "libxcb1-dev", "libxcb-render0-dev", "libxcb-shape0-dev", "libxcb-xfixes0-dev", "xclip", "xdg-utils", "ripgrep", "ca-certificates"],
        "dnf": ["git", "curl", "gcc", "gcc-c++", "make", "pkgconf-pkg-config", "openssl-devel", "libxcb-devel", "xclip", "xdg-utils", "ripgrep", "ca-certificates"],
        "pacman": ["git", "curl", "base-devel", "pkgconf", "openssl", "libxcb", "xclip", "xdg-utils", "ripgrep", "ca-certificates"],
    }
    return packages[manager]


def bash_path(path):
    text = str(path).replace("\\", "/")
    if len(text) > 2 and text[1:3] == ":/":
        return "/" + text[0].lower() + text[2:]
    return text


def update_profile(path, activation):
    old = path.read_text() if path.exists() else ""
    start = old.find(MARK_START)
    if start != -1:
        end = old.find(MARK_END, start)
        if end == -1:
            raise RuntimeError(f"Incomplete setup marker in {path}; repair it before rerunning.")
        old = old[:start] + old[end + len(MARK_END):].lstrip("\n")
    block = f"{MARK_START}\n[ ! -f {shlex.quote(activation)} ] || . {shlex.quote(activation)}\n{MARK_END}\n"
    path.write_text(old.rstrip("\n") + ("\n\n" if old.strip() else "") + block, newline="\n")


def extract_archive(archive, destination):
    """Reject path traversal/symlinks in zip; tar uses Python's data filter."""
    destination.mkdir(parents=True, exist_ok=True)
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as bundle:
            for member in bundle.infolist():
                name = member.filename.replace("\\", "/")
                target = (destination / name).resolve()
                if not target.is_relative_to(destination.resolve()) or ":" in name:
                    raise RuntimeError(f"Unsafe archive path: {name}")
                if stat.S_ISLNK(member.external_attr >> 16):
                    raise RuntimeError(f"Archive symlink rejected: {name}")
            bundle.extractall(destination)
    else:
        with tarfile.open(archive) as bundle:
            bundle.extractall(destination, filter="data")


class Installer:
    def __init__(self, args):
        self.args = args
        self.prefix = Path(args.prefix).expanduser().resolve()
        # Refuse roots and the user's home itself; cleanup is restricted to owned subdirectories.
        if self.prefix == Path(self.prefix.anchor) or self.prefix == Path.home():
            raise RuntimeError("Choose a dedicated install directory, not /, a drive root, or your home directory.")
        self.host, self.arch = host_info()
        self.exe = ".exe" if self.host == "windows" else ""
        self.env = os.environ.copy()
        self.extra_paths = [self.prefix / "bin", self.prefix / "cargo/bin"]
        self.config = {"prefix": str(self.prefix), "profile": "minimal" if args.minimal else "full", "versions": VERSIONS}
        self.uv = self.prefix / "bootstrap" / ("uv" + self.exe)

    def refresh_path(self):
        self.env["PATH"] = os.pathsep.join(str(p) for p in self.extra_paths) + os.pathsep + os.environ.get("PATH", "")

    def run(self, command, cwd=None, env=None):
        print("+", shlex.join(str(x) for x in command), flush=True)
        subprocess.run([str(x) for x in command], check=True, cwd=cwd, env=env or self.env)

    def download(self, url, sha256=None, name=None):
        if not url.startswith("https://"):
            raise RuntimeError("Downloads require HTTPS.")
        cache = self.prefix / "cache/downloads"
        cache.mkdir(parents=True, exist_ok=True)
        target = cache / (name or url.rsplit("/", 1)[-1])
        if not target.exists():
            print(f"Downloading {url}", flush=True)
            request = urllib.request.Request(url, headers={"User-Agent": "cp-terminal-setup/1.0"})
            partial = target.with_name(target.name + ".partial")
            try:
                context = ssl.create_default_context()
                try:
                    import certifi
                    context.load_verify_locations(certifi.where())
                except ImportError:
                    pass
                with urllib.request.urlopen(request, timeout=90, context=context) as response, partial.open("wb") as output:
                    shutil.copyfileobj(response, output)
                partial.replace(target)
            finally:
                partial.unlink(missing_ok=True)
        if sha256:
            with target.open("rb") as stream:
                actual = hashlib.file_digest(stream, "sha256").hexdigest()
            if actual != sha256:
                target.unlink()
                raise RuntimeError(f"SHA256 mismatch for {url}; removed the cached download.")
        return target

    def archive(self, url, destination, sha256=None, name=None):
        if (destination / ".cpw-complete").exists():
            return destination
        archive = self.download(url, sha256, name)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
            staging = Path(temporary) / "extract"
            extract_archive(archive, staging)
            entries = list(staging.iterdir())
            contents = entries[0] if len(entries) == 1 and entries[0].is_dir() else staging
            # Only replace this installer's versioned destination after successful extraction.
            if destination.exists():
                shutil.rmtree(destination)
            shutil.move(str(contents), str(destination))
        (destination / ".cpw-complete").write_text(url + "\n")
        return destination

    def source(self, repository, revision):
        dest = self.prefix / "src" / (repository.split("/")[1] + "-" + revision)
        return self.archive(f"https://codeload.github.com/{repository}/tar.gz/{revision}", dest,
                            name=repository.replace("/", "-") + "-" + revision + ".tar.gz")

    def system_dependencies(self):
        if self.args.skip_system:
            print("Using existing native compiler and build libraries (--skip-system).")
            if self.host == "windows":
                self.windows_paths()
            return
        if self.host == "darwin":
            result = subprocess.run(["xcode-select", "-p"], capture_output=True)
            if result.returncode:
                subprocess.run(["xcode-select", "--install"], check=False)
                raise RuntimeError("Complete the macOS Command Line Tools dialog, then rerun setup.sh.")
        elif self.host == "linux":
            manager = next((x for x in ("apt-get", "dnf", "pacman") if shutil.which(x)), None)
            if not manager:
                raise RuntimeError("Auto-install supports apt/dnf/pacman. Install C++, OpenSSL, pkg-config and libxcb headers yourself, then use --skip-system.")
            sudo = [] if hasattr(os, "geteuid") and os.geteuid() == 0 else ["sudo"]
            if manager == "apt-get":
                self.run(sudo + [manager, "update"])
                self.run(sudo + [manager, "install", "-y"] + linux_packages(manager))
            elif manager == "dnf":
                self.run(sudo + [manager, "install", "-y"] + linux_packages(manager))
            else:
                # Full upgrade prevents an unsupported partial Arch upgrade.
                self.run(sudo + [manager, "-Syu", "--needed", "--noconfirm"] + linux_packages(manager))
        else:
            msys = Path(os.environ.get("CPW_MSYS2_ROOT", "C:/msys64"))
            bash = msys / "usr/bin/bash.exe"
            if not bash.exists():
                if msys.exists():
                    raise RuntimeError(f"{msys} exists but is not MSYS2. Set CPW_MSYS2_ROOT to a dedicated directory.")
                if " " in str(msys) or not str(msys).isascii():
                    raise RuntimeError("MSYS2 install directory must have an ASCII path without spaces.")
                installer = self.download("https://repo.msys2.org/distrib/msys2-x86_64-latest.exe")
                checksum = self.download("https://repo.msys2.org/distrib/msys2-x86_64-latest.exe.sha256")
                expected = checksum.read_text().split()[0]
                self.download("https://repo.msys2.org/distrib/msys2-x86_64-latest.exe", expected)
                self.run([installer, "in", "--confirm-command", "--accept-messages", "--root", msys.as_posix()])
            msys_env = dict(self.env, MSYSTEM="MSYS", MSYS2_PATH_TYPE="inherit", CHERE_INVOKING="1")
            # Separate processes allow MSYS2 to replace its own runtime on the first pass.
            self.run([bash, "-lc", "pacman -Syu --noconfirm"], env=msys_env)
            self.run([bash, "-lc", "pacman -Su --noconfirm"], env=msys_env)
            self.run([bash, "-lc", "pacman -S --needed --noconfirm mingw-w64-x86_64-gcc"], env=msys_env)
            self.extra_paths.insert(0, msys / "mingw64/bin")
        self.refresh_path()

    def windows_paths(self):
        msys = Path(os.environ.get("CPW_MSYS2_ROOT", "C:/msys64"))
        for path in (msys / "mingw64/bin", msys / "ucrt64/bin"):
            if (path / "g++.exe").exists():
                self.extra_paths.insert(0, path)
                break
        self.refresh_path()

    def python_tools(self):
        self.venv = self.prefix / "venv"
        self.py = self.venv / ("Scripts/python.exe" if self.host == "windows" else "bin/python")
        if not self.py.exists():
            self.run([self.uv, "venv", "--python", VERSIONS["python"], self.venv])
        self.run([self.uv, "pip", "install", "--python", self.py,
                  f"online-judge-tools=={VERSIONS['oj']}", "setuptools==80.9.0", "requests", "lxml"])
        self.config["python"] = str(self.py)
        self.config["oj"] = str(self.venv / ("Scripts/oj.exe" if self.host == "windows" else "bin/oj"))
        kattis = self.source("Kattis/kattis-cli", VERSIONS["kattis"]) / "submit.py"
        self.config["kattis"] = str(kattis)

    def submitter(self):
        source = self.source("EgorKulikov/submitter", VERSIONS["submitter"])
        cargo_home = self.prefix / "cargo"
        self.env.update(CARGO_HOME=str(cargo_home), RUSTUP_HOME=str(self.prefix / "rustup"))
        self.refresh_path()
        target = "stable-x86_64-pc-windows-gnu" if self.host == "windows" else "stable"
        rustup = cargo_home / "bin" / ("rustup" + self.exe)
        if not rustup.exists():
            if self.host == "windows":
                url = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-gnu/rustup-init.exe"
                checksum = self.download(url + ".sha256").read_text().split()[0]
                installer = self.download(url, checksum)
                self.run([installer, "-y", "--no-modify-path", "--profile", "minimal", "--default-host", "x86_64-pc-windows-gnu", "--default-toolchain", "stable"])
            else:
                installer = self.download("https://sh.rustup.rs", name="rustup-init.sh")
                self.run(["sh", installer, "-y", "--no-modify-path", "--profile", "minimal", "--default-toolchain", "stable"])
        else:
            self.run([rustup, "toolchain", "install", target, "--profile", "minimal"])
        stamp = self.prefix / "state/submitter-revision"
        executable = self.prefix / "bin" / ("submitter" + self.exe)
        if not executable.exists() or not stamp.exists() or stamp.read_text().strip() != VERSIONS["submitter"]:
            cargo = cargo_home / "bin" / ("cargo" + self.exe)
            self.run([cargo, "+" + target, "install", "--locked", "--path", source, "--root", self.prefix, "--force"])
            stamp.write_text(VERSIONS["submitter"] + "\n")
        self.config["submitter"] = str(executable)
        if not self.args.skip_extensions:
            dest = self.prefix / "extensions/submitter-helper"
            shutil.copytree(source / "extension", dest, dirs_exist_ok=True)
            self.config["submitter_extension"] = str(dest)

    def full_tools(self):
        node_os = "win" if self.host == "windows" else self.host
        node_arch = "x64" if self.arch == "amd64" else self.arch
        key = f"{node_os}-{node_arch}"
        suffix = ".zip" if self.host == "windows" else ".tar.xz"
        filename = f"node-v{VERSIONS['node']}-{key}{suffix}"
        node = self.archive(f"https://nodejs.org/dist/v{VERSIONS['node']}/{filename}",
                            self.prefix / "runtimes" / filename.removesuffix(suffix), VERSIONS["node_sha256"][key])
        node_bin = node if self.host == "windows" else node / "bin"
        self.extra_paths.insert(0, node_bin)
        self.refresh_path()
        node_executable = node_bin / ("node" + self.exe)
        npm_cli = node / ("node_modules/npm/bin/npm-cli.js" if self.host == "windows" else "lib/node_modules/npm/bin/npm-cli.js")
        bridge = self.prefix / "bridge"
        self.run([node_executable, npm_cli, "install", "--ignore-scripts", "--prefix", bridge,
                  f"mcp-chrome-bridge@{VERSIONS['bridge']}"])
        # Build the one native dependency without running the bridge registration postinstall.
        self.run([node_executable, npm_cli, "rebuild", "--prefix", bridge, "better-sqlite3"])
        package_dir = bridge / "node_modules/mcp-chrome-bridge"
        package = json.loads((package_dir / "package.json").read_text())
        binary = package["bin"]
        cli = package_dir / (binary if isinstance(binary, str) else binary["mcp-chrome-bridge"])
        if self.host != "windows":
            for name in ("index.js", "cli.js", "run_host.sh"):
                (package_dir / "dist" / name).chmod(0o755)
        if not self.args.skip_extensions:
            self.run([node_executable, cli, "register"])
        self.config.update(node=str(node_executable), bridge_cli=str(cli))
        go_key = f"{self.host}-{self.arch}"
        suffix = ".zip" if self.host == "windows" else ".tar.gz"
        filename = f"go{VERSIONS['go']}.{go_key}{suffix}"
        go = self.archive(f"https://go.dev/dl/{filename}", self.prefix / "runtimes" / f"go-{VERSIONS['go']}",
                          VERSIONS["go_sha256"][go_key])
        self.extra_paths.insert(0, go / "bin")
        self.env.update(GOPATH=str(self.prefix / "go-cache"), GOCACHE=str(self.prefix / "cache/go-build"), GOTOOLCHAIN="local")
        self.refresh_path()
        source = self.source("NetWilliam/cf-tool", VERSIONS["cf_tool"])
        executable = self.prefix / "bin" / ("cf" + self.exe)
        self.run([go / "bin" / ("go" + self.exe), "build", "-mod=readonly", "-o", executable, "."], cwd=source)
        self.config["cf"] = str(executable)
        if not self.args.skip_extensions:
            chrome = VERSIONS["chrome_extension"]
            dest = self.archive(chrome["url"], self.prefix / "extensions/chrome-mcp-v1.0.0", chrome["sha256"])
            manifests = list(dest.rglob("manifest.json"))
            roots = [x.parent for x in manifests if "node_modules" not in x.parts]
            if len(roots) != 1:
                raise RuntimeError("Cannot identify Chrome extension manifest. See extensions/ and upstream instructions.")
            self.config["chrome_extension"] = str(roots[0])

    def neovim(self):
        host_name = {"darwin": "macos", "linux": "linux", "windows": "win"}[self.host]
        arch_name = "x86_64" if self.arch == "amd64" else self.arch
        name = "nvim-win64.zip" if self.host == "windows" else f"nvim-{host_name}-{arch_name}.tar.gz"
        version = VERSIONS["nvim"]
        runtime = self.archive(f"https://github.com/neovim/neovim/releases/download/v{version}/{name}",
                               self.prefix / "runtimes" / f"nvim-{version}",
                               VERSIONS["nvim_sha256"][f"{self.host}-{self.arch}"])
        self.extra_paths.insert(0, runtime / "bin")
        self.config["nvim"] = str(runtime / "bin" / ("nvim" + self.exe))
        self.refresh_path()
        if self.host == "windows":
            config_home = Path(os.environ.get("XDG_CONFIG_HOME", os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData/Local"))))
        else:
            config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
        appname = os.environ.get("NVIM_APPNAME", "nvim")
        if not appname or Path(appname).name != appname or appname in (".", ".."):
            raise RuntimeError("NVIM_APPNAME must be a single directory name.")
        target = config_home / appname
        source = ROOT.resolve()
        if target.resolve() != source:
            if source.is_relative_to(target.resolve()):
                raise RuntimeError("The checkout is nested inside the target config. Move it elsewhere or use --no-nvim.")
            # Recognize a previous deployment from this checkout; do not replace it on every rerun.
            marker = target / ".cpw-install.json"
            managed = False
            if marker.is_file():
                try:
                    managed = json.loads(marker.read_text()).get("source") == str(source)
                except (ValueError, OSError):
                    pass
            if target.exists() and not managed:
                suffix = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
                backup = target.with_name(target.name + ".backup-" + suffix)
                target.rename(backup)
                print(f"Existing Neovim config backed up to {backup}", flush=True)
            shutil.copytree(source, target, dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns(".git", "__pycache__", ".venv", ".build", "work", "contests", ".cpw-install.json"))
        marker = target / ".cpw-install.json"
        marker.write_text(json.dumps({"prefix": str(self.prefix), "source": str(source)}, indent=2) + "\n")
        self.config["nvim_config"] = str(target)

    def finish(self):
        share = self.prefix / "share"
        share.mkdir(exist_ok=True)
        shutil.copy2(ROOT / "scripts/cpw.py", share / "cpw.py")
        shutil.copy2(ROOT / "templates/files/cpp/cp.cpp", share / "main.cpp")
        compiler = next((shutil.which(x, path=self.env["PATH"]) for x in ("g++", "clang++", "c++")
                         if shutil.which(x, path=self.env["PATH"])), None)
        if not compiler:
            raise RuntimeError("No C++ compiler found. Install one and rerun without --skip-system.")
        self.config["compiler"] = compiler
        self.config["extra_paths"] = [str(x) for x in self.extra_paths]
        (self.prefix / "config.json").write_text(json.dumps(self.config, indent=2) + "\n")
        paths = ":".join(shlex.quote(bash_path(x)) for x in self.extra_paths)
        activation = self.prefix / "env.sh"
        activation.write_text("# Generated by cp-terminal-setup\nexport CPW_PREFIX=" + shlex.quote(self.prefix.as_posix()) + "\nexport PATH=" + paths + ':"$PATH"\n', newline="\n")
        launchers = {
            "cpw": [self.py, share / "cpw.py"],
            "oj": [Path(self.config["oj"])],
            "kattis": [self.py, Path(self.config["kattis"])],
        }
        if "bridge_cli" in self.config:
            launchers["mcp-chrome-bridge"] = [Path(self.config["node"]), Path(self.config["bridge_cli"])]
        for name, command in launchers.items():
            path = self.prefix / "bin" / name
            path.write_text("#!/usr/bin/env bash\nset -e\n. " + shlex.quote(bash_path(activation)) +
                            "\nexec " + " ".join(shlex.quote(bash_path(x)) for x in command) + ' "$@"\n', newline="\n")
            path.chmod(0o755)
        if not self.args.no_shell:
            home = Path.home()
            profiles = [home / ".bashrc"]
            if self.host == "darwin":
                profiles += [home / ".zshrc", home / ".bash_profile"]
            elif self.host == "windows":
                profiles += [home / ".bash_profile" if (home / ".bash_profile").exists() or not (home / ".profile").exists() else home / ".profile"]
            elif (home / ".bash_profile").exists():
                profiles += [home / ".bash_profile"]
            for profile in profiles:
                update_profile(profile, bash_path(activation))
        # This report contains paths and public URLs only, never credentials.
        report = f"Activate in Bash/zsh:\n  source {shlex.quote(bash_path(activation))}\n\nThen:\n  cpw doctor\n  cpw login codeforces\n  cpw login atcoder\n\nCodeforces API credentials: https://codeforces.com/settings/api\nKattis: download https://open.kattis.com/download/kattisrc into ~/.kattisrc\n"
        for label in ("submitter_extension", "chrome_extension"):
            if label in self.config:
                report += f"\n{label}: {self.config[label]}\n"
        report += "\nChrome: chrome://extensions -> Developer mode -> Load unpacked.\nChrome MCP extension: click Connect after loading; then run cf mcp-ping.\nLog in to the judge in your browser. See README.md for WSL/display notes.\n"
        (self.prefix / "NEXT_STEPS.txt").write_text(report)
        print("\nSetup finished.\n" + report)

    def install(self):
        print(f"Platform: {self.host}/{self.arch}; prefix: {self.prefix}", flush=True)
        self.refresh_path()
        if self.args.dry_run:
            print("Plan: native dependencies -> isolated Python/oj/Kattis -> Rust/submitter -> " +
                  ("launchers" if self.args.minimal else "Node/Go/cf-tool/bridge/extensions -> launchers"))
            return
        for directory in ("bin", "state", "cache", "extensions"):
            (self.prefix / directory).mkdir(parents=True, exist_ok=True)
        self.system_dependencies()
        self.python_tools()
        self.submitter()
        if not self.args.minimal:
            self.full_tools()
        if not self.args.no_nvim:
            self.neovim()
        self.finish()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prefix", default=os.environ.get("CPW_PREFIX", "~/.local/share/cpw"))
    for flag in ("minimal", "skip-system", "no-shell", "skip-extensions", "no-nvim", "dry-run"):
        parser.add_argument("--" + flag, action="store_true")
    args = parser.parse_args(argv)
    try:
        Installer(args).install()
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(f"\nERROR: {error}\nFix the reported step and rerun the same setup command.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
