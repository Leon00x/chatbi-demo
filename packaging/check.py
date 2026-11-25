"""Extract a platform ZIP and smoke-test its normal launcher."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory
from time import monotonic, sleep
from urllib.error import URLError
from urllib.request import ProxyHandler, build_opener


def main():
    archive = Path(sys.argv[1]).resolve()
    with TemporaryDirectory(prefix="ChatBI release check ") as temp:
        folder = Path(temp)
        bundle = folder / "ChatBI"
        if os.name == "nt":
            shutil.unpack_archive(archive, folder)
            launcher = ["cmd.exe", "/d", "/c", "call", "Start ChatBI.cmd", "--no-browser"]
        else:
            subprocess.run(["/usr/bin/ditto", "-x", "-k", archive, folder], check=True)
            launcher_path = bundle / "Start ChatBI.command"
            launcher = [str(launcher_path), "--no-browser"]

        env = os.environ.copy()
        for name in ("MAAS_API_KEY", "MAAS_BASE_URL", "MAAS_MODEL",
                     "DATABASE_URL", "SCENARIO", "CORS_ORIGINS"):
            env.pop(name, None)
        env["PATH"] = os.path.join(env["SystemRoot"], "System32") if os.name == "nt" else "/usr/bin:/bin"

        log = folder / "launch.log"
        with log.open("wb") as output:
            process = subprocess.Popen(
                launcher, cwd=bundle, env=env, stdin=subprocess.DEVNULL,
                stdout=output, stderr=subprocess.STDOUT,
            )
            try:
                probe(log, process)
            finally:
                if process.poll() is None:
                    if os.name == "nt":
                        subprocess.run(["taskkill", "/pid", str(process.pid), "/t", "/f"], env=env,
                                       stdout=subprocess.DEVNULL, check=False)
                    else:
                        process.terminate()
                    process.wait(timeout=10)


def probe(log, process):
    opener = build_opener(ProxyHandler({}))
    deadline = monotonic() + 30
    while process.poll() is None and monotonic() < deadline:
        output = log.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"Open (http://127\.0\.0\.1:\d+/)", output)
        if match:
            url = match[1]
            try:
                with opener.open(url + "api/health", timeout=2) as response:
                    health = json.load(response)
            except URLError:
                sleep(0.1)
                continue
            assert health["status"] == "ok" and health["maas"]["state"] == "missing_key"
            assert health["model"] == "deepseek-v4.1-flash-1017"
            with opener.open(url + "api/scenario", timeout=2) as response:
                assert json.load(response)["id"] == "sg-retail"
            with opener.open(url, timeout=2) as response:
                html = response.read().decode("utf-8")
            asset = re.search(r'src="(/assets/[^"]+\.js)"', html)[1]
            with opener.open(url.rstrip("/") + asset, timeout=2) as response:
                assert response.read(1)
            print("Bundled launcher, environment defaults, SQLite and web assets passed.")
            return
        sleep(0.1)
    raise SystemExit(log.read_text(encoding="utf-8", errors="replace"))


if __name__ == "__main__":
    main()
