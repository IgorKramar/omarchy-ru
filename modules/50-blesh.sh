#!/usr/bin/env bash
# Собирает ble.sh — автоподсказки и подсветку синтаксиса для bash.

BLESH_DIR=$HOME/.local/share/blesh
BLESH_REPO=https://github.com/akinomyoga/ble.sh.git

if [[ -r $BLESH_DIR/ble.sh ]] && ((!FORCE)); then
  ok "ble.sh уже установлен ($(short "$BLESH_DIR")), --force чтобы пересобрать"
  return 0 2>/dev/null || exit 0
fi

# Ставим из исходников, а не из AUR: сборка кладёт всё в ~/.local и не требует
# root, поэтому проходит и там, где helper'а AUR нет вовсе.
deps=()
for tool in git make gawk; do
  have "$tool" || deps+=("$tool")
done
if ((${#deps[@]})); then
  log "для сборки нужны: ${deps[*]}"
  if have omarchy-pkg-add; then
    run omarchy pkg add "${deps[@]}"
  else
    run sudo pacman -S --needed --noconfirm "${deps[@]}"
  fi
fi

if ((DRY_RUN)); then
  printf '  %s(dry-run)%s склонировал бы %s и собрал в %s\n' \
    "$C_DIM" "$C_OFF" "$BLESH_REPO" "$(short "$HOME/.local")"
else
  workdir=$(mktemp -d)
  trap 'rm -rf "$workdir"' RETURN
  git clone --recursive --depth 1 --shallow-submodules "$BLESH_REPO" "$workdir/ble.sh" >/dev/null 2>&1 ||
    die "не смог склонировать ble.sh — проверь сеть"
  make -C "$workdir/ble.sh" install PREFIX="$HOME/.local" >/dev/null ||
    die "сборка ble.sh не прошла"
  [[ -r $BLESH_DIR/ble.sh ]] || die "ble.sh не появился в $(short "$BLESH_DIR")"
  ok "ble.sh собран в $(short "$BLESH_DIR")"
fi
