"""Run the two ChatBI development servers or rebuild the frontend."""

import argparse
import os
from pathlib import Path
import subprocess
import sys
from time import sleep


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("dev", "build"), default="dev", nargs="?")
    args = parser.parse_args()

    node_root = ROOT / "runtime" / "node"
    windows = os.name == "nt"
    node_bin = node_root if windows else node_root / "bin"
    npm_root = node_root if windows else node_root / "lib"
    node = node_bin / ("node.exe" if windows else "node")
    npm = npm_root / "node_modules" / "npm" / "bin" / "npm-cli.js"
    env = os.environ.copy()
    env.pop("DYLD_FRAMEWORK_PATH", None)
    env.pop("DYLD_LIBRARY_PATH", None)
    env["PATH"] = str(node_bin) + os.pathsep + env["PATH"]

    frontend = ROOT / "frontend"
    if args.command == "build":
        subprocess.run([node, npm, "run", "build"], cwd=frontend, env=env, check=True)
        return

    processes = []
    try:
        processes.append(subprocess.Popen([
            sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1",
            "--port", "8000", "--reload",
        ], cwd=ROOT / "backend"))
        processes.append(subprocess.Popen([
            node, npm, "run", "dev", "--", "--port", "5173", "--strictPort",
        ], cwd=frontend, env=env))
        print("Open http://127.0.0.1:5173/ after Vite starts.", flush=True)
        while all(process.poll() is None for process in processes):
            sleep(0.2)
        failed = next(process for process in processes if process.poll() is not None)
        raise SystemExit(failed.returncode)
    except KeyboardInterrupt:
        pass
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == "__main__":
    main()
