<p align="center">
  <a href="https://trueconf.ru" target="_blank" rel="noopener noreferrer">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/TrueConf/.github/refs/heads/main/logos/logo-cyrillic-dark.svg">
      <img width="150" alt="trueconf" src="https://raw.githubusercontent.com/TrueConf/.github/refs/heads/main/logos/logo-cyrillic.svg">
    </picture>
  </a>
</p>

<h1 align="center">trueconf-server-linux-autoinstaller</h1>

<p align="center">Автоматизированная установка TrueConf Server на Linux</p>

<p align="center">
    <a href="https://t.me/trueconf_talks" target="_blank">
        <img src="https://img.shields.io/badge/Telegram-2CA5E0?logo=telegram&logoColor=white" />
    </a>
    <a href="#">
        <img src="https://img.shields.io/github/stars/trueconf/trueconf-server-linux-autoinstaller?style=social" />
    </a>
</p>

<p align="center">
  <a href="./README.md">English</a> /
  <a href="./README-ru.md">Русский</a>
</p>

Скрипт определяет ОС, подготавливает систему и устанавливает TrueConf Server
(инсталлятор TrueConf Server для Linux) с сайта TrueConf (`trueconf.com`).

## Поддерживаемые ОС (x86_64)

| ОС | Версии | Пакет |
|---|---|---|
| Debian | 11, 12, 13 | .deb |
| CentOS Stream | 9 | .rpm |
| Astra Linux SE | 1.7, 1.8 | .deb |
| РЕД ОС | 7.3, 8 | .rpm |
| Альт Сервер | 10, c10f2, 11 | .rpm |

## Запуск

> [!IMPORTANT]
> Команда требует прав администратора для выполнения.

```sh
curl -LsSf https://raw.githubusercontent.com/TrueConf/trueconf-server-linux-autoinstaller/refs/heads/master/install.sh | sudo bash
```

или запустите с аргументами:

```sh
# 1.
curl -LsSf https://raw.githubusercontent.com/TrueConf/trueconf-server-linux-autoinstaller/refs/heads/master/install.sh -o install.sh

# 2.
sudo bash install.sh [--admin-users=user1,user2] [--yes] [--port=NNNN] [--file=FILE] [--help] [--version] 
```

| Параметр | Назначение |
|---|---|
| `--admin-users=a,b` | Пользователи ОС с доступом к панели управления (передаётся через `TCADMINS_USERS`). Валидация формата: имена через запятую, до 32 символов `[A-Za-z0-9_.-]`, пробелы вокруг имён игнорируются |
| `--yes` | При занятом порте 80 автоматически выбирается любой свободный порт начиная с 8888 (если параметр не используется, то порт необходимо будет ввести вручную) |
| `--port=NNNN` | Явно указать порт панели управления (только цифры 1–65535; если занят — повторный запрос) |
| `--file=ФАЙЛ` | Установка из локального файла (`.deb`/`.rpm`) без скачивания; расширение должно соответствовать ОС |
| `--help` | Справка (язык зависит от локали ОС) |
| `-v, --version` | Показать версию скрипта |

## Что делает скрипт

1. Проверяет запуск от root.
2. Определяет ОС по `/etc/os-release`; неподдерживаемая ОС или архитектура
   (не x86_64) — сообщение и выход.
3. Проверяет, что пользователя `trueconf` нет (установщик создаёт его сам)
   и что TrueConf Server ещё не установлен.
4. Проверяет и правит репозитории - автоматически раскомментирует необходимые.
5. Обновляет системные пакеты и ставит `curl`. На Debian/Astra — `gnupg2`,
   на Альт — `gnupg`. Для Debian — безопасный `upgrade`; для Astra —
   `upgrade --enable-upgrade` (apt на Astra блокирует обычный `upgrade`,
   не `dist-upgrade`).
6. Выбирает порт панели управления. Только цифры, диапазон 1–65535,
   проверка занятости через `ss -tlnn`/`netstat -tlnn` (числовой вывод; если
   утилиты нет — ошибка). Если выбранный порт занят — повторный запрос. В
   режиме `--yes` берётся первый свободный порт начиная с 8888; при
   недоступном вводе (EOF, cron/CI) тоже берётся первый свободный начиная
   с 8888.
7. Скачивает инсталлятор TrueConf Server для Linux с `trueconf.com/download/server/linux`. Каталог
   загрузки — `/tmp/tcs-installer` (докачка через `-C -`). Устойчивый curl:
   только IPv4, повторы при ошибках (без `--retry-all-errors` — нет в curl
   < 7.71 на Astra/РЕД), отсечка соединений медленнее 1 КБ/с в течение 30 с.
   После успешной установки скачанный файл удаляется.
8. Устанавливает TrueConf Server для Linux; администраторы панели — через `TCADMINS_USERS`.
9. Если выбранный порт ≠ 80 — применяет его после установки
   (`/opt/trueconf/server/etc/webmanager/listen.conf` и
   `/opt/trueconf/server/etc/manager/manager.toml`) и перезапускает службы.
   Заменяются только директивы, слушающие на текущем порту (80): сохраняются
   адрес/опции (`Listen 80` → `Listen 9000`, `Listen 0.0.0.0:80` →
   `Listen 0.0.0.0:9000`, `Listen 443 ssl` не трогается) и схема connection
   (`http`/`https`/`ws`). При отсутствии целевой директивы — ошибка без
   дописывания дублей (невалидный TOML).
10. Выводит URL панели и напоминание о регистрации (Free: порт 4310/TCP
    до `reg.trueconf.com`).
