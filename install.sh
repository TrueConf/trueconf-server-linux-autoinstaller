#!/usr/bin/env bash
# install.sh — автоматическая установка TrueConf Server на Linux
# Automatic TrueConf Server installation for Linux
#
# Поддерживаемые ОС / Supported OS:
#   Debian 11/12/13, CentOS Stream 9, Astra Linux SE 1.7/1.8,
#   РЕД ОС 7.3/8, Альт Сервер 10/c10f2/11  (только x86_64)
#
# Запуск / Usage:
#   sudo bash install.sh [--admin-users=a,b] [--yes] [--port=NNNN]
#                        [--file=ФАЙЛ] [--version] [--help]

# Версия скрипта (хардкод) / Script version (hardcoded)
SCRIPT_VERSION="1.1"

# Привилегированные команды запускаются через sudo, если скрипт запущен
# не от root. Пустая строка — уже root, sudo не нужен.
if [[ "$(id -u)" -eq 0 ]] 2>/dev/null; then
  SUDO=""
else
  SUDO="sudo"
fi

# ============================================================================
# i18n
# ============================================================================

declare -A MSG_RU
declare -A MSG_EN

MSG_RU=(
  [msg_step_detect_os]="Определение операционной системы"
  [msg_step_check_user]="Проверка пользователя trueconf"
  [msg_step_check_installed]="Проверка отсутствия установленного TrueConf Server"
  [msg_step_repos]="Проверка и настройка репозиториев"
  [msg_step_update]="Обновление системных пакетов"
  [msg_step_port]="Проверка порта панели управления"
  [msg_step_download]="Скачивание инсталлятора TrueConf Server"
  [msg_step_install]="Установка TrueConf Server"
  [msg_step_port_apply]="Настройка порта панели управления"

  [msg_err_root]="Требуются права администратора: установите sudo или запустите скрипт от root"
  [msg_err_os_unsupported]="Операционная система не поддерживается TrueConf Server."
  [msg_supported_os_list]="Поддерживаемые ОС: Debian 11/12/13, CentOS Stream 9, Astra Linux SE 1.7/1.8, РЕД ОС 7.3/8, Альт Сервер 10/c10f2/11 (64-битные)."
  [msg_err_arch]="Поддерживается только 64-битная архитектура (x86_64)."
  [msg_err_user_exists]="В системе существует пользователь 'trueconf'. Установщик TrueConf Server создаёт его автоматически, поэтому он не должен существовать до установки. Удалите пользователя и повторите запуск."
  [msg_err_already_installed]="TrueConf Server уже установлен в системе. Удалите его и повторите запуск."
  [msg_err_repos]="Не найдены активные репозитории пакетов. Добавьте репозитории вручную и повторите запуск."
  [msg_err_download]="Не удалось скачать инсталлятор TrueConf Server. Проверьте доступ в интернет и повторите."
  [msg_err_install]="Ошибка при установке TrueConf Server. Смотрите вывод выше."
  [msg_err_bad_arg]="Неизвестный аргумент: %s"
  [msg_err_bad_admins]="Недопустимый список администраторов: %s. Ожидается список имён через запятую (без пробелов, до 32 символов, [A-Za-z0-9_.-])."
  [msg_err_file_mismatch]="Тип пакета .%s не подходит для этой ОС (ожидается .%s)."
  [msg_err_no_listen]="Не найдена директива Listen/connection для замены порта в конфигурации TrueConf Server."
  [msg_err_portcheck]="Не удалось проверить порт: не найдены утилиты ss или netstat."
  [msg_err_write]="Не удалось записать файл: %s."
  [msg_err_missing_repos]="Не найден обязательный репозиторий (%s). Добавьте его вручную и повторите запуск."

  [msg_repos_fixed]="Репозитории настроены."
  [msg_repos_uncommented]="Раскомментированы обязательные репозитории:"
  [msg_repos_enabled]="Включены обязательные репозитории:"

  [msg_os_found]="Обнаружена ОС: %s"
  [msg_repos_fixed]="Репозитории настроены."
  [msg_port_80_free]="Порт 80 свободен, будет использован по умолчанию."
  [msg_port_80_busy]="Порт 80 занят."
  [msg_port_prompt]="Введите номер порта [8888]: "
  [msg_port_invalid]="Недопустимый порт. Введите число от 1 до 65535."
  [msg_port_busy]="Порт %s уже занят. Выберите другой."
  [msg_port_chosen]="Выбран порт: %s"
  [msg_port_no_free]="Нет свободного порта в диапазоне 8888–65535."
  [msg_downloading_file]="Скачивание: %s"
  [msg_download_source]="Источник: %s"
  [msg_use_local_file]="Установка из локального файла: %s"
  [msg_install_done]="TrueConf Server установлен."
  [msg_port_apply_done]="Порт панели управления установлен: %s"

  [msg_success]="Установка завершена успешно!"
  [msg_panel_url]="Панель управления: http://%s:%s"
  [msg_register_reminder]="Зарегистрируйте сервер в панели управления. Для версии Free убедитесь, что доступен TCP-порт 4310 до reg.trueconf.com."
  [msg_update_skipped]="Обновление системных пакетов пропущено (--skip-update)."
  [msg_https_reminder]="Панель управления работает по HTTP. Для доступа по HTTPS настройте сертификат (раздел «Настройки веб и HTTPS» документации TrueConf)."
  [msg_err_dl_dir]="Небезопасный каталог загрузки: %s. Проверьте права и владельца."
  [msg_err_filemode]="Не удалось сохранить режим файла: %s."
  [msg_err_no_conf]="Конфигурационный файл панели не найден: %s. Порт не изменён — проверьте установленный пакет."

  [msg_help]="Использование: sudo bash install.sh [--admin-users=имя1,имя2] [--yes] [--port=NNNN] [--file=ФАЙЛ] [--skip-update] [--version] [--help]

  --admin-users=имя1,имя2  пользователи ОС с доступом к панели управления
  --yes                    без вопросов (при занятом порту 80 берётся первый свободный начиная с 8888)
  --port=NNNN              явно указать порт панели управления
  --file=ФАЙЛ              установка из локального файла без скачивания
  --version, -v            показать версию скрипта
  --skip-update             не обновлять системные пакеты
  --allow-env-hooks         учитывать TC_* и DL_DIR из окружения (только для тестов)
  --help                   показать эту справку"
)

MSG_EN=(
  [msg_step_detect_os]="Detecting operating system"
  [msg_step_check_user]="Checking for the 'trueconf' user"
  [msg_step_check_installed]="Checking that TrueConf Server is not installed yet"
  [msg_step_repos]="Checking and fixing package repositories"
  [msg_step_update]="Updating system packages"
  [msg_step_port]="Checking web panel port"
  [msg_step_download]="Downloading TrueConf Server installer"
  [msg_step_install]="Installing TrueConf Server"
  [msg_step_port_apply]="Configuring web panel port"

  [msg_err_root]="Administrator privileges required: install sudo or run the script as root"
  [msg_err_os_unsupported]="Operating system is not supported by TrueConf Server."
  [msg_supported_os_list]="Supported OS: Debian 11/12/13, CentOS Stream 9, Astra Linux SE 1.7/1.8, RED OS 7.3/8, ALT Server 10/c10f2/11 (64-bit)."
  [msg_err_arch]="Only 64-bit architecture (x86_64) is supported."
  [msg_err_user_exists]="User 'trueconf' already exists. The TrueConf Server installer creates it automatically, so it must not exist before installation. Remove the user and run again."
  [msg_err_already_installed]="TrueConf Server is already installed. Uninstall it and run again."
  [msg_err_repos]="No active package repositories found. Add repositories manually and run again."
  [msg_err_download]="Failed to download the TrueConf Server installer. Check internet access and retry."
  [msg_err_install]="Error installing TrueConf Server. See output above."
  [msg_err_bad_arg]="Unknown argument: %s"
  [msg_err_bad_admins]="Invalid administrator list: %s. Expected comma-separated user names (no spaces, up to 32 chars, [A-Za-z0-9_.-])."
  [msg_err_file_mismatch]="Package type .%s is not supported on this OS (expected .%s)."
  [msg_err_no_listen]="No Listen/connection directive found to replace the port in the TrueConf Server configuration."
  [msg_err_portcheck]="Cannot check the port: neither ss nor netstat is available."
  [msg_err_write]="Failed to write file: %s."
  [msg_err_missing_repos]="Required repository not found (%s). Add it manually and run again."

  [msg_repos_fixed]="Repositories are ready."
  [msg_repos_uncommented]="Uncommented required repositories:"
  [msg_repos_enabled]="Enabled required repositories:"

  [msg_os_found]="Detected OS: %s"
  [msg_repos_fixed]="Repositories are ready."
  [msg_port_80_free]="Port 80 is free, will be used by default."
  [msg_port_80_busy]="Port 80 is in use."
  [msg_port_prompt]="Enter port number [8888]: "
  [msg_port_invalid]="Invalid port. Enter a number from 1 to 65535."
  [msg_port_busy]="Port %s is already in use. Choose another."
  [msg_port_chosen]="Chosen port: %s"
  [msg_port_no_free]="No free port found in range 8888-65535."
  [msg_downloading_file]="Downloading: %s"
  [msg_download_source]="Source: %s"
  [msg_use_local_file]="Installing from local file: %s"
  [msg_install_done]="TrueConf Server installed."
  [msg_port_apply_done]="Web panel port set to: %s"

  [msg_success]="Installation completed successfully!"
  [msg_panel_url]="Web panel: http://%s:%s"
  [msg_register_reminder]="Register the server in the web panel. For the Free version, ensure TCP port 4310 to reg.trueconf.com is reachable."
  [msg_update_skipped]="System package update skipped (--skip-update)."
  [msg_https_reminder]="The web panel runs over HTTP. To use HTTPS, configure a certificate (see the 'Web and HTTPS settings' section of the TrueConf manual)."
  [msg_err_dl_dir]="Unsafe download directory: %s. Check permissions and owner."
  [msg_err_filemode]="Failed to preserve file mode: %s."
  [msg_err_no_conf]="Web panel configuration file not found: %s. Port was not changed — check the installed package."

  [msg_help]="Usage: sudo bash install.sh [--admin-users=user1,user2] [--yes] [--port=NNNN] [--file=FILE] [--skip-update] [--version] [--help]

  --admin-users=user1,user2  OS users with web panel access
  --yes                     non-interactive (if port 80 is busy, first free port from 8888 is used)
  --port=NNNN               explicitly set the web panel port
  --file=FILE               install from a local file, skip downloading
  --version, -v             show script version
  --skip-update              skip system package update
  --allow-env-hooks          honor TC_* and DL_DIR env overrides (test hooks only)
  --help                    show this help"
)

# Выбор языка по окружению (LANG/LC_ALL). LANG_CODE: ru | en
detect_lang() {
  local loc
  loc="${LC_ALL:-${LANG:-C}}"
  case "$loc" in
    ru*) LANG_CODE="ru" ;;
    *)   LANG_CODE="en" ;;
  esac
}

# _L KEY — возвращает сообщение для текущего языка (fallback: EN, затем сам ключ)
_L() {
  local key="$1"
  case "${LANG_CODE:-en}" in
    ru) printf '%s' "${MSG_RU[$key]:-${MSG_EN[$key]:-$key}}" ;;
    *)  printf '%s' "${MSG_EN[$key]:-$key}" ;;
  esac
}

# lmsg KEY [аргументы...] — печатает локализованное сообщение с аргументами
# shellcheck disable=SC2059
lmsg() {
  local key="$1"
  shift
  printf "$(_L "$key")\n" "$@"
}

step() {
  printf '\n== %s ==\n' "$(_L "$1")"
}

# ============================================================================
# Вспомогательные функции
# ============================================================================

# Чтение значения KEY из файла os-release (без внешних утилит)
osrel_get() {
  local file="$1" key="$2" line val
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "$key="*)
        val="${line#*=}"
        val="${val%\"}"
        val="${val#\"}"
        printf '%s' "$val"
        return 0
        ;;
    esac
  done < "$file"
  return 1
}

# os_version_major VER — первая числовая компонента версии (major).
# "1.7_x86-64"→1, "8.0"→8, "11"→11, "9 (Stream)"→9. 1 при неверном формате.
os_version_major() {
  if [[ "$1" =~ ^[[:space:]]*([[:digit:]]+)([.]|[[:space:]]|[-_]|$) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# os_version_major_minor VER — первые две числовые компоненты (major.minor).
# "1.7_x86-64"→1.7, "1.7.6"→1.7, "8.0"→8.0. 1, если minor отсутствует.
os_version_major_minor() {
  if [[ "$1" =~ ^[[:space:]]*([[:digit:]]+)[.]([[:digit:]]+)([.]|[[:space:]]|[-_]|$) ]]; then
    printf '%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}

unsupported_os() {
  printf '%s\n' "$(_L msg_err_os_unsupported)" >&2
  printf '%s\n' "$(_L msg_supported_os_list)" >&2
  return 1
}

# ============================================================================
# Определение ОС
# ============================================================================

TCDL_BASE="https://trueconf.com/download/server/linux"
# российские дистрибутивы (Astra, РЕД ОС, Альт) качаем с download.trueconf.ru:
# trueconf.ru отдаёт HTML-заглушку антибота вместо файла, а этот хост — прямой
TCDL_BASE_RU="https://download.trueconf.ru/download/server/linux"

# detect_os [FILE] — задаёт OS_ID, OS_VERSION_ID, OS_FAMILY (apt|dnf),
# OS_PKG_TYPE (deb|rpm), OS_INSTALLER_URL, OS_DISPLAY. 1 при неподдержке.
detect_os() {
  local f="${1:-${OS_RELEASE_FILE:-/etc/os-release}}"
  local id version_id version
  OS_ID=""
  OS_VERSION_ID=""
  OS_FAMILY=""
  OS_PKG_TYPE=""
  OS_INSTALLER_URL=""
  OS_DISPLAY=""

  [[ -r "$f" ]] || return $(unsupported_os)

  id="$(osrel_get "$f" ID)"
  version_id="$(osrel_get "$f" VERSION_ID)"
  version="$(osrel_get "$f" VERSION)"
  OS_ID="$id"

  case "$id" in
    debian)
      local major
      major="$(os_version_major "$version_id")" || return $(unsupported_os)
      case "$major" in
        11|12|13)
          OS_FAMILY="apt"; OS_PKG_TYPE="deb"
          OS_VERSION_ID="$major"
          OS_INSTALLER_URL="$TCDL_BASE/trueconf_server_debian${major}_amd64.deb"
          OS_DISPLAY="Debian $major"
          ;;
        *) return $(unsupported_os) ;;
      esac
      ;;
    centos)
      local major
      major="$(os_version_major "$version_id")" || return $(unsupported_os)
      if [[ "$major" == "9" ]]; then
        OS_FAMILY="dnf"; OS_PKG_TYPE="rpm"
        OS_VERSION_ID="9"
        OS_INSTALLER_URL="$TCDL_BASE/trueconf_server_centos_stream9_x86_64.rpm"
        OS_DISPLAY="CentOS Stream 9"
      else
        return $(unsupported_os)
      fi
      ;;
    astra)
      local minor
      minor="$(os_version_major_minor "$version_id")" || return $(unsupported_os)
      case "$minor" in
        1.7)
          OS_FAMILY="apt"; OS_PKG_TYPE="deb"
          OS_VERSION_ID="$minor"
          OS_INSTALLER_URL="$TCDL_BASE_RU/trueconf_server_astralinux_se17_amd64.deb"
          OS_DISPLAY="Astra Linux SE $minor"
          ;;
        1.8)
          OS_FAMILY="apt"; OS_PKG_TYPE="deb"
          OS_VERSION_ID="$minor"
          OS_INSTALLER_URL="$TCDL_BASE_RU/trueconf_server_astralinux_se18_amd64.deb"
          OS_DISPLAY="Astra Linux SE $minor"
          ;;
        *) return $(unsupported_os) ;;
      esac
      ;;
    redos)
      local major minor
      major="$(os_version_major "$version_id")" || return $(unsupported_os)
      minor="$(os_version_major_minor "$version_id")" || minor="$major"
      case "$minor" in
        7.3)
          OS_FAMILY="dnf"; OS_PKG_TYPE="rpm"
          OS_VERSION_ID="7.3"
          OS_INSTALLER_URL="$TCDL_BASE_RU/trueconf_server_redos7.3_x86_64.rpm"
          OS_DISPLAY="RED OS 7.3"
          ;;
        8|8.*)
          OS_FAMILY="dnf"; OS_PKG_TYPE="rpm"
          OS_VERSION_ID="8"
          OS_INSTALLER_URL="$TCDL_BASE_RU/trueconf_server_redos8.0_x86_64.rpm"
          OS_DISPLAY="RED OS 8"
          ;;
        *) return $(unsupported_os) ;;
      esac
      ;;
    altlinux)
      local major
      major="$(os_version_major "$version_id")" || return $(unsupported_os)
      case "$major" in
        10)
          OS_FAMILY="apt"; OS_PKG_TYPE="rpm"
          OS_VERSION_ID="10"
          if [[ "${version,,}" == *c10f2* ]]; then
            OS_INSTALLER_URL="$TCDL_BASE_RU/trueconf_server_basealt_sp10_x86_64.rpm"
            OS_DISPLAY="ALT Server 10 (c10f2)"
          else
            OS_INSTALLER_URL="$TCDL_BASE_RU/trueconf_server_basealt10_x86_64.rpm"
            OS_DISPLAY="ALT Server 10"
          fi
          ;;
        11)
          OS_FAMILY="apt"; OS_PKG_TYPE="rpm"
          OS_VERSION_ID="11"
          OS_INSTALLER_URL="$TCDL_BASE_RU/trueconf_server_basealt11_x86_64.rpm"
          OS_DISPLAY="ALT Server 11"
          ;;
        *) return $(unsupported_os) ;;
      esac
      ;;
    *)
      return $(unsupported_os)
      ;;
  esac
  lmsg msg_os_found "$OS_DISPLAY" >&2
}

# Проверка архитектуры (только x86_64)
check_arch() {
  local arch
  arch="$(uname -m)"
  [[ "$arch" == "x86_64" ]] && return 0
  printf '%s\n' "$(_L msg_err_arch)" >&2
  return 1
}

# Проверка, что пользователя trueconf нет в системе
check_trueconf_user() {
  if getent passwd trueconf >/dev/null 2>&1; then
    printf '%s\n' "$(_L msg_err_user_exists)" >&2
    return 1
  fi
  if ! command -v getent >/dev/null 2>&1 && grep -q '^trueconf:' /etc/passwd 2>/dev/null; then
    printf '%s\n' "$(_L msg_err_user_exists)" >&2
    return 1
  fi
  return 0
}

# Проверка, что TrueConf Server ещё не установлен
check_not_installed() {
  case "${OS_PKG_TYPE:-}" in
    rpm)
      if rpm -q trueconf-server >/dev/null 2>&1; then
        printf '%s\n' "$(_L msg_err_already_installed)" >&2
        return 1
      fi
      ;;
    *)
      if dpkg-query -W -f='${Status}' trueconf-server 2>/dev/null | grep -q 'install ok installed'; then
        printf '%s\n' "$(_L msg_err_already_installed)" >&2
        return 1
      fi
      ;;
  esac
  return 0
}

# ============================================================================
# Репозитории
# ============================================================================

# commit_tmp_file TMP TARGET — атомарная запись файла; при сбое удаляет TMP
# и сообщает об ошибке записи. 1 при ошибке.
commit_tmp_file() {
  local tmp="$1" target="$2"
  local mode owner group real
  # если цель — симлинк, правим реальный файл, ссылку не подменяем
  if [[ -L "$target" ]]; then
    real="$(readlink -f "$target" 2>/dev/null || true)"
    [[ -n "$real" && -e "$real" ]] && target="$real"
  fi
  # сохраняем права и владельца исходного файла
  mode="$(stat -c %a "$target" 2>/dev/null || true)"
  owner="$(stat -c %U "$target" 2>/dev/null || true)"
  group="$(stat -c %G "$target" 2>/dev/null || true)"
  $SUDO mv "$tmp" "$target" || { rm -f "$tmp"; lmsg msg_err_write "$target" >&2; return 1; }
  if [[ -n "$mode" ]] && ! $SUDO chmod "$mode" "$target" 2>/dev/null; then
    lmsg msg_err_filemode "$target" >&2
  fi
  if [[ -n "$owner" && -n "$group" ]]; then
    $SUDO chown "$owner:$group" "$target" 2>/dev/null || true
  fi
}

# _apt_required_active REQUIRED FILES... — 0, если обязательный дистрибутивный
# репозиторий активен. REQUIRED: для Debian — codename основной suite
# (11→bullseye, 12→bookworm, 13→trixie); для Astra — пуст; для Альт — активный
# rpm http(s). Покрывает и классические строки, и deb822 (.sources).
_apt_required_active() {
  local required="$1"; shift
  local files=("$@")
  local f line cur_types_deb stanza_disabled stanza_http stanza_match found=0
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    cur_types_deb=0
    stanza_disabled=0
    stanza_http=0
    stanza_match=0
    [[ -z "$required" ]] && stanza_match=1
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -z "$line" ]]; then
        [[ "$cur_types_deb" -eq 1 && "$stanza_disabled" -eq 0 \
           && "$stanza_http" -eq 1 && "$stanza_match" -eq 1 ]] && found=1
        cur_types_deb=0; stanza_disabled=0; stanza_http=0; stanza_match=0
        [[ -z "$required" ]] && stanza_match=1
      elif [[ "$line" =~ ^[[:space:]]*Types:[[:space:]]+deb([[:space:]]|$) ]] && [[ "$line" != \#* ]]; then
        cur_types_deb=1
      elif [[ "$line" != \#* ]] \
          && [[ "${OS_PKG_TYPE:-}" != "rpm" ]] \
          && [[ "$line" =~ ^[[:space:]]*Enabled:[[:space:]]+(no|false|0) ]]; then
        stanza_disabled=1
      elif [[ "$line" != \#* ]] \
          && [[ "$line" =~ ^[[:space:]]*URIs:[[:space:]]*https?:// ]]; then
        stanza_http=1
      elif [[ "$line" != \#* ]] && [[ "$line" =~ ^[[:space:]]*Suites:[[:space:]]+ ]] \
          && { [[ -z "$required" ]] || [[ "$line" == *"$required"* ]]; }; then
        stanza_match=1
      fi
      # классическая строка: активный http(s) репозиторий нужного типа
      if [[ "$line" != \#* ]]; then
        if [[ "${OS_PKG_TYPE:-}" == "rpm" ]]; then
          [[ "$line" =~ ^[[:space:]]*rpm([[:space:]]+\[[^]]*\])*[[:space:]]+https?:// ]] && found=1
        else
          [[ "$line" =~ ^[[:space:]]*deb([[:space:]]+\[[^]]*\])*[[:space:]]+https?:// ]] \
            && { [[ -z "$required" ]] || [[ "$line" == *"$required"* ]]; } && found=1
        fi
      fi
    done < "$f"
    [[ "$cur_types_deb" -eq 1 && "$stanza_disabled" -eq 0 \
       && "$stanza_http" -eq 1 && "$stanza_match" -eq 1 ]] && found=1
  done
  [[ "$found" -eq 1 ]]
}

# fix_apt_repos [FILE...] — правит apt-источники:
#   комментирует активные медиа-строки (deb cdrom: для Debian/Astra,
#   rpm/rpm-dir cdrom:/file:// для Альт). Обязательный дистрибутивный
#   репозиторий должен быть активен: если закомментирован — раскомментируется,
#   иначе — ошибка. 1 при ошибке.
fix_apt_repos() {
  local files=("$@")
  if [[ ${#files[@]} -eq 0 ]]; then
    if [[ -n "${TC_APT_FILES:-}" ]]; then
      IFS=: read -r -a files <<< "$TC_APT_FILES"
    else
      files=()
      local f
      [[ -f /etc/apt/sources.list ]] && files+=("/etc/apt/sources.list")
      for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [[ -f "$f" ]] && files+=("$f")
      done
    fi
  fi

  local f tmp line changed
  local media_re uncomment_re
  if [[ "${OS_PKG_TYPE:-}" == "rpm" ]]; then
    # Альт (apt-rpm): источники вида "rpm http://...", медиа — "rpm-dir file://..."
    media_re='^[[:space:]]*(rpm|rpm-dir)[[:space:]]+(cdrom:|file://)'
    uncomment_re='^#[[:space:]]*rpm([[:space:]]+\[[^]]*\])*[[:space:]]+https?://'
  else
    media_re='^[[:space:]]*deb[[:space:]]+cdrom:'
    uncomment_re='^#[[:space:]]*deb([[:space:]]+\[[^]]*\])*[[:space:]]+https?://'
  fi

  # обязательный репозиторий: для Debian — основная suite (codename)
  local required=""
  if [[ "${OS_ID:-}" == "debian" ]]; then
    case "${OS_VERSION_ID:-}" in
      11) required="bullseye" ;;
      12) required="bookworm" ;;
      13) required="trixie" ;;
    esac
  fi

  # 1. комментируем активные медиа-строки
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    tmp="$(mktemp "${TMPDIR:-/tmp}/tcs-repo.XXXXXX")" || { lmsg msg_err_write "$f" >&2; return 1; }
    changed=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ $media_re ]] && [[ "$line" != \#* ]]; then
        printf '#%s\n' "$line" >> "$tmp"
        changed=1
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$f"
    if [[ "$changed" -eq 1 ]]; then
      commit_tmp_file "$tmp" "$f" || return 1
    else
      rm -f "$tmp"
    fi
  done

  # 2. обязательный дистрибутивный репозиторий активен?
  if ! _apt_required_active "$required" "${files[@]}"; then
    # 3. раскомментируем закомментированный обязательный кандидат
    local uncommented=0
    local -a uncommented_list=()
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || continue
      tmp="$(mktemp "${TMPDIR:-/tmp}/tcs-repo.XXXXXX")" || { lmsg msg_err_write "$f" >&2; return 1; }
      changed=0
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ $uncomment_re && ( -z "$required" || "$line" == *"$required"* ) ]]; then
          local clean="${line#\#}"
          clean="${clean#"${clean%%[![:space:]]*}"}"
          printf '%s\n' "$clean" >> "$tmp"
          uncommented=$((uncommented + 1))
          uncommented_list+=("$clean")
          changed=1
        else
          printf '%s\n' "$line" >> "$tmp"
        fi
      done < "$f"
      if [[ "$changed" -eq 1 ]]; then
        commit_tmp_file "$tmp" "$f" || return 1
      else
        rm -f "$tmp"
      fi
    done
    # уведомление о раскомментировании
    if [[ "$uncommented" -gt 0 ]]; then
      lmsg msg_repos_uncommented
      printf '  - %s\n' "${uncommented_list[@]}"
    fi
    # повторная проверка после раскомментирования
    if [[ "$uncommented" -eq 0 ]] || ! _apt_required_active "$required" "${files[@]}"; then
      local miss="${required:-network repo}"
      [[ "${OS_PKG_TYPE:-}" == "rpm" ]] && [[ -z "$required" ]] && miss="rpm http(s) repo"
      lmsg msg_err_missing_repos "$miss" >&2
      return 1
    fi
  fi
  return 0
}

# _dnf_media_sections FILE — печатает заголовки секций, в которых встречается
# baseurl=file:// (порядок ключей в секции не гарантирован → двухпроходный разбор)
_dnf_media_sections() {
  local found_media=""
  local header=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*\[ ]]; then
      if [[ -n "$header" ]] && [[ -n "$found_media" ]]; then
        printf '%s\n' "$header"
      fi
      found_media=""
      header="$line"
    elif [[ "$line" =~ ^[[:space:]]*baseurl[[:space:]]*=[[:space:]]*file:// ]]; then
      found_media=1
    fi
  done < "$1"
  if [[ -n "$header" ]] && [[ -n "$found_media" ]]; then
    printf '%s\n' "$header"
  fi
}

# _section_is_media HEADER — 0, если заголовок HEADER есть в media_sections
_section_is_media() {
  local s
  for s in "${media_sections[@]}"; do
    [[ "$1" == "$s" ]] && return 0
  done
  return 1
}

# _dnf_has_network_repo FILES... — 0, если есть включённый http(s) репозиторий
# (baseurl http(s), mirrorlist http(s)/file:// со списком https-зеркал, metalink
# http(s)), не media и не debug/source. Секция без ключа enabled=
# считается включённой по умолчанию (семантика dnf/yum).
_dnf_has_network_repo() {
  local files=("$@")
  local f line section enabled http mf ml
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    section=""; enabled=1; http=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^[[:space:]]*\[[^]]+\] ]]; then
        if [[ "$enabled" -eq 1 && "$http" -eq 1 \
              && "${section,,}" != *debug* && "${section,,}" != *source* ]]; then
          return 0
        fi
        section="$line"; enabled=1; http=0
      elif [[ "$line" =~ ^[[:space:]]*enabled[[:space:]]*=[[:space:]]*0 ]]; then
        enabled=0
      elif [[ "$line" =~ ^[[:space:]]*enabled[[:space:]]*=[[:space:]]*1 ]]; then
        enabled=1
      elif [[ "$line" =~ ^[[:space:]]*(baseurl|mirrorlist|metalink)[[:space:]]*=[[:space:]]*https?:// ]]; then
        http=1
      elif [[ "$line" =~ ^[[:space:]]*mirrorlist[[:space:]]*=[[:space:]]*file://(.+) ]]; then
        # РЕД/аналоги: зеркальный список в локальном файле — сетевой,
        # если внутри есть https-строки ($basearch раскрывать не нужно)
        mf="${BASH_REMATCH[1]}"
        if [[ -f "$mf" ]]; then
          while IFS= read -r ml || [[ -n "$ml" ]]; do
            [[ "$ml" =~ ^[[:space:]]*(https?://) ]] && http=1
          done < "$mf"
        fi
      fi
    done < "$f"
    if [[ "$enabled" -eq 1 && "$http" -eq 1 \
          && "${section,,}" != *debug* && "${section,,}" != *source* ]]; then
      return 0
    fi
  done
  return 1
}

# _dnf_disabled_distro_repos FILES... — 0, если в файлах есть отключённая
# секция дистрибутивного репозитория: для CentOS — baseos/appstream,
# для РЕД ОС — base/updates. Media/debug/source не учитываются.
# Если подходящих секций нет вовсе — 1 (не блокируем нестандартные системы).
_dnf_disabled_distro_repos() {
  local files=("$@")
  local f line s hdr want
  local -a ids=() media_sections=()
  case "${OS_ID:-}" in
    centos) ids=(baseos appstream) ;;
    redos)  ids=(base updates) ;;
    *)      return 1 ;;
  esac
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    mapfile -t media_sections < <(_dnf_media_sections "$f")
    s=""; hdr=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^[[:space:]]*\[([^]]+)\] ]]; then
        s="${BASH_REMATCH[1]}"
        hdr="$line"
      elif [[ "$line" =~ ^[[:space:]]*enabled[[:space:]]*=[[:space:]]*(0|1) ]] \
          && [[ "${BASH_REMATCH[1]}" == "0" && -n "$s" ]]; then
        _section_is_media "$hdr" && continue
        s="${s,,}"
        [[ "$s" == *debug* || "$s" == *source* ]] && continue
        for want in "${ids[@]}"; do
          [[ "$s" == *"$want"* ]] && return 0
        done
      fi
    done < "$f"
  done
  return 1
}

# fix_dnf_repos [FILE...] — правит dnf/yum-репозитории:
#   отключает локальные медиа-репозитории (baseurl=file://), при отсутствии
#   включённых включает стандартные (кроме debug/source). 1 при ошибке.
fix_dnf_repos() {
  local files=("$@")
  if [[ ${#files[@]} -eq 0 ]]; then
    if [[ -n "${TC_DNF_FILES:-}" ]]; then
      IFS=: read -r -a files <<< "$TC_DNF_FILES"
    else
      files=()
      local f
      for f in /etc/yum.repos.d/*.repo /etc/dnf/repos.d/*.repo /etc/zypp/repos.d/*.repo; do
        [[ -f "$f" ]] && files+=("$f")
      done
    fi
  fi

  local f tmp line changed section in_media media_sections

  # 1. отключаем медиа-репозитории (медиа-секции известны заранее — порядок ключей не важен)
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    mapfile -t media_sections < <(_dnf_media_sections "$f")
    tmp="$(mktemp "${TMPDIR:-/tmp}/tcs-repo.XXXXXX")" || { lmsg msg_err_write "$f" >&2; return 1; }
    changed=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^[[:space:]]*\[ ]]; then
        in_media=0
        _section_is_media "$line" && in_media=1
        printf '%s\n' "$line" >> "$tmp"
      elif [[ "$line" =~ ^[[:space:]]*enabled[[:space:]]*=[[:space:]]*1 ]] && [[ "$in_media" -eq 1 ]]; then
        printf 'enabled=0\n' >> "$tmp"
        changed=1
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$f"
    if [[ "$changed" -eq 1 ]]; then
      commit_tmp_file "$tmp" "$f" || return 1
    else
      rm -f "$tmp"
    fi
  done

  # 2. включённый сетевой репозиторий уже есть? (секция без enabled= = включена)
  #    Дистрибутивные (baseos/appstream, base/updates) включаем и тогда, когда
  #    какой-то сторонний репозиторий уже включён: иначе базовые зависимости
  #    (sqlite-libs и др.) не находятся.
  if ! _dnf_has_network_repo "${files[@]}" || _dnf_disabled_distro_repos "${files[@]}"; then
    # 3. включаем стандартные (не media, не debug/source)
    local enabled_any=0
    local -a enabled_list=()
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || continue
      mapfile -t media_sections < <(_dnf_media_sections "$f")
      tmp="$(mktemp "${TMPDIR:-/tmp}/tcs-repo.XXXXXX")" || { lmsg msg_err_write "$f" >&2; return 1; }
      changed=0
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*\[ ]]; then
          section="$line"
          in_media=0
          _section_is_media "$line" && in_media=1
          printf '%s\n' "$line" >> "$tmp"
        elif [[ "$line" =~ ^[[:space:]]*enabled[[:space:]]*=[[:space:]]*0 ]] && [[ "$in_media" -eq 0 ]]; then
          if [[ "${section,,}" != *debug* && "${section,,}" != *source* ]]; then
            printf 'enabled=1\n' >> "$tmp"
            enabled_any=1
            enabled_list+=("$section")
            changed=1
          else
            printf '%s\n' "$line" >> "$tmp"
          fi
        else
          printf '%s\n' "$line" >> "$tmp"
        fi
      done < "$f"
      if [[ "$changed" -eq 1 ]]; then
        commit_tmp_file "$tmp" "$f" || return 1
      else
        rm -f "$tmp"
      fi
    done
    # уведомление о включении стандартных репозиториев
    if [[ "$enabled_any" -gt 0 ]]; then
      lmsg msg_repos_enabled
      printf '  - %s\n' "${enabled_list[@]}"
    fi
    if [[ "$enabled_any" -eq 0 ]]; then
      lmsg msg_err_missing_repos "enabled http(s) repo" >&2
      return 1
    fi
  fi
  if ! _dnf_has_network_repo "${files[@]}"; then
    lmsg msg_err_missing_repos "enabled http(s) repo" >&2
    return 1
  fi
  # дистрибутивные репозитории должны остаться включёнными
  if _dnf_disabled_distro_repos "${files[@]}"; then
    local miss="baseos/appstream"
    [[ "${OS_ID:-}" == "redos" ]] && miss="base/updates"
    lmsg msg_err_missing_repos "$miss" >&2
    return 1
  fi
  return 0
}

# prepare_centos — установка EPEL для CentOS (нужен для зависимостей TCSL).
prepare_centos() {
  $SUDO dnf install -y epel-release || return 1
  return 0
}

# update_packages — обновление системных пакетов и установка curl
update_packages() {
  case "${OS_FAMILY:-}" in
    apt)
      case "${OS_ID:-}" in
        astra)    $SUDO apt-get update && $SUDO apt-get upgrade --enable-upgrade -y && $SUDO apt-get install -y curl gnupg2 ;;
        altlinux) $SUDO apt-get update -y && $SUDO apt-get install -y curl gnupg ;;
        *)        $SUDO apt-get update && $SUDO apt-get upgrade -y && $SUDO apt-get install -y curl gnupg2 ;;
      esac
      ;;
    dnf)
      $SUDO dnf update -y && $SUDO dnf install -y curl
      ;;
    *) return 1 ;;
  esac
}

# ensure_curl — гарантирует наличие curl перед скачиванием. Актуально при
# --skip-update: на минимальной системе curl может отсутствовать, и скачивание
# упало бы с невнятной ошибкой.
ensure_curl() {
  command -v curl >/dev/null 2>&1 && return 0
  case "${OS_FAMILY:-}" in
    apt) $SUDO apt-get install -y curl || return 1 ;;
    dnf) $SUDO dnf install -y curl || return 1 ;;
    *)   return 1 ;;
  esac
}

# ============================================================================
# Выбор порта панели управления
# ============================================================================

# port_in_use PORT — 0, если TCP-порт занят (ss, при его отсутствии netstat).
# 2, если нет ни одной утилиты (неизвестно — занят или свободен).
# Флаг -n обязателен: без него ss/netstat выводят имя сервиса вместо номера
# порта (80 → :http), и числовое сравнение не сработает.
port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnn | awk -v p=":$port" '$4 ~ (p "$") { found = 1 } END { exit !found }'
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnn | awk -v p=":$port" '$4 ~ (p "$") { found = 1 } END { exit !found }'
  else
    return 2
  fi
}

# pick_auto_port — первый свободный порт начиная с 8888; задаёт PANEL_PORT
pick_auto_port() {
  local candidate=8888 rc
  while :; do
    port_in_use "$candidate"
    rc=$?
    if [[ $rc -eq 2 ]]; then
      lmsg msg_err_portcheck >&2
      return 1
    fi
    if [[ $rc -eq 1 ]]; then
      PANEL_PORT="$candidate"
      lmsg msg_port_chosen "$PANEL_PORT"
      return 0
    fi
    candidate=$((candidate + 1))
    if (( candidate > 65535 )); then
      lmsg msg_port_no_free >&2
      return 1
    fi
  done
}

# select_port — выбор порта панели управления; задаёт PANEL_PORT.
# Учитывает --port (явное указание). Занятый порт (включая явный --port) ведёт
# к повторному запросу; в режиме --yes берётся первый свободный начиная с 8888.
# Ввод: только цифры 1–65535 (защита от переполнения — не более 5 цифр).
select_port() {
  local ans rc
  if [[ -n "${OPT_PORT:-}" ]]; then
    if ! [[ "$OPT_PORT" =~ ^[0-9]+$ ]] || (( ${#OPT_PORT} > 5 )) \
        || ! (( 10#$OPT_PORT >= 1 && 10#$OPT_PORT <= 65535 )); then
      lmsg msg_port_invalid >&2
      return 1
    fi
    port_in_use "$OPT_PORT"; rc=$?
    [[ $rc -eq 2 ]] && { lmsg msg_err_portcheck >&2; return 1; }
    if [[ $rc -eq 1 ]]; then
      PANEL_PORT="$OPT_PORT"
      lmsg msg_port_chosen "$PANEL_PORT"
      return 0
    fi
    lmsg msg_port_busy "$OPT_PORT"
  else
    port_in_use 80; rc=$?
    [[ $rc -eq 2 ]] && { lmsg msg_err_portcheck >&2; return 1; }
    if [[ $rc -eq 1 ]]; then
      lmsg msg_port_80_free
      PANEL_PORT="80"
      return 0
    fi
    lmsg msg_port_80_busy
  fi

  if [[ "${OPT_YES:-0}" == "1" ]]; then
    pick_auto_port
    return $?
  fi

  while :; do
    printf '%s' "$(_L msg_port_prompt)"
    IFS= read -r ans || {
      # EOF (не-интерактив: cron/CI): авто-выбор вместо вечного цикла
      pick_auto_port
      return $?
    }
    ans="${ans:-8888}"
    if [[ "$ans" =~ ^[0-9]+$ ]] && (( ${#ans} <= 5 )) \
        && (( 10#$ans >= 1 && 10#$ans <= 65535 )); then
      port_in_use "$ans"; rc=$?
      if [[ $rc -eq 2 ]]; then
        lmsg msg_err_portcheck >&2
        return 1
      fi
      if [[ $rc -eq 0 ]]; then
        lmsg msg_port_busy "$ans"
        continue
      fi
      PANEL_PORT="$ans"
      lmsg msg_port_chosen "$PANEL_PORT"
      return 0
    fi
    lmsg msg_port_invalid
  done
}

# ============================================================================
# Скачивание и установка
# ============================================================================

# _is_html_file FILE — 0, если FILE похож на HTML-страницу, а не на пакет.
# Защита от случая, когда сервер отдаёт антибот-заглушку с кодом 200.
_is_html_file() {
  head -c 512 "$1" 2>/dev/null | grep -qiE '<!doctype[[:space:]]+html|<html[[:space:]>]'
}

# download_installer — скачивание инсталлятора (или использование --file);
# задаёт INSTALLER_FILE. Устойчивый curl: докачка (-C -), отсечка медленных
# соединений (--speed-limit/--speed-time), только IPv4 (-4), повторы при ошибках.
download_installer() {
  if [[ -n "${OPT_FILE:-}" ]]; then
    # относительный путь → абсолютный: без «/» apt/dnf сочтут аргумент
    # именем пакета из репозитория, а не локальным файлом
    [[ "$OPT_FILE" == /* ]] || OPT_FILE="$PWD/$OPT_FILE"
    if [[ -r "$OPT_FILE" && -s "$OPT_FILE" ]]; then
      if [[ "$OPT_FILE" != *".${OS_PKG_TYPE:-}" ]]; then
        lmsg msg_err_file_mismatch "${OPT_FILE##*.}" "${OS_PKG_TYPE:-}" >&2
        return 1
      fi
      INSTALLER_FILE="$OPT_FILE"
      lmsg msg_use_local_file "$OPT_FILE"
      return 0
    fi
    lmsg msg_err_download >&2
    return 1
  fi

  local url="${OS_INSTALLER_URL:-}" fname dest dl_base
  local curl_opts=(-fL -4 --retry 3 --retry-delay 2 \
                  --connect-timeout 30 --speed-limit 1024 --speed-time 30)
  [[ -n "$url" ]] || { lmsg msg_err_download >&2; return 1; }
  fname="${url##*/}"
  [[ -n "$fname" ]] || { lmsg msg_err_download >&2; return 1; }

  # безопасный каталог загрузки: не симлинк, наш каталог, только нам доступ
  if [[ "${OPT_ALLOW_ENV:-0}" == "1" && -n "${DL_DIR:-}" ]]; then
    dl_base="$DL_DIR"
    DL_IS_TEMP=0
  else
    dl_base="$(mktemp -d "${TMPDIR:-/tmp}/tcs-installer.XXXXXX" 2>/dev/null)" \
      || { lmsg msg_err_download >&2; return 1; }
    DL_IS_TEMP=1
  fi
  if [[ -e "$dl_base" ]]; then
    if [[ -L "$dl_base" ]] || ! [[ -O "$dl_base" ]]; then
      lmsg msg_err_dl_dir "$dl_base" >&2
      return 1
    fi
  else
    # родитель не должен быть симлинком (обход через чужой каталог)
    if [[ -L "$(dirname "$dl_base")" ]]; then
      lmsg msg_err_dl_dir "$dl_base" >&2
      return 1
    fi
    mkdir -p "$dl_base" || { lmsg msg_err_dl_dir "$dl_base" >&2; return 1; }
    if [[ -L "$dl_base" ]] || ! [[ -O "$dl_base" ]]; then
      lmsg msg_err_dl_dir "$dl_base" >&2
      return 1
    fi
  fi
  chmod 700 "$dl_base" 2>/dev/null || true
  if [[ "${DL_IS_TEMP:-0}" == "0" ]]; then
    local _dl_real
    _dl_real="$(readlink -f "$dl_base" 2>/dev/null || true)"
    [[ -n "$_dl_real" && "$_dl_real" == "${dl_base%/}" ]] || { lmsg msg_err_dl_dir "$dl_base" >&2; return 1; }
  fi
  dest="$dl_base/$fname"

  DL_CACHE_DIR="$dl_base"
  lmsg msg_download_source "$url"

  if [[ -s "$dest" ]]; then
    if curl "${curl_opts[@]}" -C - -o "$dest" "$url" && ! _is_html_file "$dest"; then
      INSTALLER_FILE="$dest"
      return 0
    fi
  fi
  if curl "${curl_opts[@]}" -o "$dest" "$url" && [[ -s "$dest" ]] && ! _is_html_file "$dest"; then
    INSTALLER_FILE="$dest"
    return 0
  fi
  rm -f "$dest"
  if [[ "${DL_IS_TEMP:-0}" == "1" && -n "${DL_CACHE_DIR:-}" ]]; then
    rm -rf "$DL_CACHE_DIR" 2>/dev/null || true
  fi
  lmsg msg_err_download >&2
  return 1
}

# cleanup_download — удаляет скачанный инсталлятор; временный (mktemp) каталог
# убирается целиком, а test-каталог DL_DIR не трогаем (там могут быть свои файлы).
cleanup_download() {
  [[ -n "${OPT_FILE:-}" ]] && return 0
  if [[ "${DL_IS_TEMP:-0}" == "1" ]]; then
    rm -rf "${DL_CACHE_DIR:-}" 2>/dev/null || true
  else
    rm -f "${INSTALLER_FILE:-}" 2>/dev/null || true
  fi
}

# install_tcsl [FILE] — установка TCSL, администраторы через TCADMINS_USERS.
# DEBIAN_FRONTEND=noninteractive — чтобы apt не завис на debconf-вопросе
# в cron/CI и неинтерактивных сценариях (--yes, EOF).
install_tcsl() {
  local file="${1:-${INSTALLER_FILE:-}}"
  [[ -n "$file" ]] || { lmsg msg_err_install >&2; return 1; }
  case "${OS_FAMILY:-}" in
    apt)
      if [[ -n "${OPT_ADMINS:-}" ]]; then
        $SUDO env TCADMINS_USERS="$OPT_ADMINS" DEBIAN_FRONTEND=noninteractive apt-get install -y "$file" \
          || { lmsg msg_err_install >&2; return 1; }
      else
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$file" \
          || { lmsg msg_err_install >&2; return 1; }
      fi
      ;;
    dnf)
      if [[ -n "${OPT_ADMINS:-}" ]]; then
        $SUDO env TCADMINS_USERS="$OPT_ADMINS" dnf install -y "$file" || { lmsg msg_err_install >&2; return 1; }
      else
        $SUDO dnf install -y "$file" || { lmsg msg_err_install >&2; return 1; }
      fi
      ;;
    *) lmsg msg_err_install >&2; return 1 ;;
  esac
}

# _rewrite_file FILE TRANSFORM — читает FILE и для каждой строки вызывает
# TRANSFORM "$line". TRANSFORM печатает изменённую строку и возвращает 0, если
# целевой директивы коснулись, либо печатает строку без изменений и возвращает 1.
# Без цели — msg_err_no_listen; запись через commit_tmp_file.
_rewrite_file() {
  local file="$1" transform="$2"
  local tmp line out done=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/tcs-conf.XXXXXX")" || { lmsg msg_err_write "$file" >&2; return 1; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    if out="$("$transform" "$line")"; then
      done=1
    fi
    printf '%s\n' "${out:-$line}" >> "$tmp"
  done < "$file"
  if [[ "$done" -eq 0 ]]; then
    rm -f "$tmp"
    lmsg msg_err_no_listen >&2
    return 1
  fi
  commit_tmp_file "$tmp" "$file" || return 1
}

# _webconf_transform LINE — замена Listen на PORT там, где слушают OLPORT
# (сохраняются адрес и опции). PORT/OLDPORT видны через динамическую область.
_webconf_transform() {
  local line="$1"
  if [[ "$line" =~ ^[[:space:]]*Listen[[:space:]]+([^[:space:]]+):([0-9]+)([[:space:]]+.*)?$ ]]; then
    if [[ "${BASH_REMATCH[2]}" == "$oldport" ]]; then
      printf 'Listen %s:%s%s\n' "${BASH_REMATCH[1]}" "$port" "${BASH_REMATCH[3]}"
      return 0
    fi
  elif [[ "$line" =~ ^[[:space:]]*Listen[[:space:]]+([0-9]+)([[:space:]]+.*)?$ ]]; then
    if [[ "${BASH_REMATCH[1]}" == "$oldport" ]]; then
      printf 'Listen %s%s\n' "$port" "${BASH_REMATCH[2]}"
      return 0
    fi
  fi
  printf '%s\n' "$line"
  return 1
}

# _mgrconf_transform LINE — замена connection на PORT (схема сохраняется)
_mgrconf_transform() {
  local line="$1"
  if [[ "$line" =~ ^[[:space:]]*connection[[:space:]]*=[[:space:]]*\"([a-z]+)://([^:/]+):([0-9]+)\" ]]; then
    if [[ "${BASH_REMATCH[3]}" == "$oldport" ]]; then
      printf 'connection = "%s://127.0.0.1:%s"\n' "${BASH_REMATCH[1]}" "$port"
      return 0
    fi
  fi
  printf '%s\n' "$line"
  return 1
}

# configure_port PORT [OLDPORT] — применяет порт панели управления после установки.
# Меняет только директивы, слушающие на OLDPORT (по умолчанию 80), сохраняя
# адрес/опции (Listen) и схему (http/https/ws в connection). Остальные не трогаются.
# 1 при отсутствии целевой директивы или конфигурационного файла.
configure_port() {
  local port="$1"
  local oldport="${2:-80}"
  local webconf="${TC_WEB_CONF:-/opt/trueconf/server/etc/webmanager/listen.conf}"
  local mgrconf="${TC_MGR_CONF:-/opt/trueconf/server/etc/manager/manager.toml}"
  if [[ ! -f "$webconf" ]]; then
    lmsg msg_err_no_conf "$webconf" >&2
    return 1
  fi
  if [[ ! -f "$mgrconf" ]]; then
    lmsg msg_err_no_conf "$mgrconf" >&2
    return 1
  fi

  _rewrite_file "$webconf" _webconf_transform || return 1
  _rewrite_file "$mgrconf" _mgrconf_transform || return 1

  $SUDO systemctl restart trueconf-manager trueconf-web || return 1
  lmsg msg_port_apply_done "$port"
}

# ============================================================================
# Аргументы командной строки
# ============================================================================

# validate_admins LIST — проверка формата списка администраторов:
# имена через запятую, без пробелов, до 32 символов [A-Za-z0-9_.-].
# Нормализует OPT_ADMINS (тримминг пробелов вокруг имён). 1 при ошибке.
validate_admins() {
  local list="$1" u norm="" tokens
  if [[ -n "$list" ]]; then
    IFS=, read -r -a tokens <<< "$list"
    for u in "${tokens[@]}"; do
      u="${u#"${u%%[![:space:]]*}"}"
      u="${u%"${u##*[![:space:]]}"}"
      if [[ -z "$u" ]] || (( ${#u} > 32 )) || [[ ! "$u" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]]; then
        lmsg msg_err_bad_admins "$list" >&2
        return 1
      fi
      norm="${norm:+$norm,}$u"
    done
    OPT_ADMINS="$norm"
  fi
  return 0
}

# parse_args — разбор аргументов:
#   --admin-users=, --yes, --port=, --file=, --skip-update, --allow-env-hooks,
#   --help, --version/-v
parse_args() {
  OPT_ADMINS=""
  OPT_YES=0
  OPT_PORT=""
  OPT_FILE=""
  OPT_SKIP_UPDATE=0
  OPT_ALLOW_ENV=0
  local a
  for a in "$@"; do
    case "$a" in
      --admin-users=*)
        OPT_ADMINS="${a#--admin-users=}"
        validate_admins "$OPT_ADMINS" || exit 1
        ;;
      --yes)             OPT_YES=1 ;;
      --port=*)          OPT_PORT="${a#--port=}" ;;
      --file=*)          OPT_FILE="${a#--file=}" ;;
      --skip-update)     OPT_SKIP_UPDATE=1 ;;
      --allow-env-hooks) OPT_ALLOW_ENV=1 ;;
      --help|-h)       printf '%s\n' "$(_L msg_help)"; exit 0 ;;
      --version|-v)    printf 'trueconf-server-auto-installer %s\n' "$SCRIPT_VERSION"; exit 0 ;;
      *)               lmsg msg_err_bad_arg "$a" >&2; exit 1 ;;
    esac
  done
}

# ============================================================================
# Основной поток
# ============================================================================

# _on_exit — EXIT-обработчик: убирает временный каталог загрузки (в т.ч.
# при сбое установки). Сигналы HUP/INT/TERM завершаются через exit,
# поэтому проходят здесь же.
_on_exit() {
  cleanup_download
}

# _require_sudo — 1, если нужен sudo, но его нет в PATH
_require_sudo() {
  if [[ -n "${SUDO:-}" ]] && ! command -v sudo >/dev/null 2>&1; then
    lmsg msg_err_root >&2
    return 1
  fi
  return 0
}

main() {
  set -uo pipefail

  detect_lang
  parse_args "$@" || exit 1

  # уборка и восстановление при любом выходе, включая обрыв сессии/сигналы
  trap '_on_exit' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  # По умолчанию игнорируем тестовые env-хуки (безопасно при sudo с пробросом env)
  if [[ "${OPT_ALLOW_ENV:-0}" != "1" ]]; then
    unset DL_DIR TC_APT_FILES TC_DNF_FILES TC_WEB_CONF TC_MGR_CONF
  fi

  # Привилегированные команды идут через sudo: проверяем, что он есть
  _require_sudo || exit 1

  step msg_step_detect_os
  detect_os || exit 1

  check_arch || exit 1

  step msg_step_check_user
  check_trueconf_user || exit 1

  step msg_step_check_installed
  check_not_installed || exit 1

  step msg_step_repos
  case "${OS_FAMILY:-}" in
    apt) fix_apt_repos || exit 1 ;;
    dnf) fix_dnf_repos || exit 1 ;;
    *)   exit 1 ;;
  esac
  lmsg msg_repos_fixed

  if [[ "${OS_ID:-}" == "centos" ]]; then
    prepare_centos || exit 1
  fi

  step msg_step_update
  if [[ "${OPT_SKIP_UPDATE:-0}" == "1" ]]; then
    lmsg msg_update_skipped
  else
    update_packages || exit 1
  fi

  step msg_step_port
  select_port || exit 1

  step msg_step_download
  if [[ -z "${OPT_FILE:-}" ]]; then
    ensure_curl || exit 1
  fi
  download_installer || exit 1

  step msg_step_install
  install_tcsl || exit 1
  lmsg msg_install_done

  if [[ "${PANEL_PORT:-80}" != "80" ]]; then
    step msg_step_port_apply
    configure_port "$PANEL_PORT" || exit 1
  fi

  printf '\n%s\n' "$(_L msg_success)"
  lmsg msg_panel_url "$(hostname)" "${PANEL_PORT:-80}"
  printf '%s\n' "$(_L msg_register_reminder)"
  printf '%s\n' "$(_L msg_https_reminder)"
}

# запуск из файла (BASH_SOURCE == $0) или из pipe (BASH_SOURCE пуст)
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
