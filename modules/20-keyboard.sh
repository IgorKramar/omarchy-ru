#!/usr/bin/env bash
# Русская раскладка по Alt+Shift и синхронизация переключения между клавиатурами.

: "${RU_KB_SECOND_LAYOUT:=ru}"
: "${RU_KB_SWITCH:=grp:alt_shift_toggle}"

# Значения Omarchy по умолчанию — запасной вариант, если Hyprland не отвечает
# (установка по ssh, из TTY, до первого входа в сессию).
layout="us"
options="compose:caps,shift:both_capslock_cancel"

if hyprland_live; then
  live_layout=$(hyprctl getoption input:kb_layout 2>/dev/null | sed -n 's/^str: //p' | head -1)
  live_options=$(hyprctl getoption input:kb_options 2>/dev/null | sed -n 's/^str: //p' | head -1)
  [[ -n $live_layout ]] && layout=$live_layout
  [[ -n $live_options ]] && options=$live_options
else
  warn "Hyprland не отвечает — беру значения Omarchy по умолчанию"
fi

# Вторую раскладку добавляем, только если её ещё нет: повторный запуск не должен
# превращать список в "us,ru,ru".
if [[ ",$layout," != *",$RU_KB_SECOND_LAYOUT,"* ]]; then
  layout="$layout,$RU_KB_SECOND_LAYOUT"
fi

# Прежний переключатель групп выкидываем, свой ставим ровно один.
options=$(printf '%s' "$options" | tr ',' '\n' | grep -vx '' | grep -v '^grp:' | paste -sd,)
options=${options:+$options,}$RU_KB_SWITCH

install_file "$RU_ROOT/files/bin/hypr-sync-kb-layout" "$HOME/.local/bin/hypr-sync-kb-layout" 755

ensure_block "$HOME/.config/hypr/input.lua" keyboard tail <<EOF
-- Раскладки и переключатель. Блок идёт последним в файле, поэтому он
-- перекрывает любые прежние input-настройки выше.
hl.config({
  input = {
    kb_layout = "$layout",
    kb_options = "$options",
  },
})
EOF

ensure_block "$HOME/.config/hypr/autostart.lua" keyboard tail <<'EOF'
-- Hyprland переключает группу xkb отдельно для каждой клавиатуры: Alt+Shift
-- меняет раскладку только на той, где нажали. Демон разносит переключение на
-- все физические клавиатуры сразу.
o.launch_on_start("hypr-sync-kb-layout")
EOF

if hyprland_live && ((!DRY_RUN)); then
  hyprctl reload >/dev/null
  errors=$(hyprctl configerrors 2>/dev/null | grep -v '^no errors' || true)
  if [[ -n $errors ]]; then
    warn "hyprctl configerrors ругается:"
    printf '%s\n' "$errors" >&2
  else
    ok "конфиг Hyprland перечитан без ошибок"
  fi

  if pgrep -f 'hypr-sync-kb-layout' >/dev/null; then
    ok "демон синхронизации уже запущен"
  else
    uwsm-app -- hypr-sync-kb-layout >/dev/null 2>&1 &
    disown
    ok "демон синхронизации запущен"
  fi
fi
