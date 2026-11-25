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
UV_MAC_VERSION = "0.13.10"
UV_MAC = (
    f"https://github.com/astral-sh/uv/releases/download/{UV_MAC_VERSION}/uv-aarch64-apple-darwin.tar.gz",
    "e419bf07533bdbf48795fc793601c834dd79db57a8c49ce8e25cfe3a8639958d",
)
UV_LICENSES = {
    "LICENSE-MIT": "860e3d7a86b84e6a7012c7a635fc64df475cebc6cce34dfeb73a5982ec58176c",
    "LICENSE-APACHE": "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4",
}
PYTHON_MAC_VERSION = "3.12.16"
PYTHON_MAC_RELEASE = "20261124"
PYTHON_MAC_ASSET = (
    f"cpython-{PYTHON_MAC_VERSION}+{PYTHON_MAC_RELEASE}-aarch64-apple-darwin-install_only_stripped.tar.gz"
)
PYTHON_MAC_DIGEST = "9d6d9d0d85feda3f9cb4eb3e048f0fed21ed280feda087927eaa4fbc7124826f"
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


def prepare_uv_python(staging, runtime, output, env):
    uv_archive = download(output, *UV_MAC)
    with tarfile.open(uv_archive) as package:
        package.extractall(staging, filter="data")
    uv = runtime / "uv"
    (staging / "uv-aarch64-apple-darwin" / "uv").rename(uv)
    subprocess.run(["codesign", "--verify", "--strict", uv], check=True)
    for name, digest in UV_LICENSES.items():
        license_file = download(
            output, f"https://raw.githubusercontent.com/astral-sh/uv/{UV_MAC_VERSION}/{name}",
            digest, filename=f"uv-{name}",
        )
        shutil.copy2(license_file, runtime)

    python_archive = download(
        output,
        "https://github.com/astral-sh/python-build-standalone/releases/download/"
        f"{PYTHON_MAC_RELEASE}/{PYTHON_MAC_ASSET.replace('+', '%2B')}",
        PYTHON_MAC_DIGEST,
        filename=PYTHON_MAC_ASSET,
    )
    mirror = runtime / "python-mirror"
    (mirror / PYTHON_MAC_RELEASE).mkdir(parents=True)
    shutil.copy2(python_archive, mirror / PYTHON_MAC_RELEASE)
    (runtime / "python-version").write_text(PYTHON_MAC_VERSION + "\n", encoding="utf-8")

    # The build-time interpreter stays outside the published package.
    env["UV_PYTHON_INSTALL_DIR"] = str(staging / "managed-python")
    env["UV_CACHE_DIR"] = str(staging / "uv-cache")
    subprocess.run([
        uv, "python", "install", PYTHON_MAC_VERSION, "--offline", "--no-config",
        "--no-bin", "--mirror", mirror.as_uri(),
    ], env=env, check=True)
    python = subprocess.check_output([
        uv, "python", "find", PYTHON_MAC_VERSION, "--offline", "--no-config",
        "--managed-python",
    ], env=env, text=True)
    return Path(python.strip())


def prepare_python(staging, runtime, output, macos):
    env = os.environ.copy()
    dist = runtime / "python"
    if macos:
        python = prepare_uv_python(staging, runtime, output, env)
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
                "/usr/bin/tar", "--format", "zip", "-cf", archive_base.with_suffix(".zip"),
                "-C", staging, bundle.name,
            ], check=True)
        else:
            shutil.make_archive(str(archive_base), "zip", staging, bundle.name)
    print(archive_base.with_suffix(".zip"))


if __name__ == "__main__":
    main()
