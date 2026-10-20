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
TrueConf Server (the TrueConf Server for Linux installer) from the TrueConf website
(`trueconf.com`; packages for Russian distributions are downloaded from
`download.trueconf.ru`).

## Supported operating systems (x86_64)

| OS | Versions | Package |
|---|---|---|
| Debian | 11, 12, 13 | .deb |
| CentOS Stream | 9 | .rpm |
| Astra Linux SE | 1.7, 1.8 | .deb |
| RED OS | 7.3, 8 | .rpm |
| ALT Server | 10, 10.2 (c10f2), 11 | .rpm |

## Usage

> [!IMPORTANT]
> Administrator (root) privileges are required for the installation.

> [!NOTE]
> Privileged operations (package manager, service restart, writes to `/etc`
> and `/opt`) are executed through `sudo`, so the script can be started by a
> regular user — including through a pipe (`curl ... | bash`).

```sh
curl -LsSf https://trueconf.com/go/install.sh | bash
```

or with args:

```sh
# 1.
curl -LsSf https://trueconf.com/go/install.sh -o install.sh

# 2.
bash install.sh [--admin-users=user1,user2] [--yes] [--port=NNNN] [--file=FILE] [--skip-update] [--allow-env-hooks] [--help] [--version] 
```

`sudo` is optional: the script requests it itself for privileged operations,
or you can run the same command with `sudo` right away.

| Option | Purpose |
|---|---|
| `--admin-users=a,b` | OS users with access to the control panel (passed via `TCADMINS_USERS`). Format validation: comma-separated names, up to 32 characters `[A-Za-z0-9_.-]`; spaces around names are ignored |
| `--yes` | Non-interactive mode: no questions are asked. If the port is busy (including the one passed via `--port`), the first available port starting from 8888 is taken automatically |
| `--port=NNNN` | Explicitly set the control panel port (digits only, 1–65535; if the port is busy, it is requested again, and with `--yes` the first free port from 8888 is taken) |
| `--file=FILE` | Install from a local file (`.deb`/`.rpm`) without downloading; the file extension must match the OS. A relative path is converted to an absolute one automatically |
| `--skip-update` | Skip the system package update step (`apt-get upgrade` / `dnf update`); `curl` is installed separately if it is missing |
| `--allow-env-hooks` | Honor `TC_*`/`DL_DIR` environment overrides (test hooks; ignored unless this option is passed) |
| `-h, --help` | Show help (the language depends on the OS locale) |
| `-v, --version` | Display script version |

## What the script does

1. Performs privileged operations through `sudo` (works both as root and as a
   regular user with sudo access).
2. Detects the OS from `/etc/os-release`; an unsupported OS or architecture
   (other than x86_64) results in a message and exit.
3. Checks that the `trueconf` user does not exist (the installer creates it
   itself) and that TrueConf Server is not already installed.
4. Checks and fixes repositories: disables local media (CD/DVD) sources and
   makes the required distribution repositories active. On Debian, the main
   suite of the detected release must be active — a commented one is
   uncommented, otherwise an error is raised. On Astra and ALT, an active
   `deb`/`rpm http(s)` source is required. On CentOS and RED OS, media
   repositories are disabled and disabled distribution repositories
   (`baseos`/`appstream`, `base`/`updates`) are enabled inside the `.repo`
   files (`enabled=1`) even if some other repository is already enabled; at
   least one enabled http(s) repository is required. EPEL is installed on
   CentOS.
5. Unless `--skip-update` is used, updates system packages and installs `curl`.
   On Debian/Astra — `gnupg2`, on ALT — `gnupg`. On Debian, a safe `upgrade` is
   used; on Astra — `upgrade --enable-upgrade` (apt on Astra blocks the regular
   `upgrade`, not `dist-upgrade`). If `curl` is still missing (for example with
   `--skip-update`), it is installed separately before downloading.
6. Selects the control panel port. Digits only, range 1–65535; availability is
   checked via `ss -tlnn`/`netstat -tlnn` (numeric output; if neither utility
   is available — an error). If the selected port is busy, the prompt is
   repeated. In `--yes` mode, the first available port starting from 8888 is
   taken; when input is unavailable (EOF, cron/CI), the first available port
   starting from 8888 is taken as well.
7. Downloads the TrueConf Server for Linux installer from
   `trueconf.com/download/server/linux` (for Russian distributions — Astra,
   RED OS, ALT — from `download.trueconf.ru/download/server/linux`). The
   download goes into a private temporary directory created with `mktemp -d`
   (mode 0700). A `DL_DIR` override is honored only with `--allow-env-hooks`
   and is refused if it is a symlink, is not owned by the current user, or its
   parent is a symlink. Resilient curl: IPv4 only, resume via `-C -`, retries
   on errors (no `--retry-all-errors` — unavailable in curl < 7.71 on
   Astra/RED), aborts connections slower than 1 KB/s for 30 s. If the server
   returns an HTML page instead of a package, the download is treated as
   failed. The temporary directory is removed after installation, including on
   failure.
8. Installs TrueConf Server for Linux; panel administrators are set via
   `TCADMINS_USERS`. Package installation runs non-interactively
   (`DEBIAN_FRONTEND=noninteractive` on apt), so debconf questions never block
   cron/CI.
9. If the selected port ≠ 80, it is applied after installation
   (`/opt/trueconf/server/etc/webmanager/listen.conf` and
   `/opt/trueconf/server/etc/manager/manager.toml`) and the services are
   restarted. Only directives listening on the current port (80) are replaced:
   the address/options are preserved (`Listen 80` → `Listen 9000`,
   `Listen 0.0.0.0:80` → `Listen 0.0.0.0:9000`, `Listen 443 ssl` is left
   untouched), as is the connection scheme (`http`/`https`/`ws`). If the target
   directive or a configuration file is missing, an error is raised instead of
   silently skipping the change or appending duplicates (invalid TOML).
10. Prints the control panel URL, a registration reminder (Free: TCP port
    4310 to `reg.trueconf.com`) and an HTTPS reminder.
