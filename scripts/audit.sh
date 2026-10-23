#!/usr/bin/env bash
set -uo pipefail

VM="devops"
PASS=0
FAIL=0

vm() { ssh -o BatchMode=yes -o ConnectTimeout=5 "$VM" "$@"; }

check() {
    local desc="$1" expected="$2" actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo " [OK]    $desc"
        ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(vm hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"

check "Вход от имени root запрещён" "no" \
    "$(vm 'sudo -n sshd -T' | awk '/^permitrootlogin/{print $2}')"

check "Парольная аутентификация отключена" "no" \
    "$(vm 'sudo -n sshd -T' | awk '/^passwordauthentication/{print $2}')"

check "SSH использует порт, отличный от 22" "not-22" \
    "$(vm 'sudo -n sshd -T' | awk '/^port/{if ($2 != 22) print "not-22"; else print "22"; exit}')"

check "Максимум попыток аутентификации равен 3" "3" \
    "$(vm 'sudo -n sshd -T' | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"

check "Межсетевой экран активен" "active" \
    "$(vm 'sudo -n ufw status' | awk '/^Status:/{print $2}')"

check "Политика входящего трафика — deny" "deny" \
    "$(vm 'sudo -n ufw status verbose' | awk '/Default:/{for(i=1;i<=NF;i++) if($i=="(incoming),") {print $(i-1); exit}}')"

echo "[3] Учётные записи"

vm "awk -F: '\$3>=1000 && \$3<65534 {printf \"              %s (uid=%s)\n\", \$1, \$3}' /etc/passwd"

echo "[4] Веб-сервер"

check "Служба nginx активна" "active" \
    "$(vm 'systemctl is-active nginx')"

check "Конфигурация nginx корректна" "yes" \
    "$(vm 'sudo -n nginx -t >/dev/null 2>&1 && echo yes || echo no')"

check "Сертификат действует ещё минимум 30 дней" "yes" \
    "$(vm 'sudo -n openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend 2592000 >/dev/null 2>&1 && echo yes || echo no')"

check "Нет world-writable объектов и ключ имеет права 600" "yes" \
    "$(vm 'if [ -z "$(sudo -n find /var/www/devops-site -perm -o+w -print -quit)" ] && [ "$(sudo -n stat -c %a /etc/ssl/private/devops.key)" = "600" ]; then echo yes; else echo no; fi')"

echo "[5] Контейнеризация"

check "Служба docker активна" "active" \
    "$(vm 'systemctl is-active docker')"

check "Контейнер СУБД healthy" "healthy" \
    "$(vm "docker inspect -f '{{.State.Health.Status}}' app-db-1")"

check "Порты 5000 и 5432 доступны только на 127.0.0.1" "yes" \
    "$(vm "ss -tlnH | awk '\$4 ~ /:(5000|5432)$/ { if (\$4 !~ /^127\\.0\\.0\\.1:/) bad=1 } END { print bad ? \"no\" : \"yes\" }'")"

check "Права файла .env равны 600" "600" \
    "$(vm 'stat -c %a ~/app/.env')"

echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
