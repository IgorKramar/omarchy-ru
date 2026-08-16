#!/usr/bin/env bash
# Ставит тему, фон и шрифт из files/theme.env.

# Значения из окружения важнее файла: RU_THEME=gruvbox ./install.sh theme
env_theme=${RU_THEME-} env_repo=${RU_THEME_REPO-}
env_background=${RU_BACKGROUND-} env_font=${RU_FONT-}

# shellcheck disable=SC1091
source "$RU_ROOT/files/theme.env"

[[ -n $env_theme ]] && RU_THEME=$env_theme
[[ -n $env_repo ]] && RU_THEME_REPO=$env_repo
[[ -n $env_background ]] && RU_BACKGROUND=$env_background
[[ -n $env_font ]] && RU_FONT=$env_font

have omarchy-theme-set || {
  warn "omarchy-theme-set не найден — пропускаю"
  return 0 2>/dev/null || exit 0
}

theme_dir() { omarchy theme dir "$1" 2>/dev/null; }

# Тема
if [[ -z ${RU_THEME:-} ]]; then
  warn "RU_THEME пуст — тему не трогаю"
else
  if [[ ! -d $(theme_dir "$RU_THEME") ]]; then
    if [[ -n ${RU_THEME_REPO:-} ]]; then
      log "темы «$RU_THEME» нет, ставлю из $RU_THEME_REPO"
      run omarchy theme install "$RU_THEME_REPO"
    else
      die "темы «$RU_THEME» нет ни в стоковых, ни в пользовательских; укажи RU_THEME_REPO в files/theme.env"
    fi
  fi

  current_theme=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)
  if [[ $current_theme == "$RU_THEME" ]]; then
    ok "тема уже $RU_THEME"
  else
    run omarchy theme set "$RU_THEME"
    ok "тема: $RU_THEME (было: ${current_theme:-не задана})"
  fi
fi

# Фон. Ищем и в каталоге темы, и в пользовательских фонах — omarchy-theme-set
# собирает список из обоих мест.
if [[ -n ${RU_BACKGROUND:-} ]]; then
  background=""
  for dir in "$(theme_dir "$RU_THEME")/backgrounds" "$HOME/.config/omarchy/backgrounds/$RU_THEME"; do
    [[ -f $dir/$RU_BACKGROUND ]] && background=$dir/$RU_BACKGROUND && break
  done

  if [[ -z $background ]]; then
    warn "фона «$RU_BACKGROUND» нет среди фонов темы $RU_THEME — оставляю выбранный Omarchy"
  elif [[ $(basename "$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null)") == "$RU_BACKGROUND" ]]; then
    ok "фон уже $RU_BACKGROUND"
  else
    run omarchy theme bg set "$background"
    ok "фон: $RU_BACKGROUND"
  fi
fi

# Шрифт
if [[ -n ${RU_FONT:-} ]] && have omarchy-font-set; then
  if ! fc-list -q "$RU_FONT" 2>/dev/null; then
    warn "шрифт «$RU_FONT» не установлен — ставится через меню Omarchy (Установить → Оформление → Шрифт)"
  elif [[ $(omarchy font current 2>/dev/null) == "$RU_FONT" ]]; then
    ok "шрифт уже $RU_FONT"
  else
    run omarchy font set "$RU_FONT"
    ok "шрифт: $RU_FONT"
  fi
fi
