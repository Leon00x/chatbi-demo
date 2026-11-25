"""Run the packaged app on localhost and open the browser."""

import argparse
from pathlib import Path
import socket
import sys
from threading import Thread
from time import sleep
import webbrowser


ROOT = Path(__file__).resolve().parents[1]


def open_when_started(server, url):
    while not server.started and not server.should_exit:
        sleep(0.05)
    if server.started:
        webbrowser.open(url)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()

    sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "packages")]

    import uvicorn
    from fastapi.staticfiles import StaticFiles
    from starlette.middleware.trustedhost import TrustedHostMiddleware
    from app.main import app

    host = "127.0.0.1"
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=[host])
    app.mount("/", StaticFiles(directory=ROOT / "frontend" / "dist", html=True))

    with socket.socket() as listener:
        listener.bind((host, 0))
        port = listener.getsockname()[1]
        url = f"http://{host}:{port}/"
        server = uvicorn.Server(
            uvicorn.Config(app, host=host, port=port, proxy_headers=False)
        )
        print(f"Open {url} if your browser does not launch.", flush=True)
        if not args.no_browser:
            Thread(target=open_when_started, args=(server, url), daemon=True).start()
        server.run(sockets=[listener])


if __name__ == "__main__":
    main()
