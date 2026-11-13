# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- Гипервизор: Oracle VirtualBox 7.x.
- Операционная система: Ubuntu Server 24.04 LTS.
- Оперативная память: 2048 МБ.
- Количество ядер процессора: 2.
- Диск: 25 ГБ, динамически расширяемый.

## 2. Сетевые интерфейсы

- Адаптер 1: NAT, 10.0.2.15. Используется для доступа в Интернет.
- Адаптер 2: Host-only,  192.168.56.104
  Используется для связи хостовой системы с виртуальной машиной.

## 3. Правило проброса портов

- Протокол: TCP.
- Адрес хостовой системы: 127.0.0.1.
- Порт хостовой системы: 2222.
- Порт гостевой системы: 2222.
- Назначение: доступ к SSH через NAT.

## 4. Учётные записи

- student: исходная учётная запись, использовавшаяся при установке системы.
- devops: отдельная административная учётная запись, включённая в группу sudo.
- Способ входа devops: аутентификация по SSH-ключу Ed25519.
- Открытый ключ пользователя devops хранится в ~/.ssh/authorized_keys.
- На основном компьютере закрытый ключ хранится в ~/.ssh/devops_vm.

## 5. Служба SSH

- Служба: ssh.service.
- Порт: 2222/tcp.
- Файл дополнительных настроек: /etc/ssh/sshd_config.d/99-hardening.conf.
- Резервная копия основной конфигурации: /etc/ssh/sshd_config.backup.
- PermitRootLogin: no.
- PasswordAuthentication: no.
- PubkeyAuthentication: yes.
- PermitEmptyPasswords: no.
- MaxAuthTries: 3.
- LoginGraceTime: 30.
- AllowUsers: devops.
- X11Forwarding: no.
- ClientAliveInterval: 300.
- ClientAliveCountMax: 2.
- Подключение с основного компьютера: команда ssh devops.

## 6. Правила межсетевого экрана

- Средство фильтрации: UFW.
- Политика входящего трафика: deny.
- Политика исходящего трафика: allow.
- TCP/2222: SSH, ограничение частоты подключений (LIMIT).
- TCP/80: HTTP.
- TCP/443: HTTPS.
- Журналирование: medium.

## 7. Снимки состояния

- 01-clean-install - исходная установленная система.
- 02-keys-configured - создан пользователь devops и настроена ключевая аутентификация.
- 03-ssh-hardened - усилена защита SSH.


## 10. Ansible

Управляющий узел: WSL с Ubuntu.
Управляемый узел: VM devops-vm с Ubuntu Server 24.04.
Адрес VM в сети Host-only: 192.168.56.104.

Проект автоматизации расположен в каталоге ansible/.

Для первичной настройки используется inventory/bootstrap.ini
и учётная запись student с парольным подключением.

Последующие запуски используют inventory/prod.ini,
учётную запись devops и ключ ~/.ssh/devops_vm.

Назначение ролей:

- base: базовые пакеты и Docker Engine;
- ssh: SSH-доступ, пользователи, sudo и UFW;
- nginx: обратное проксирование;
- app: загрузка и запуск контейнера.

Образ: ghcr.io/eeegggooorrr1/devops-ci-app
SHA: a9dc43381184900c6fe1e9b5d052172e58dac488

Порт приложения: 5000, доступен через 127.0.0.1.
Внешний HTTP-порт: 80.
Проверка работоспособности: /health.

Первый запуск из каталога ansible/:

```bash
ansible-playbook -i inventory/bootstrap.ini site.yml --ask-pass --ask-become-pass
```

Повторный запуск:

```bash
ansible-playbook site.yml
```

Проверочный запуск без изменения конфигурации:

```bash
ansible-playbook verify.yml
```

Пароли и закрытые SSH-ключи в репозитории не хранятся.
