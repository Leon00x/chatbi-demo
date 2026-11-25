"""Verify the documented setup and startup commands in an extracted ZIP."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
from tempfile import TemporaryDirectory
from time import monotonic, sleep
from urllib.error import URLError
from urllib.request import ProxyHandler, build_opener
from zipfile import ZipFile


def main():
    archive = Path(sys.argv[1]).resolve()
    with ZipFile(archive) as zipped:
        damaged = zipped.testzip()
        assert damaged is None, f"Damaged ZIP entry: {damaged}"
        members = set(zipped.namelist())
        assert {"ChatBI/guide.md", "ChatBI/guide-portable.md"} <= members
        assert not any(name.startswith("ChatBI/frontend/dist/") for name in members)
        assert not any(Path(name).name.startswith("Start ChatBI.") for name in members)
    with TemporaryDirectory(prefix="ChatBI release check ") as temp:
        folder = Path(temp)
        bundle = folder / "ChatBI"
        env = os.environ.copy()
        for name in ("MAAS_API_KEY", "MAAS_BASE_URL", "MAAS_MODEL",
                     "DATABASE_URL", "SCENARIO", "CORS_ORIGINS"):
            env.pop(name, None)

        windows = os.name == "nt"
        if windows:
            shutil.unpack_archive(archive, folder)
            setup = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "setup.ps1"]
            npm = ["cmd.exe", "/d", "/c", "npm.cmd"]
            node_bin = bundle / "runtime" / "node"
            venv = bundle / "backend" / ".venv" / "Scripts" / "python.exe"
            env["PATH"] = os.path.join(env["SYSTEMROOT"], "System32")
        else:
            subprocess.run(["/usr/bin/ditto", "-x", "-k", archive, folder], check=True)
            subprocess.run(["codesign", "--verify", "--strict", bundle / "runtime" / "uv"], check=True)
            assert not (bundle / "runtime" / "python").exists(), "Python should be prepared by setup"
            setup = ["/bin/bash", "./setup.sh"]
            npm = ["npm"]
            node_bin = bundle / "runtime" / "node" / "bin"
            venv = bundle / "backend" / ".venv" / "bin" / "python"
            env["PATH"] = "/usr/bin:/bin"

        assert not venv.exists(), "A prebuilt virtual environment was packaged"
        subprocess.run(setup, cwd=bundle, env=env, check=True, timeout=180)
        assert venv.exists() and (bundle / "backend" / ".env").is_file()
        assert not (bundle / "frontend" / "dist").exists(), "Setup unexpectedly built the frontend"
        env["PATH"] = str(node_bin) + os.pathsep + env["PATH"]
        subprocess.run(npm + ["run", "build"], cwd=bundle / "frontend", env=env, check=True, timeout=90)
        assert (bundle / "frontend" / "dist" / "index.html").is_file()

        backend = [
            venv, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1",
            "--port", "8000", "--reload",
        ]
        frontend = npm + ["run", "dev", "--", "--port", "5173", "--strictPort"]
        processes = []
        log = folder / "launch.log"
        with log.open("wb") as output:
            try:
                for command, directory in ((backend, "backend"), (frontend, "frontend")):
                    processes.append(subprocess.Popen(
                        command, cwd=bundle / directory, env=env, stdin=subprocess.DEVNULL,
                        stdout=output, stderr=subprocess.STDOUT, start_new_session=not windows,
                    ))
                probe(log, processes)
            finally:
                for process in processes:
                    if windows:
                        subprocess.run(["taskkill", "/pid", str(process.pid), "/t", "/f"], env=env,
                                       stdout=subprocess.DEVNULL, check=False)
                    else:
                        try:
                            os.killpg(process.pid, signal.SIGTERM)
                        except ProcessLookupError:
                            pass
                    process.wait(timeout=10)


def probe(log, processes):
    opener = build_opener(ProxyHandler({}))
    url = "http://127.0.0.1:5173/"
    deadline = monotonic() + 45
    while all(process.poll() is None for process in processes) and monotonic() < deadline:
        try:
            with opener.open(url + "api/health", timeout=2) as response:
                health = json.load(response)
            with opener.open(url + "api/scenario", timeout=2) as response:
                scene = json.load(response)
            with opener.open(url, timeout=2) as response:
                html = response.read().decode("utf-8")
        except (URLError, TimeoutError):
            sleep(0.25)
            continue
        assert health["status"] == "ok" and health["maas"]["state"] == "missing_key"
        assert health["model"] == "deepseek-v4.1-flash-1017"
        assert scene["id"] == "sg-retail"
        assert "/src/main.tsx" in html
        print("Offline setup, local venv, frontend build and both development servers passed.")
        return
    raise SystemExit(log.read_text(encoding="utf-8", errors="replace"))


if __name__ == "__main__":
    main()
