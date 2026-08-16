#!/usr/bin/env bash
#
# Разворачивает русскую Omarchy с обновлённым шелл-окружением.
# Все шаги идемпотентны: скрипт можно гонять повторно, он меняет только то,
# что разошлось с эталоном, и делает бэкап перед каждой правкой.
#
#   ./install.sh                  все модули по порядку
#   ./install.sh keyboard menu    только указанные
#   ./install.sh --list           список модулей
#   ./install.sh --dry-run        показать, что было бы сделано
#   ./install.sh --force          пересобрать даже то, что уже стоит (ble.sh)
#   ./install.sh --skip-update    не запускать omarchy update на старой версии

# -E: ловушку ERR должны наследовать функции, иначе падение внутри ensure_block
# проходит мимо отчёта о том, какой модуль сломался.
set -Eeuo pipefail

RU_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export RU_ROOT

DRY_RUN=0
FORCE=0
SKIP_UPDATE=0
REQUIRED_MAJOR=4
selected=()

module_files=("$RU_ROOT"/modules/*.sh)
module_name() {
  local base=${1##*/}
  base=${base%.sh}
  printf '%s' "${base#*-}"
}

usage() {
  # Шапка файла до первой не-комментарной строки и есть справка.
  awk 'NR>2 && /^#/ { sub(/^# ?/, ""); print; next } NR>2 { exit }' "${BASH_SOURCE[0]}"
  printf '\nМодули:\n'
  local file
  for file in "${module_files[@]}"; do
    printf '  %-10s %s\n' "$(module_name "$file")" \
      "$(sed -n '2s/^# \{0,1\}//p' "$file")"
  done
}

while (($#)); do
  case $1 in
  --dry-run) DRY_RUN=1 ;;
  --force) FORCE=1 ;;
  --skip-update) SKIP_UPDATE=1 ;;
  --list | -l)
    usage
    exit 0
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*) echo "неизвестный флаг: $1" >&2 && exit 2 ;;
  *) selected+=("$1") ;;
  esac
  shift
done

export DRY_RUN FORCE SKIP_UPDATE REQUIRED_MAJOR
source "$RU_ROOT/lib/common.sh"

((EUID == 0)) && die "запускай от обычного пользователя — sudo скрипт попросит сам, когда понадобится"
[[ $OSTYPE == linux* ]] || die "рассчитано на Linux/Arch"

# Модуль omarchy проверяет версию и при необходимости обновляет систему,
# поэтому он идёт первым всегда, даже при выборочном запуске.
to_run=()
if ((${#selected[@]})); then
  for want in "${selected[@]}"; do
    match=""
    for file in "${module_files[@]}"; do
      [[ $(module_name "$file") == "$want" ]] && match=$file
    done
    [[ -n $match ]] || die "нет модуля «$want», список: ./install.sh --list"
    to_run+=("$match")
  done
  [[ ${to_run[0]} == *00-omarchy.sh ]] || to_run=("$RU_ROOT/modules/00-omarchy.sh" "${to_run[@]}")
else
  to_run=("${module_files[@]}")
fi

((DRY_RUN)) && log "режим --dry-run: система не меняется"

# Без этого модуль, упавший под set -e, обрывает установку молча.
CURRENT_MODULE=""
trap 'status=$?; [[ -n $CURRENT_MODULE ]] &&
  printf "  %s✗%s модуль «%s» прервался (код %d)\n" "$C_ERR" "$C_OFF" "$CURRENT_MODULE" "$status" >&2
  exit $status' ERR

for file in "${to_run[@]}"; do
  CURRENT_MODULE=$(module_name "$file")
  log "[$CURRENT_MODULE] $(sed -n '2s/^# \{0,1\}//p' "$file")"
  # shellcheck disable=SC1090
  source "$file"
done
CURRENT_MODULE=""

log "Готово."
cat <<'NOTE'

  Что нужно сделать руками:
    • перелогиниться в сессию — LANG=ru_RU.UTF-8 подхватят Hyprland,
      оболочка Omarchy и уже запущенные приложения;
    • открыть новый терминал — ble.sh, atuin и television живут в bash.

  Первый старт bash после установки ble.sh пару секунд молчит: он строит
  кеши раскладки клавиш. Это разово.
NOTE
