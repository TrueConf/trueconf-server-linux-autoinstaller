<p align="center">
  <a href="https://trueconf.com" target="_blank" rel="noopener noreferrer">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/TrueConf/.github/refs/heads/main/logos/logo-dark.svg">
      <img width="150" alt="trueconf" src="https://raw.githubusercontent.com/TrueConf/.github/refs/heads/main/logos/logo.svg">
    </picture>
  </a>
</p>

<h1 align="center">trueconf-server-linux-autoinstaller</h1>

<p align="center">Automated installation of TrueConf Server on Linux</p>

<p align="center">
    <a href="https://t.me/trueconf_chat" target="_blank">
        <img src="https://img.shields.io/badge/Telegram-2CA5E0?logo=telegram&logoColor=white" />
    </a>
    <a href="https://discord.gg/2gJ4VUqATZ">
        <img src="https://img.shields.io/badge/Discord-%235865F2.svg?&logo=discord&logoColor=white" />
    </a>
    <a href="#">
        <img src="https://img.shields.io/github/stars/trueconf/trueconf-server-linux-autoinstaller?style=social" />
    </a>
</p>

<p align="center">
  <a href="./README.md">English</a> /
  <a href="./README-ru.md">Русский</a>
</p>

The script detects the operating system, prepares the system, and installs
TrueConf Server (the TrueConf Server for Linux installer) from the TrueConf website (`trueconf.com`).

## Supported operating systems (x86_64)

| OS | Versions | Package |
|---|---|---|
| Debian | 11, 12, 13 | .deb |
| CentOS Stream | 9 | .rpm |

## Usage

> [!IMPORTANT]
> Administrator (root) privileges are required to run the command.

```sh
curl -LsSf https://trueconf.com/go/install.sh | sudo bash
```

or with args:

```sh
# 1.
curl -LsSf https://trueconf.com/go/install.sh -o install.sh

# 2.
sudo bash install.sh [--admin-users=user1,user2] [--yes] [--port=NNNN] [--file=FILE] [--help] [--version] 
```

| Option | Purpose |
|---|---|
| `--admin-users=a,b` | OS users with access to the control panel (passed via `TCADMINS_USERS`). Format validation: comma-separated names, up to 32 characters `[A-Za-z0-9_.-]`; spaces around names are ignored |
| `--yes` | If port 80 is in use, automatically selects the first available port starting from 8888 (without this option, the port must be entered manually) |
| `--port=NNNN` | Explicitly set the control panel port (digits only, 1–65535; if the port is busy, you are prompted again) |
| `--file=FILE` | Install from a local file (`.deb`/`.rpm`) without downloading; the file extension must match the OS |
| `--help` | Show help (the language depends on the OS locale) |
| `-v, --version` | Display script version |

## What the script does

1. Checks that it is run as root.
2. Detects the OS from `/etc/os-release`; an unsupported OS or architecture
   (other than x86_64) results in a message and exit.
3. Checks that the `trueconf` user does not exist (the installer creates it
   itself) and that TrueConf Server is not already installed.
4. Checks and fixes repositories — automatically uncomments the required ones.
5. Updates system packages and installs `curl`. On Debian/Astra — `gnupg2`,
   on ALT — `gnupg`. For Debian, a safe `upgrade` is used; for Astra —
   `upgrade --enable-upgrade` (apt on Astra blocks the regular `upgrade`, not
   `dist-upgrade`).
6. Selects the control panel port. Digits only, range 1–65535; availability is
   checked via `ss -tlnn`/`netstat -tlnn` (numeric output; if neither utility
   is available — an error). If the selected port is busy, the prompt is
   repeated. In `--yes` mode, the first available port starting from 8888 is
   taken; when input is unavailable (EOF, cron/CI), the first available port
   starting from 8888 is taken as well.
7. Downloads the TrueConf Server for Linux installer from `trueconf.com/download/server/linux`. The
   download directory is `/tmp/tcs-installer` (resume via `-C -`). Resilient
   curl: IPv4 only, retries on errors (no `--retry-all-errors` — unavailable
   in curl < 7.71 on Astra/RED), aborts connections slower than 1 KB/s for
   30 s. The downloaded file is removed after a successful installation.
8. Installs TrueConf Server for Linux; panel administrators are set via `TCADMINS_USERS`.
9. If the selected port ≠ 80, it is applied after installation
   (`/opt/trueconf/server/etc/webmanager/listen.conf` and
   `/opt/trueconf/server/etc/manager/manager.toml`) and the services are
   restarted. Only directives listening on the current port (80) are replaced:
   the address/options are preserved (`Listen 80` → `Listen 9000`,
   `Listen 0.0.0.0:80` → `Listen 0.0.0.0:9000`, `Listen 443 ssl` is left
   untouched), as is the connection scheme (`http`/`https`/`ws`). If the target
   directive is missing, an error is raised without appending duplicates
   (invalid TOML).
10. Prints the control panel URL and a registration reminder (Free: TCP port
    4310 to `reg.trueconf.com`).
