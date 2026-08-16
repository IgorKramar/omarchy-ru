#!/usr/bin/env bash
# Русские подписи меню Omarchy плюс генератор и хук пересборки после обновлений.

install_file "$RU_ROOT/files/bin/omarchy-menu-ru" "$HOME/.local/bin/omarchy-menu-ru" 755
install_file "$RU_ROOT/files/omarchy/menu-ru.json" "$HOME/.config/omarchy/menu-ru.json" 644

# Хук пересобирает меню после omarchy update: подписи переопределяют пункты
# целиком, поэтому копии должны обновляться вместе с упакованным меню.
hook_dest="$HOME/.config/omarchy/hooks/post-update.d/rebuild-ru-menu"
if have omarchy-hook-install && [[ ! -e $hook_dest ]]; then
  run omarchy hook install post-update "$RU_ROOT/files/hooks/rebuild-ru-menu"
  ok "$(short "$hook_dest")"
else
  install_file "$RU_ROOT/files/hooks/rebuild-ru-menu" "$hook_dest" 755
fi

if ((DRY_RUN)); then
  printf '  %s(dry-run)%s собрал бы меню через omarchy-menu-ru\n' "$C_DIM" "$C_OFF"
else
  PATH="$HOME/.local/bin:$PATH" omarchy-menu-ru
fi
