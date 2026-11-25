"""Build a portable ChatBI development ZIP on the target operating system."""

import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[1]
NODE_VERSION = "22.23.5"
NODE_ARCHIVES = {
    "macos-arm64": ("darwin-arm64.tar.gz", "e7131995759b61a0170b646010d2ad35a5d37b4cb0d471f3e8317eac6f742f3d"),
    "windows-x64": ("win-x64.zip", "4a191082e9706866830379d577d2cc8a50c776fcd9436a8d061b063ed0d9a0e3"),
}
PYTHON_MAC = (
    "https://www.python.org/ftp/python/3.14.10/python-3.14.10-macos11.pkg",
    "286c7018aa2730f6747ca433dccdc2b31be45f078a9ea0ffa44d5f06368fd2d7",
)
PYTHON_WINDOWS = (
    "https://github.com/astral-sh/python-build-standalone/releases/download/20261124/"
    "cpython-3.12.16%2B20261124-x86_64-pc-windows-msvc-install_only.tar.gz",
    "8152ff5b6c6c044ddbbaa3531dda59cb9ce5bd6cb670d4c9ac2e3ab91afa8778",
)


def download(output, url, digest, filename=None):
    archive = output / (filename or url.rsplit("/", 1)[-1])
    if not archive.exists():
        pending = archive.with_suffix(".download")
        subprocess.run(["curl", "-fsSL", "--retry", "2", "-o", pending, url], check=True)
        pending.replace(archive)
    with archive.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != digest:
            raise SystemExit(f"Runtime archive checksum mismatch: {archive}")
    return archive


def copy_sources(bundle):
    project_files = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    directories = {"backend", "frontend", "docs", "packaging"}
    root_files = {"AGENTS.md", "README.md", "guide.md", "setup.sh", "setup.ps1", ".gitignore"}
    for name in project_files.decode("utf-8").split("\0"):
        path = Path(name)
        if name not in root_files and (not path.parts or path.parts[0] not in directories):
            continue
        target = bundle / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / path, target)


def prepare_python(staging, runtime, output, macos):
    env = os.environ.copy()
    dist = runtime / "python"
    if macos:
        archive = download(output, *PYTHON_MAC, filename="python-3.14.10.pkg")
        expanded = staging / "python-package"
        subprocess.run(["pkgutil", "--expand-full", archive, expanded], check=True)
        dist.mkdir()
        framework = dist / "Python.framework"
        (expanded / "Python_Framework.pkg" / "Payload").rename(framework)
        version = framework / "Versions" / "3.14"
        env["DYLD_FRAMEWORK_PATH"] = str(dist)
        env["DYLD_LIBRARY_PATH"] = str(version / "lib")
        python = version / "bin" / "python3"
        venv_python = Path("bin/python")
    else:
        archive = download(output, *PYTHON_WINDOWS, filename="cpython-windows-x64.tar.gz")
        with tarfile.open(archive) as package:
            package.extractall(staging, filter="data")
        (staging / "python").rename(dist)
        python = dist / "python.exe"
        venv_python = Path("Scripts/python.exe")

    builder = staging / "wheel-builder"
    subprocess.run([python, "-m", "venv", builder], env=env, check=True)
    subprocess.run([
        builder / venv_python, "-m", "pip", "download", "--only-binary=:all:",
        "--dest", runtime / "wheels", "-r", ROOT / "backend" / "requirements.txt",
    ], env=env, check=True)


def prepare_node(staging, bundle, runtime, output, target, macos):
    suffix, digest = NODE_ARCHIVES[target]
    name = f"node-v{NODE_VERSION}-{suffix}"
    archive = download(output, f"https://nodejs.org/dist/v{NODE_VERSION}/{name}", digest)
    if macos:
        with tarfile.open(archive) as package:
            package.extractall(staging, filter="data")
        extracted = staging / name.removesuffix(".tar.gz")
    else:
        shutil.unpack_archive(archive, staging)
        extracted = staging / name.removesuffix(".zip")
    node_root = runtime / "node"
    extracted.rename(node_root)
    node_bin = node_root / "bin" if macos else node_root
    npm_root = node_root / "lib" if macos else node_root
    node = node_bin / ("node" if macos else "node.exe")
    npm = npm_root / "node_modules" / "npm" / "bin" / "npm-cli.js"
    env = os.environ.copy()
    env["PATH"] = str(node_bin) + os.pathsep + env["PATH"]
    cache = staging / "npm-cache"
    subprocess.run([
        node, npm, "ci", "--cache", cache, "--no-audit", "--no-fund",
    ], cwd=bundle / "frontend", env=env, check=True)
    (runtime / "npm-cache").mkdir()
    (cache / "_cacache").rename(runtime / "npm-cache" / "_cacache")
    shutil.rmtree(bundle / "frontend" / "node_modules")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=NODE_ARCHIVES)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    macos = args.target == "macos-arm64"
    if (macos and (sys.platform != "darwin" or platform.machine() != "arm64")) or (
        not macos and (os.name != "nt" or platform.machine().lower() not in {"amd64", "x86_64"})
    ):
        parser.error("Build this package on its target operating system and architecture.")
    args.output.mkdir(parents=True, exist_ok=True)
    output = args.output.resolve()

    with TemporaryDirectory(prefix="chatbi-package-") as directory:
        staging = Path(directory)
        bundle = staging / "ChatBI"
        copy_sources(bundle)
        runtime = bundle / "runtime"
        runtime.mkdir()
        prepare_python(staging, runtime, output, macos)
        prepare_node(staging, bundle, runtime, output, args.target, macos)
        launcher = "Start ChatBI.command" if macos else "Start ChatBI.cmd"
        shutil.copy2(ROOT / "packaging" / launcher, bundle)
        archive_base = output / f"chatbi-{args.target}"
        if macos:
            subprocess.run([
                "/usr/bin/ditto", "-c", "-k", "--keepParent", "--norsrc",
                bundle, archive_base.with_suffix(".zip"),
            ], check=True)
        else:
            shutil.make_archive(str(archive_base), "zip", staging, bundle.name)
    print(archive_base.with_suffix(".zip"))


if __name__ == "__main__":
    main()
