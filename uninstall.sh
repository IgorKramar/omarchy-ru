#!/usr/bin/env bash
#
# Снимает то, что поставил install.sh.
#
# По умолчанию трогает только следы самого установщика: блоки в чужих
# конфигах, свои файлы, хук и сгенерированное меню. Всё, что меняет систему
# целиком, снимается только по явному флагу.
#
#   ./uninstall.sh                 блоки, файлы, хук, меню, настройки git
#   ./uninstall.sh --packages      плюс снести ghostty, atuin, yazi, delta, tv и ble.sh
#   ./uninstall.sh --locale        плюс вернуть LANG=en_US.UTF-8
#   ./uninstall.sh --dry-run       показать, что было бы сделано

set -Eeuo pipefail

RU_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export RU_ROOT

DRY_RUN=0
DROP_PACKAGES=0
DROP_LOCALE=0

while (($#)); do
  case $1 in
  --dry-run) DRY_RUN=1 ;;
  --packages) DROP_PACKAGES=1 ;;
  --locale) DROP_LOCALE=1 ;;
  -h | --help)
    awk 'NR>2 && /^#/ { sub(/^# ?/, ""); print; next } NR>2 { exit }' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *)
    echo "неизвестный флаг: $1" >&2
    exit 2
    ;;
  esac
  shift
done

export DRY_RUN
source "$RU_ROOT/lib/common.sh"

((EUID == 0)) && die "запускай от обычного пользователя"
((DRY_RUN)) && log "режим --dry-run: система не меняется"

log "Останавливаю демон синхронизации раскладки"
if pgrep -f 'hypr-sync-kb-layout' >/dev/null; then
  run pkill -f 'hypr-sync-kb-layout'
  ok "демон остановлен"
else
  ok "демон не запущен"
fi

log "Снимаю блоки из конфигов"
remove_block "$HOME/.config/hypr/input.lua" keyboard
remove_block "$HOME/.config/hypr/input.lua" touchpad
remove_block "$HOME/.config/hypr/autostart.lua" keyboard
remove_block "$HOME/.bashrc" bash-head
remove_block "$HOME/.bashrc" bash-tail

log "Удаляю установленные файлы"
remove_file "$HOME/.local/bin/hypr-sync-kb-layout"
remove_file "$HOME/.local/bin/omarchy-menu-ru"
remove_file "$HOME/.config/omarchy/menu-ru.json"
remove_file "$HOME/.config/omarchy/hooks/post-update.d/rebuild-ru-menu"
remove_file "$HOME/.config/omarchy-ru"
# Меню без генератора всё равно нечем пересобрать: без этого файла Omarchy
# просто вернётся к своим английским подписям.
remove_file "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

log "Возвращаю git к пейджеру по умолчанию"
for key in core.pager interactive.diffFilter delta.navigate delta.line-numbers delta.hyperlinks; do
  if git config --global --get "$key" >/dev/null 2>&1; then
    run git config --global --unset "$key"
    ok "git $key — снят"
  else
    ok "git $key — не задан"
  fi
done

if ((DROP_PACKAGES)); then
  log "Сношу пакеты и ble.sh"
  remove_file "$HOME/.local/share/blesh"
  installed=()
  for pkg in ghostty atuin yazi git-delta television; do
    pacman -Q "$pkg" &>/dev/null && installed+=("$pkg")
  done
  if ((${#installed[@]})); then
    # Ghostty мог остаться терминалом по умолчанию — возвращаем foot заранее,
    # иначе Super+Enter будет звать удалённый бинарник.
    if have omarchy-default-terminal && [[ $(omarchy-default-terminal 2>/dev/null) == ghostty ]]; then
      run omarchy-default-terminal foot
      ok "терминал по умолчанию: foot"
    fi
    need_root
    run sudo pacman -Rns --noconfirm "${installed[@]}"
    ok "снесено: ${installed[*]}"
  else
    ok "пакетов уже нет"
  fi
fi

if ((DROP_LOCALE)); then
  log "Возвращаю LANG=en_US.UTF-8"
  need_root
  run sudo localectl set-locale LANG=en_US.UTF-8
  ok "LANG=en_US.UTF-8 — подхватится после перелогина"
fi

if hyprland_live && ((!DRY_RUN)); then
  hyprctl reload >/dev/null
  ok "конфиг Hyprland перечитан"
fi

log "Готово."
cat <<'NOTE'

  Что осталось нетронутым намеренно:
    • тема, фон и шрифт — это твой выбор, а не след установщика;
    • копии <файл>.bak.<таймстамп> рядом с каждым правленым конфигом;
    • история atuin в ~/.local/share/atuin (сноси руками, если не нужна).

  Открой новый терминал: bash вернётся к стоковому окружению Omarchy.
NOTE
