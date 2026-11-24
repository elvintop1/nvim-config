import argparse
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import install
import cpw


def test_bash():
    if os.name == "nt":
        candidates = [os.environ.get("CPW_TEST_BASH", ""),
                      str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe")]
        git = shutil.which("git")
        if git:
            candidates += [str(Path(git).parent.parent / "bin/bash.exe")]
        for candidate in candidates:
            if candidate and Path(candidate).is_file():
                return candidate
        raise RuntimeError("Tests require Git Bash, not the Windows System32 WSL bash launcher.")
    return shutil.which("bash") or "/bin/bash"


BASH = test_bash()


def options(prefix, **overrides):
    result = dict(prefix=str(prefix), minimal=True, skip_system=True, no_shell=True,
                  skip_extensions=False, no_nvim=True, dry_run=False)
    result.update(overrides)
    return argparse.Namespace(**result)


class SetupTests(unittest.TestCase):
    def test_platforms_and_unsupported_host(self):
        for system, machine, expected in [
            ("Linux", "x86_64", ("linux", "amd64")),
            ("Linux", "aarch64", ("linux", "arm64")),
            ("Darwin", "arm64", ("darwin", "arm64")),
            ("Darwin", "x86_64", ("darwin", "amd64")),
            ("Windows", "AMD64", ("windows", "amd64")),
        ]:
            self.assertEqual(install.host_info(system, machine), expected)
        with self.assertRaises(RuntimeError):
            install.host_info("Windows", "ARM64")

    def test_linux_source_build_dependencies(self):
        self.assertIn("libxcb1-dev", install.linux_packages("apt-get"))
        self.assertIn("openssl-devel", install.linux_packages("dnf"))
        self.assertIn("libxcb", install.linux_packages("pacman"))

    def test_shell_help_dry_run_and_invalid_args_do_not_write(self):
        with tempfile.TemporaryDirectory() as temp:
            prefix = Path(temp) / "install with spaces"
            for args in (["--help"], ["--dry-run", "--minimal"], ["--dry-run", "--no-nvim"]):
                result = subprocess.run([BASH, ROOT / "setup.sh", "--prefix", str(prefix)] + args, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(prefix.exists())
            result = subprocess.run([BASH, ROOT / "setup.sh", "--invalid"], capture_output=True)
            self.assertEqual(result.returncode, 2)
            result = subprocess.run([BASH, ROOT / "setup.sh", "--prefix"], capture_output=True)
            self.assertEqual(result.returncode, 2)

    def test_python_dry_run_does_not_write(self):
        with tempfile.TemporaryDirectory() as temp:
            prefix = Path(temp) / "not-created"
            install.Installer(options(prefix, dry_run=True)).install()
            self.assertFalse(prefix.exists())

    def test_profile_update_preserves_content_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as temp:
            profile = Path(temp) / ".bashrc"
            profile.write_text("export MY_EDITOR=nvim\n")
            activation = "/some path/with 'quotes'/env.sh"
            install.update_profile(profile, activation)
            first = profile.read_text()
            install.update_profile(profile, activation)
            self.assertEqual(profile.read_text(), first)
            self.assertIn("export MY_EDITOR=nvim", first)
            self.assertEqual(first.count(install.MARK_START), 1)
            subprocess.run([BASH, "-n", profile], check=True)

    def test_dedicated_prefix_required(self):
        with self.assertRaises(RuntimeError):
            install.Installer(options(Path.home()))
        with self.assertRaises(RuntimeError):
            install.Installer(options(Path(Path.cwd().anchor)))

    def test_neovim_deployment_preserves_backup_and_reruns(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            source = temp / "checkout"
            source.mkdir()
            (source / "init.lua").write_text("-- source config\n")
            (source / ".git").mkdir()
            target = temp / "config/nvim"
            target.mkdir(parents=True)
            (target / "custom.lua").write_text("-- keep this in backup\n")
            installer = install.Installer(options(temp / "prefix", no_nvim=False))
            with patch.object(install, "ROOT", source), patch.object(installer, "archive", return_value=temp / "runtime"), \
                 patch.dict(os.environ, {"XDG_CONFIG_HOME": str(temp / "config"), "NVIM_APPNAME": "nvim"}):
                installer.neovim()
                backups = list(target.parent.glob("nvim.backup-*"))
                self.assertEqual(len(backups), 1)
                self.assertEqual((backups[0] / "custom.lua").read_text(), "-- keep this in backup\n")
                self.assertFalse((target / ".git").exists())
                self.assertEqual((target / "init.lua").read_text(), "-- source config\n")
                installer.neovim()
                self.assertEqual(len(list(target.parent.glob("nvim.backup-*"))), 1)

    def test_windows_path_for_git_bash(self):
        self.assertEqual(install.bash_path("C:\\Users\\Name Here\\cpw"), "/c/Users/Name Here/cpw")

    def test_zip_paths_and_symlinks_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            for name in ("../escape.txt", "C:/escape.txt", "..\\escape.txt"):
                archive = temp / "bad.zip"
                with zipfile.ZipFile(archive, "w") as bundle:
                    bundle.writestr(name, "bad")
                with self.assertRaises(RuntimeError):
                    install.extract_archive(archive, temp / "output")
            with zipfile.ZipFile(archive, "w") as bundle:
                entry = zipfile.ZipInfo("link")
                entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                bundle.writestr(entry, "../outside")
            with self.assertRaises(RuntimeError):
                install.extract_archive(archive, temp / "output")
            self.assertFalse((temp / "escape.txt").exists())

    def test_tar_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            archive = temp / "bad.tar.gz"
            with tarfile.open(archive, "w:gz") as bundle:
                entry = tarfile.TarInfo("../escape.txt")
                entry.size = 3
                bundle.addfile(entry, io.BytesIO(b"bad"))
            with self.assertRaises(tarfile.FilterError):
                install.extract_archive(archive, temp / "output")
            self.assertFalse((temp / "escape.txt").exists())

    def test_checksum_mismatch_removes_cache(self):
        with tempfile.TemporaryDirectory() as temp:
            installer = install.Installer(options(Path(temp) / "prefix"))
            cached = installer.prefix / "cache/downloads/asset"
            cached.parent.mkdir(parents=True)
            cached.write_bytes(b"corrupt")
            with self.assertRaises(RuntimeError):
                installer.download("https://example.org/asset", "0" * 64)
            self.assertFalse(cached.exists())

    def test_generated_launcher_handles_spaces_without_shell_edits(self):
        with tempfile.TemporaryDirectory() as temp:
            installer = install.Installer(options(Path(temp) / "prefix with spaces"))
            (installer.prefix / "bin").mkdir(parents=True)
            installer.py = Path(sys.executable)
            installer.config.update(python=sys.executable, oj=sys.executable, kattis=__file__)
            with patch.object(install.shutil, "which", return_value=sys.executable):
                installer.finish()
            launcher = installer.prefix / "bin/cpw"
            result = subprocess.run([BASH, launcher, "--help"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("submit", result.stdout)
            self.assertNotIn(b"\r", launcher.read_bytes())
            self.assertNotIn(b"\r", (installer.prefix / "env.sh").read_bytes())


class WorkspaceTests(unittest.TestCase):
    def test_create_samples_and_refuse_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp) / "problem with spaces"
            cpw.create_problem(directory, "https://codeforces.com/contest/1/problem/A",
                               ROOT / "templates/files/cpp/cp.cpp", [{"input": "1 2\n", "output": "3\n"}])
            self.assertEqual((directory / "test/sample-1.in").read_text(), "1 2\n")
            self.assertEqual(json.loads((directory / ".cpw.json").read_text())["language"], "C++")
            with self.assertRaises(FileExistsError):
                cpw.create_problem(directory, "https://codeforces.com/contest/1/problem/A", ROOT / "templates/files/cpp/cp.cpp")
            self.assertEqual((directory / "test/sample-1.out").read_text(), "3\n")

    def test_companion_updates_samples_without_overwriting_source(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp) / "problem"
            url = "https://codeforces.com/contest/1/problem/A"
            template = ROOT / "templates/files/cpp/cp.cpp"
            cpw.import_companion(directory, url, template, [{"input": "2\n", "output": "3\n"}])
            (directory / "main.cpp").write_text("// my solution\n")
            cpw.import_companion(directory, url, template, [{"input": "4\n", "output": "5\n"}])
            self.assertEqual((directory / "main.cpp").read_text(), "// my solution\n")
            self.assertEqual((directory / "test/sample-1.in").read_text(), "4\n")
            with self.assertRaises(cpw.UserError):
                cpw.import_companion(directory, "https://codeforces.com/contest/2/problem/A", template, [])

    def test_problem_names(self):
        self.assertEqual(cpw.problem_name("https://codeforces.com/contest/123/problem/B"), "cf-123-B")
        self.assertEqual(cpw.problem_name("https://codeforces.com/problemset/problem/123/B"), "cf-123-B")
        self.assertEqual(cpw.problem_name("https://atcoder.jp/contests/abc388/tasks/abc388_a"), "tasks-abc388_a")
        for url in ("http://example.org/a", "https://user:secret@example.org/a", "file:///tmp/a"):
            with self.assertRaises(cpw.UserError):
                cpw.validate_url(url)

    def test_forwarded_tool_flags_are_preserved(self):
        for command, arguments in (("kattis", ["-p", "hello", "main.cpp"]), ("cf", ["--version"]),
                                   ("bridge", ["register", "--system"])):
            parsed = cpw.parse_arguments([command] + arguments)
            self.assertEqual(parsed.command, command)
            self.assertEqual(parsed.arguments, arguments)

    def test_missing_install_and_workspace_report_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            self.assertEqual(cpw.main(["doctor"], prefix=temp), 1)


@unittest.skipUnless(os.environ.get("CPW_TEST_PREFIX"), "Set CPW_TEST_PREFIX for installed-tool integration tests")
class IntegrationTests(unittest.TestCase):
    def test_compiler_and_oj_accept_and_reject(self):
        config = json.loads((Path(os.environ["CPW_TEST_PREFIX"]) / "config.json").read_text())
        with tempfile.TemporaryDirectory(prefix="cpw tests ") as temp:
            directory = cpw.create_problem(Path(temp) / "problem with spaces", "https://codeforces.com/contest/1/problem/A",
                ROOT / "templates/files/cpp/cp.cpp", [{"input": "2 3\n", "output": "5\n"}])
            script = "import sys;sys.path.insert(0,sys.argv[1]);import cpw;raise SystemExit(cpw.main(['test'],prefix=sys.argv[2]))"
            command = [config["python"], "-c", script, str(ROOT / "scripts"), os.environ["CPW_TEST_PREFIX"]]
            source = directory / "main.cpp"
            source.write_text('#include <iostream>\nint main(){int a,b;std::cin>>a>>b;std::cout<<a+b<<"\\n";}\n')
            result = subprocess.run(command, cwd=directory, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            source.write_text('#include <iostream>\nint main(){std::cout<<0<<"\\n";}\n')
            result = subprocess.run(command, cwd=directory, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("[FAILURE] WA", result.stdout)


if __name__ == "__main__":
    unittest.main()
