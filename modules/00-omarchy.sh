#!/usr/bin/env bash
# Проверяет, что это Omarchy 4 (Quattro), и обновляет систему, если версия старее.

have omarchy || die "команда omarchy не найдена — это не Omarchy"

read_major() {
  local version=${1%%-*}
  printf '%s' "${version%%.*}"
}

version=$(omarchy version 2>/dev/null | head -1 | tr -d '[:space:]')
[[ -n $version ]] || die "omarchy version ничего не вернула"
major=$(read_major "$version")
[[ $major =~ ^[0-9]+$ ]] || die "не разобрал версию Omarchy: «$version»"

if ((major >= REQUIRED_MAJOR)); then
  ok "Omarchy $version — подходит (нужна $REQUIRED_MAJOR.x)"
else
  warn "Omarchy $version старее требуемой ${REQUIRED_MAJOR}.x (Quattro)"
  ((SKIP_UPDATE)) && die "запуск с --skip-update: обнови вручную через omarchy update"

  log "Запускаю omarchy update. Это надолго и попросит пароль sudo."
  run omarchy update

  version=$(omarchy version 2>/dev/null | head -1 | tr -d '[:space:]')
  major=$(read_major "$version")
  if ((DRY_RUN)); then
    ok "(dry-run) дальше проверялась бы версия после обновления"
  elif ((major >= REQUIRED_MAJOR)); then
    ok "обновлено до Omarchy $version"
  else
    die "после обновления всё ещё $version — обнови систему вручную и запусти скрипт снова"
  fi

  # Обновление могло принести новое упакованное меню и новые дефолты bash,
  # поэтому дальше идут модули, которые пересобирают всё поверх свежего.
  warn "Omarchy обновилась: если Hyprland просил перезайти в сессию, сделай это до правки конфигов"
fi
