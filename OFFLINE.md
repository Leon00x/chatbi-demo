# Offline workshop setup

For the Windows workshop kit, follow [Step 0 in the included guide](guide.md#step-0-prepare-the-environment-configure-maas-then-start-manually). The kit includes the source and dependencies in one ZIP.

The instructions below cover the original source and dependency downloads from `main` and `deps-v1`.

## 1. What you need

- Network access to `github.com`, to fetch the project and download the dependency bundle (about 130 MB for one platform).
- Git is optional: clone with it, or download the ZIP as described in section 2.
- Windows 10/11 on x64 or ARM64, or macOS on Apple silicon.
- Network access to your MaaS endpoint. The app calls Huawei Cloud MaaS at startup and for every question, so "offline" here only means **dependency installation needs no internet**.

Intel Macs are not supported by the offline bundle. `bootstrap.sh` stops with a clear message on those machines.

## 2. One-time setup

Windows PowerShell, from the project root:

```powershell
git clone https://github.com/hhuang37/chatbi-demo.git
cd chatbi-demo
powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

macOS, from the project root:

```bash
git clone https://github.com/hhuang37/chatbi-demo.git
cd chatbi-demo
bash ./bootstrap.sh
```

`setup.ps1` and `setup.sh` run the same logic, so the Step 0 command in guide.md works too.

### If Git is not installed

Git is only used to fetch the sources. Bootstrap and the two services do not need it.

1. Open https://github.com/hhuang37/chatbi-demo and choose **Code > Download ZIP**.
2. Extract the archive. Windows: right-click the file and choose Extract All. macOS: double-click it.
3. Open a terminal in the extracted folder (`chatbi-demo-main`) and run `bootstrap.ps1` on Windows or `bootstrap.sh` on macOS, as shown above.

Without Git you cannot pull updates or push your changes. Keep a copy of the folder if you want to preserve your work.

### What bootstrap does

1. Detects the platform (`win-arm64`, `win-x64`, `mac-arm64`) and refuses to continue on an unsupported one.
2. Downloads `chatbi-deps-<platform>-v1.zip` from the pinned GitHub release and verifies it against `SHA256SUMS`.
3. Extracts Node.js, CPython, the wheelhouse and the npm cache into `.offline\`, and `node_modules` into `frontend\`. When a platform bundle ships the runtimes as source archives (macOS), it extracts them here as well, and builds `node_modules` from the bundled cache on first run.
4. Creates `backend\.venv` from the bundled Python.
5. Installs the backend packages with `pip install --no-index`; PyPI is never contacted.
6. Writes `frontend\.npmrc` so later `npm install` runs resolve from the bundled cache.
7. Copies `backend\.env.example` to `backend\.env` if no `.env` exists. No credentials are shipped.
8. Adds `.offline\node` to your **user** PATH only when no Node 20+ is found (section 3.2).
9. Prints the two startup commands from guide.md.

Run bootstrap once, in the folder where the project will stay. Do not move the project folder afterwards: `backend\.venv\pyvenv.cfg` records absolute paths. If you do move it, run `bootstrap.ps1 -Repair` (`bootstrap.sh --repair`) to rebuild the venv in seconds.

Other switches:

| Windows | macOS | Effect |
| --- | --- | --- |
| `.\bootstrap.ps1 -Repair` | `bash ./bootstrap.sh --repair` | Rebuild `backend\.venv` |
| `.\bootstrap.ps1 -Force` | `bash ./bootstrap.sh --force` | Download the bundle again |
| `.\bootstrap.ps1 -Uninstall` | `bash ./bootstrap.sh --uninstall` | Remove the PATH entry added by bootstrap |

## 3. Verify the environment

### 3.1 Node and npm

Open a terminal in the project root and run:

```powershell
node -v
where.exe node
where.exe npm
node -p "process.execPath"
```

On macOS use `which -a node npm` instead of `where.exe`.

If the bundled runtime is in use, `where.exe node` prints the project path first:

```
D:\work\chatbi-demo\.offline\node\node.exe
```

If it prints a system installation such as `C:\Program Files\nodejs\node.exe`, use this table:

| Result | Meaning | Action |
| --- | --- | --- |
| `where.exe` reports nothing | No Node installed | Add the bundled Node (section 3.2) |
| System path, `node -v` is 20 or newer | Usable | Nothing to do |
| System path, `node -v` is below 20 | Too old for Vite 6 | Add the bundled Node (section 3.2) |
| Project `.offline\node` path | Bundled runtime | Nothing to do |

### 3.2 If npm resolves to the wrong place

Windows inherits environment variables at process start. A PATH change made by bootstrap applies to **new** terminals, not to the window that ran it, and a terminal tab inside an IDE inherits the IDE's environment from when the IDE started. After bootstrap, close the terminal (restart the IDE if the terminal lives inside it) and open a new one.

To use the bundled Node in the current window only:

```powershell
$env:Path = "$PWD\.offline\node;$env:Path"
node -v
```

To make it persistent for your user account (run this in the project root):

```powershell
$nodeDir = (Resolve-Path '.\.offline\node').Path
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$nodeDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$nodeDir;$userPath", 'User')
    Write-Host "Added. Reopen your terminal: $nodeDir"
} else {
    Write-Host "Already present: $nodeDir"
}
```

Close and reopen the terminal, then check again with `where.exe node`.

Do not use `setx PATH "%PATH%;..."`: it truncates values at 1024 characters and merges the system PATH into the user PATH.

To undo the change:

```powershell
$nodeDir = (Resolve-Path '.\.offline\node').Path
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$cleaned = ($userPath -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $nodeDir.TrimEnd('\') }) -join ';'
[Environment]::SetEnvironmentVariable('Path', $cleaned, 'User')
```

On macOS, for the current shell and persistently:

```bash
export PATH="$PWD/.offline/node/bin:$PATH"
echo "export PATH=\"$(pwd)/.offline/node/bin:\$PATH\"" >> ~/.zshrc
```

### 3.3 Python

Python does not need to be on PATH: guide.md always calls the venv interpreter by relative path.

```powershell
cd backend
.\.venv\Scripts\python.exe -c "import sys, sqlite3, fastapi; print(sys.version.split()[0], hasattr(sqlite3.Connection, 'setlimit'))"
```

Expected output (a 3.11+ runtime with the SQLite safety interface):

```
3.14.10 True
```

On macOS the interpreter is `.venv/bin/python`.

## 4. Start the app

For the original source and dependency downloads, use the startup commands below. For the Windows workshop kit, use the two PowerShell terminals described in the included guide.

```powershell
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

```powershell
cd frontend
npm run dev -- --port 5173 --strictPort
```

`cd backend` is required: the database URL is relative (`sqlite:///./data/retail.db`).

## 5. Adding dependencies while offline

Step 1 of guide.md adds ECharts. The bundle already contains `echarts@6.1.0`, so:

- `import` from `echarts` works without any install step.
- Running `npm install echarts` anyway succeeds from the bundled npm cache (`frontend\.npmrc` sets `prefer-offline` and points npm at `.offline\npm-cache`).

If you install a package that is **not** in the cache, npm fails with `ENOTCACHED` instead of hanging. Options:

- Install from a local tarball: `npm install ./vendor/<package>.tgz`.
- Ask the instructor for a bundle update that includes the package.

If `frontend\node_modules` is deleted or damaged:

```powershell
cd frontend
npm ci --offline
```

Python: Steps 1–3 need no new packages. If one is required, place the wheel in `.offline\wheels` and run:

```powershell
.\.venv\Scripts\python.exe -m pip install --no-index --find-links ..\.offline\wheels <package>
```

## 6. Differences from guide.md

| Topic | guide.md (upstream) | This offline setup |
| --- | --- | --- |
| Step 0 setup command | Runs `setup.ps1` / `setup.sh`, installs from PyPI and the npm registry | Same commands; both delegate to bootstrap and use the local bundle |
| Python | You install 3.11+ yourself | Bundled Python 3.14.10, no system install needed |
| Node | You install 20+ yourself | Bundled Node 24 LTS, added to PATH only if needed |
| ECharts (Step 1) | `npm install echarts` downloads from the registry | Preinstalled; the install command still works from the offline cache |
| Startup commands | Two terminals | Unchanged |

Steps 1–3 of guide.md are unaffected.

## 7. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `npm` is not recognized | PATH was updated after this terminal started | Section 3.2, then reopen the terminal |
| `You installed esbuild for another platform` | `node_modules` copied from a different OS/architecture | Re-run bootstrap with `-Force` / `--force` |
| `ModuleNotFoundError` in the backend | `backend\.venv` missing or broken | Re-run bootstrap with `-Repair` / `--repair` |
| Venv fails after moving the project | `pyvenv.cfg` absolute paths | Re-run bootstrap with `-Repair` / `--repair` |
| Port 8000 or 5173 already in use | Another process is listening | Stop it, or change both ports and the Vite proxy as guide.md describes |
| Connection check fails at startup | `.env` not configured, or no network to MaaS | Edit `backend\.env` as guide.md Step 0 describes |
| `ENOTCACHED` from npm | The package is not in the bundled cache | Section 5 |

## 8. Cleanup

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Uninstall
```

This removes the PATH entry bootstrap added. Then delete `.offline`, `backend\.venv` and `frontend\node_modules` if you want the disk space back. Project sources and `backend\.env` are left untouched.

## 9. Bundle contents

Each platform bundle contains:

| Component | Version |
| --- | --- |
| Standalone CPython | 3.14.10 |
| Python wheels for the backend requirements | Frozen in [offline/constraints.txt](offline/constraints.txt) |
| Node.js runtime | 24.22.3 LTS |
| `node_modules` including `echarts` | Matches `frontend\package-lock.json`; prebuilt on Windows, restored from the bundled cache on macOS |
| npm offline cache | Same packages, for repairs and extra installs |

Bundles are published as release assets named `chatbi-deps-<platform>-v1.zip`. The release tag is pinned in `bootstrap.ps1` and `bootstrap.sh`, so a fresh clone always gets the versions this document describes.
