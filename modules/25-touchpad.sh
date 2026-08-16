#!/usr/bin/env bash
# Естественная прокрутка тачпада: пальцами сверху вниз — листает вверх.

# Omarchy по умолчанию ставит traditional-прокрутку (движение пальцами вверх
# листает вверх). Здесь включается «естественная», как на macOS: содержимое
# едет за пальцами, поэтому листать вверх = вести двумя пальцами сверху вниз.
# Мыши это не касается — у неё отдельная настройка input:natural_scroll.
: "${RU_TOUCHPAD_NATURAL_SCROLL:=true}"

case $RU_TOUCHPAD_NATURAL_SCROLL in
true | false) ;;
*) die "RU_TOUCHPAD_NATURAL_SCROLL должен быть true или false, а не «$RU_TOUCHPAD_NATURAL_SCROLL»" ;;
esac

ensure_block "$HOME/.config/hypr/input.lua" touchpad tail <<EOF
hl.config({
  input = {
    touchpad = {
      natural_scroll = $RU_TOUCHPAD_NATURAL_SCROLL,
    },
  },
})
EOF

if hyprland_live && ((!DRY_RUN)); then
  hyprctl reload >/dev/null
  applied=$(hyprctl getoption input:touchpad:natural_scroll 2>/dev/null | sed -n 's/^bool: //p' | head -1)
  if [[ $applied == "$RU_TOUCHPAD_NATURAL_SCROLL" ]]; then
    ok "естественная прокрутка тачпада: $applied"
  else
    warn "Hyprland сообщает natural_scroll=$applied вместо $RU_TOUCHPAD_NATURAL_SCROLL — проверь hyprctl configerrors"
  fi
fi
