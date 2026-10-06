# Deploy the demo on Huawei Cloud ECS

This optional deployment is for a later hosted demo. For the current local exercise, follow [guide.md](../guide.md). Deployment does not implement any of the guide's feature tasks; the selected Git branch determines the app's capabilities.

## Deployment layout

Use a dedicated Ubuntu/Debian ECS with systemd, Python 3.11+, Node.js 20+ with npm, and Nginx. The scripts use fixed paths for simplicity:

```text
Browser -> Nginx :80 -> /var/www/chatbi-demo (built frontend)
                    -> /api -> FastAPI on 127.0.0.1:8000
                                  -> Huawei Cloud MaaS
                                  -> /var/lib/chatbi-demo/retail.db

Source and .env: /opt/chatbi-demo
Backend service: chatbi.service, running as user chatbi
```

Nginx replaces the local Vite proxy. Node is used only to build the frontend. The backend runs one Uvicorn process, without reload, and systemd starts it at boot and restarts it after failures.

These instructions assume this ECS hosts only this demo. Other Linux distributions or an existing shared Nginx host need configuration adjustments. The initial configuration uses HTTP; configure a domain and HTTPS before using the app with sensitive data.

## 1. Prepare the ECS

Allow SSH only from your administration IP and HTTP port 80 only from the demo audience's IP addresses in the ECS security group. Keep ports 8000 and 5173 closed to external access. The app has no login; anyone with access can consume the configured MaaS quota. Allow outbound HTTPS access to your MaaS endpoint and dependency registries.

Install the host tools:

```bash
sudo apt update
sudo apt install -y git curl nginx python3 python3-venv
python3 --version
```

Install a compatible Node.js release with npm using your normal system provisioning method, then confirm:

```bash
node --version
npm --version
```

Python must be 3.11 or newer; Node must be 20 or newer. Installing these runtimes is a host preparation step, not part of the deployment script.

Clone the starter branch:

```bash
sudo git clone --branch main https://github.com/Leon00x/chatbi-demo.git /opt/chatbi-demo
cd /opt/chatbi-demo
sudo bash deploy/deploy.sh prepare
```

`prepare` creates or reuses the virtual environment, installs project dependencies, builds the frontend, creates the service user and persistent-data directory, and copies `.env.example` only if `.env` is missing. It does not start the app. Dependency downloads can take several minutes.

## 2. Configure the app

Edit the configuration directly on the ECS:

```bash
sudo nano /opt/chatbi-demo/backend/.env
```

Set your MaaS token and an enabled model ID from the [Huawei Cloud Console](https://console.huaweicloud.com/). The default endpoint is `https://api-ap-southeast-1.modelarts-maas.com/openai/v1`; the template also comments the China site address. The endpoint, key and model must belong to the service you use.

Set the database path outside the Git checkout:

```dotenv
DATABASE_URL=sqlite:////var/lib/chatbi-demo/retail.db
```

The four slashes specify an absolute SQLite path. First startup seeds this file if it is empty; existing data is preserved. Keep this path for subsequent updates. A custom database path needs read/write access for the `chatbi` user. Existing local sample data is not copied automatically.

Leave the other template settings unless needed. The browser uses the same Nginx origin for both the UI and `/api`, so the local CORS defaults do not need changing for this layout. The script gives the backend user read access to `.env`; do not place credentials in the Nginx or systemd files.

## 3. Start and open the demo

On this dedicated host, disable Nginx's default site if its symlink exists:

```bash
if [ -L /etc/nginx/sites-enabled/default ]; then
  sudo unlink /etc/nginx/sites-enabled/default
fi
sudo bash deploy/deploy.sh start
```

`start` publishes the built frontend, installs the included Nginx and systemd configurations, checks Nginx syntax, enables both services at boot and restarts them. It checks `/api/health` through Nginx. It replaces only the named ChatBI configuration; it does not modify other site files or the app's `.env` and database.

Open `http://<ECS-public-IP>/` using the public IP shown in the ECS console. Wait for `MaaS connected`, then select a suggested question. The startup health check confirms the backend responds; the MaaS probe completes separately. A missing or invalid key can leave the app running while its MaaS connection is unavailable.

## Update or change configuration

For a code update, stop the backend and pull the current branch:

```bash
sudo systemctl stop chatbi
cd /opt/chatbi-demo
sudo git pull --ff-only
sudo bash deploy/deploy.sh prepare
sudo bash deploy/deploy.sh start
```

This rebuilds the frontend and reinstalls dependencies. `.env` and the database under `/var/lib/chatbi-demo` are preserved. Updates briefly interrupt access; if preparation fails, resolve the reported error before starting again.

After an `.env` or scenario change, restart the backend:

```bash
sudo systemctl restart chatbi
```

Changing the scenario schema also requires a separate database file. Stop the backend before backing up its database, then restart it after the copy.

## Status and troubleshooting

```bash
sudo systemctl status chatbi nginx --no-pager
sudo journalctl -u chatbi -n 100 --no-pager
sudo tail -n 50 /var/log/nginx/error.log
curl --fail http://127.0.0.1/api/health
```

| Symptom | Check |
|---|---|
| Cannot open the page | ECS public IP, security group, host firewall and Nginx status |
| Nginx welcome page | Disable the default site and check for another site using port 80 |
| HTTP 502 on `/api` | Backend status, port 8000 and service logs |
| MaaS connection failure | `.env` endpoint, token, model permission and outbound HTTPS access |
| Database permission error | Database directory/file ownership for user `chatbi` |
| Old page after an update | Confirm the build/deployment succeeded, then refresh the browser |

Stop the app with `sudo systemctl stop chatbi nginx`. On a shared host, stop only the ChatBI backend and disable its Nginx site instead.

The files have been checked locally for syntax and consistency; a full ECS deployment still needs verification on the target Linux host.

References: [Vite static deployment](https://vite.dev/guide/static-deploy.html), [FastAPI deployment](https://fastapi.tiangolo.com/deployment/manually/), and [Nginx reverse proxy configuration](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass).
