#!/usr/bin/env bash
set -euo pipefail

# Single-app Ubuntu/Debian host. Clone the project at this fixed path.
app_root=/opt/chatbi-demo
web_root=/var/www/chatbi-demo
action=${1:-prepare}

if [[ $EUID -ne 0 ]]; then
  printf '%s\n' 'Run with sudo: sudo bash deploy/deploy.sh prepare|start' >&2
  exit 1
fi
case "$action" in
  prepare|start) ;;
  *) printf '%s\n' 'Usage: sudo bash deploy/deploy.sh prepare|start' >&2; exit 1 ;;
esac
if [[ "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" != "$app_root" ]]; then
  printf '%s\n' 'Clone the project at /opt/chatbi-demo before running this script.' >&2
  exit 1
fi
cd "$app_root"
for command in python3 node npm nginx systemctl curl; do
  command -v "$command" >/dev/null || { printf 'Missing command: %s\n' "$command" >&2; exit 1; }
done
node -e 'if (Number(process.versions.node.split(".")[0]) < 20) { console.error("Use Node.js 20 or newer."); process.exit(1); }'

if [[ "$action" == prepare ]]; then
  if systemctl is-active --quiet chatbi.service; then
    printf '%s\n' 'Stop chatbi.service before preparing an update.' >&2
    exit 1
  fi
  if ! id chatbi >/dev/null 2>&1; then
    useradd --system --user-group --home-dir /var/lib/chatbi-demo --shell /usr/sbin/nologin chatbi
  fi
  bash setup.sh
  npm --prefix frontend run build
  install -d -o chatbi -g chatbi -m 750 /var/lib/chatbi-demo
  # Keep an existing .env, including its values; only adjust read permissions.
  chown root:chatbi backend/.env
  chmod 640 backend/.env
  printf '%s\n' \
    'Prepared. No services were started.' \
    'Edit /opt/chatbi-demo/backend/.env with your MaaS settings.' \
    'For persistent data, set DATABASE_URL=sqlite:////var/lib/chatbi-demo/retail.db.' \
    'Then run: sudo bash deploy/deploy.sh start'
  exit 0
fi

test -f frontend/dist/index.html
test -x backend/.venv/bin/python
test -f backend/.env
id chatbi >/dev/null
if [[ -e /etc/nginx/sites-enabled/default ]]; then
  printf '%s\n' 'Disable the default Nginx site on this dedicated demo host first; see docs/deployment.md.' >&2
  exit 1
fi
# Existing assets are overwritten; .env and database files are never copied.
install -d -m 755 "$web_root"
cp -R frontend/dist/. "$web_root/"
install -m 644 deploy/nginx.conf /etc/nginx/sites-available/chatbi
ln -sfn /etc/nginx/sites-available/chatbi /etc/nginx/sites-enabled/chatbi
install -m 644 deploy/chatbi.service /etc/systemd/system/chatbi.service
nginx -t
systemctl daemon-reload
systemctl enable chatbi.service nginx.service
systemctl restart chatbi.service
systemctl restart nginx.service
curl --fail --silent --show-error --retry 5 --retry-connrefused --retry-delay 2 http://127.0.0.1/api/health
printf '\n%s\n' 'Started. Open http://<ECS-public-IP>/ from an allowed client.'
