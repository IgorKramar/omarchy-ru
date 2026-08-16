#!/usr/bin/env bash
# Помощники, общие для всех модулей. Подключается из install.sh.

: "${RU_ROOT:?lib/common.sh подключается только из install.sh}"
: "${DRY_RUN:=0}"
: "${FORCE:=0}"

if [[ -t 1 ]]; then
  C_OK=$'\e[32m' C_WARN=$'\e[33m' C_ERR=$'\e[31m' C_DIM=$'\e[2m' C_OFF=$'\e[0m'
else
  C_OK='' C_WARN='' C_ERR='' C_DIM='' C_OFF=''
fi

log() { printf '%s==>%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
ok() { printf '  %s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
die() {
  printf '  %s✗%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2
  exit 1
}

# Путь для показа человеку: /home/user/... -> ~/...
short() { printf '%s' "${1/#$HOME/\~}"; }

# Выполнить команду, уважая --dry-run.
run() {
  if ((DRY_RUN)); then
    printf '  %s(dry-run)%s %s\n' "$C_DIM" "$C_OFF" "$*"
    return 0
  fi
  "$@"
}

# Копия файла с меткой времени. Молча уходит, если файла ещё нет.
backup() {
  local file=$1
  [[ -e $file ]] || return 0
  local copy
  copy="$file.bak.$(date +%s)"
  run cp -a "$file" "$copy"
  ok "бэкап: $(short "$copy")"
}

# Установить файл из files/ с нужными правами, если содержимое отличается.
install_file() {
  local src=$1 dest=$2 mode=${3:-644}
  if [[ -e $dest ]] && cmp -s "$src" "$dest"; then
    ok "$(short "$dest") — уже актуален"
    return 0
  fi
  [[ -e $dest ]] && backup "$dest"
  run mkdir -p "$(dirname "$dest")"
  run install -m "$mode" "$src" "$dest"
  ok "$(short "$dest")"
}

# Символ комментария по расширению файла: маркеры блока должны быть
# комментарием в синтаксисе того файла, куда их кладут. Lua-конфиги Hyprland
# от решётки падают с "unexpected symbol near '#'".
comment_prefix() {
  case $1 in
  *.lua) printf -- '--' ;;
  *) printf '#' ;;
  esac
}

# Идемпотентная вставка блока, ограниченного маркерами. Тело читается со stdin.
#
#   ensure_block <файл> <имя-блока> [tail|after:<точная строка>] <<'EOF'
#
# Повторный запуск с тем же телом ничего не делает, с другим — заменяет блок
# на месте. Так один и тот же install.sh можно гонять сколько угодно раз.
ensure_block() {
  local file=$1 marker=$2 position=${3:-tail}
  local hash
  hash=$(comment_prefix "$file")
  local begin="$hash >>> omarchy-ru:$marker >>>"
  local end="$hash <<< omarchy-ru:$marker <<<"
  local body current tmp
  body=$(cat)

  if [[ -e $file ]] && grep -qxF -- "$begin" "$file"; then
    current=$(awk -v b="$begin" -v e="$end" '$0==b{f=1;next} $0==e{f=0;next} f' "$file")
    if [[ $current == "$body" ]]; then
      ok "$(short "$file") — блок «$marker» уже на месте"
      return 0
    fi
  fi

  if ((DRY_RUN)); then
    printf '  %s(dry-run)%s обновил бы блок «%s» в %s\n' \
      "$C_DIM" "$C_OFF" "$marker" "$(short "$file")"
    return 0
  fi

  [[ -e $file ]] && backup "$file"
  mkdir -p "$(dirname "$file")"
  [[ -e $file ]] || : >"$file"

  # Новое содержимое собирается во временных файлах целиком и только потом
  # переливается в целевой: сбой на середине сборки не должен оставлять от
  # пользовательского конфига огрызок. Заливаем через cat, а не mv, чтобы
  # сохранить права и владельца исходного файла.
  tmp=$(mktemp) result=$(mktemp)
  # Вырезаем прежнюю версию блока целиком, вместе с маркерами.
  awk -v b="$begin" -v e="$end" '$0==b{f=1} !f{print} $0==e{f=0}' "$file" >"$tmp"

  if [[ $position == after:* ]]; then
    # Якорь сравнивается как целая строка, а не как регулярка: строки вроде
    # "[[ $- != *i* ]] && return" в regexp не превращаются без боли.
    local anchor=${position#after:}
    if grep -qxF -- "$anchor" "$tmp"; then
      awk -v a="$anchor" -v b="$begin" -v e="$end" -v body="$body" '
        { print }
        !inserted && $0 == a { print ""; print b; print body; print e; inserted = 1 }
      ' "$tmp" >"$result"
    else
      # Якоря нет — кладём в начало файла, это всё равно раньше всего прочего.
      { printf '%s\n%s\n%s\n\n' "$begin" "$body" "$end"; cat "$tmp"; } >"$result"
    fi
  else
    { cat "$tmp"; printf '\n%s\n%s\n%s\n' "$begin" "$body" "$end"; } >"$result"
  fi

  # Права целевого файла важнее прав mktemp (0600).
  cat "$result" >"$file"
  rm -f "$tmp" "$result"
  ok "$(short "$file") — блок «$marker» записан"
}

# Снять блок, поставленный ensure_block, вместе с пустой строкой перед ним —
# иначе цикл «поставил / снял» копил бы в чужом конфиге пустые строки.
remove_block() {
  local file=$1 marker=$2
  local hash
  hash=$(comment_prefix "$file")
  local begin="$hash >>> omarchy-ru:$marker >>>"
  local end="$hash <<< omarchy-ru:$marker <<<"

  if [[ ! -e $file ]] || ! grep -qxF -- "$begin" "$file"; then
    ok "$(short "$file") — блока «$marker» нет"
    return 0
  fi

  if ((DRY_RUN)); then
    printf '  %s(dry-run)%s снял бы блок «%s» из %s\n' \
      "$C_DIM" "$C_OFF" "$marker" "$(short "$file")"
    return 0
  fi

  backup "$file"
  local tmp
  tmp=$(mktemp)
  awk -v b="$begin" -v e="$end" '
    !f && $0 == "" { pending++; next }
    $0 == b { f = 1; pending = 0; next }
    $0 == e { f = 0; next }
    f { next }
    { while (pending-- > 0) print ""; pending = 0; print }
    END { while (pending-- > 0) print "" }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
  ok "$(short "$file") — блок «$marker» снят"
}

# Удалить файл, поставленный установщиком.
remove_file() {
  local file=$1
  if [[ ! -e $file ]]; then
    ok "$(short "$file") — уже нет"
    return 0
  fi
  run rm -rf -- "$file"
  ok "$(short "$file") — удалён"
}

have() { command -v "$1" >/dev/null 2>&1; }

# Спрашиваем пароль заранее и один раз: иначе sudo падает уже посреди установки,
# а без терминала (запуск из агента, из хука) — молча и без объяснений.
need_root() {
  ((DRY_RUN)) && return 0
  sudo -n true 2>/dev/null && return 0
  [[ -t 0 ]] || die "нужен sudo, но терминала для ввода пароля нет — запусти скрипт в терминале"
  sudo -v || die "sudo не подтверждён"
}

# Hyprland запущен и отвечает? Часть шагов имеет смысл только внутри сессии.
hyprland_live() { have hyprctl && hyprctl version >/dev/null 2>&1; }
