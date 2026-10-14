#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail
REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/site/"
DRY_RUN=0
if [[ $# -gt 1 ]]; then
 echo "Использование: $0 [--dry-run]" >&2
 exit 2
fi
if [[ $# -eq 1 ]]; then
 if [[ "$1" == "--dry-run" ]]; then
 DRY_RUN=1
 else
 echo "Неизвестный аргумент: $1" >&2
 echo "Использование: $0 [--dry-run]" >&2
 exit 2
 fi
fi
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
 echo "Ошибка: отсутствует ${LOCAL_DIR}index.html; доставка отменена." >&2
 exit 1
fi
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
 echo "Ошибка: в репозитории есть незафиксированные изменения; доставка отменена." >&2
 git -C "$REPO_ROOT" status --short >&2
 exit 1
fi
RSYNC_BASE=(-avz --delete --chmod=D755,F644 -e 'ssh -o BatchMode=yes -o ConnectTimeout=5')
if [[ "$DRY_RUN" -eq 1 ]]; then
 rsync "${RSYNC_BASE[@]}" --dry-run "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}/"
 exit 0
fi
rsync "${RSYNC_BASE[@]}" "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}/"
DEVOPS · ПРАКТИЧЕСКАЯ РАБОТА № 6
Пошаговая инструкция · 11
if ! curl --fail --silent --show-error --cacert "$CA_CERT" "$SITE_URL" >/dev/null; then
 echo "Ошибка: после доставки сайт недоступен или проверка TLS не пройдена." >&2
 exit 1
fi
printf 'Деплой выполнен. Коммит: %s
' "$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
