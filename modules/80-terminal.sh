#!/usr/bin/env bash
# Делает Ghostty терминалом по умолчанию средствами Omarchy.

have ghostty || {
  warn "ghostty не установлен (модуль packages) — пропускаю"
  return 0 2>/dev/null || exit 0
}
have omarchy-default-terminal || {
  warn "omarchy-default-terminal не найден — пропускаю"
  return 0 2>/dev/null || exit 0
}

current=$(omarchy-default-terminal 2>/dev/null || true)
if [[ $current == ghostty ]]; then
  ok "терминал по умолчанию уже ghostty"
else
  run omarchy-default-terminal ghostty
  ok "терминал по умолчанию: ghostty (было: ${current:-неизвестно})"
fi

# Конфиг ghostty Omarchy кладёт сама и сама подставляет в него цвета темы,
# шрифт и обход тормозов на Hyprland — свой писать не нужно.
[[ -r $HOME/.config/ghostty/config ]] ||
  warn "нет ~/.config/ghostty/config — проверь «omarchy refresh config ghostty/config»"
