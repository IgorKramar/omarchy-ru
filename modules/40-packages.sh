#!/usr/bin/env bash
# Ставит терминал Ghostty и набор CLI: atuin, yazi, git-delta, television.

PACKAGES=(ghostty atuin yazi git-delta television)

missing=()
for pkg in "${PACKAGES[@]}"; do
  pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
done

if ((${#missing[@]} == 0)); then
  ok "всё уже стоит: ${PACKAGES[*]}"
else
  log "ставлю: ${missing[*]}"
  if have omarchy-pkg-add; then
    run omarchy pkg add "${missing[@]}"
  else
    run sudo pacman -S --needed --noconfirm "${missing[@]}"
  fi
  ok "установлено: ${missing[*]}"
fi
