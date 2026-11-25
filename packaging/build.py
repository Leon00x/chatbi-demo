"""Build a ChatBI ZIP after running npm ci and npm run build in frontend."""

import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tarfile
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parents[1]
PYTHON_VERSION = "3.12.16"
PYTHON_RELEASE = "20261124"
TARGETS = {
    "macos-arm64": (
        "aarch64-apple-darwin",
        "431b99a9c2cdd37ad9b06e425be0e520d2dbce0552abe454257abef592fe3634",
        "Start ChatBI.command",
    ),
    "windows-x64": (
        "x86_64-pc-windows-msvc",
        "8152ff5b6c6c044ddbbaa3531dda59cb9ce5bd6cb670d4c9ac2e3ab91afa8778",
        "Start ChatBI.cmd",
    ),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=TARGETS)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    output = args.output.resolve()
    platform, digest, launcher = TARGETS[args.target]
    frontend = ROOT / "frontend" / "dist"
    if not (frontend / "index.html").is_file():
        parser.error("Build the frontend with npm ci and npm run build first.")

    python_archive = output / f"cpython-{args.target}.tar.gz"
    if not python_archive.exists():
        url = (
            "https://github.com/astral-sh/python-build-standalone/releases/download/"
            f"{PYTHON_RELEASE}/cpython-{PYTHON_VERSION}%2B{PYTHON_RELEASE}-"
            f"{platform}-install_only.tar.gz"
        )
        pending = python_archive.with_suffix(".download")
        subprocess.run(["curl", "-fsSL", "--retry", "2", "-o", pending, url], check=True)
        pending.replace(python_archive)

    with python_archive.open("rb") as archive_stream:
        if hashlib.file_digest(archive_stream, "sha256").hexdigest() != digest:
            raise SystemExit(f"Python archive checksum mismatch: {python_archive}")

    with TemporaryDirectory(prefix="chatbi-package-") as staging_dir:
        staging = Path(staging_dir)
        bundle = staging / "ChatBI"
        bundle.mkdir()
        with tarfile.open(python_archive) as archive:
            archive.extractall(staging, filter="data")
        (staging / "python").rename(bundle / "runtime")

        backend = bundle / "backend"
        shutil.copytree(
            ROOT / "backend" / "app", backend / "app",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        shutil.copytree(ROOT / "backend" / "scenarios", backend / "scenarios")
        (backend / "data").mkdir()
        shutil.copy2(ROOT / "backend" / "data" / "retail.db", backend / "data")
        shutil.copy2(ROOT / "backend" / ".env.example", backend / ".env")
        shutil.copy2(ROOT / "backend" / ".env.example", backend / ".env.example")
        shutil.copytree(frontend, bundle / "frontend" / "dist")
        shutil.copy2(ROOT / "guide.md", bundle)
        shutil.copy2(ROOT / "packaging" / launcher, bundle)
        (bundle / "packaging").mkdir()
        shutil.copy2(ROOT / "packaging" / "serve.py", bundle / "packaging")

        requirements = staging / "runtime-requirements.txt"
        requirements.write_text(
            "\n".join(
                requirement for requirement in (ROOT / "backend" / "requirements.txt")
                .read_text(encoding="utf-8").splitlines()
                if not requirement.startswith("pytest")
            ) + "\n",
            encoding="utf-8",
        )
        subprocess.run([
            "uv", "pip", "install", "--python-version", PYTHON_VERSION,
            "--python-platform", platform, "--target", bundle / "packages",
            "--only-binary", ":all:", "--link-mode", "copy", "-r", requirements,
        ], check=True)
        for directory in ("bin", "Scripts"):
            scripts = bundle / "packages" / directory
            if scripts.is_dir():
                shutil.rmtree(scripts)
        archive = shutil.make_archive(
            str(output / f"chatbi-{args.target}"), "zip", staging, bundle.name,
        )
    print(archive)


if __name__ == "__main__":
    main()
