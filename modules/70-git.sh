#!/usr/bin/env bash
# Включает delta как пейджер диффов в глобальном конфиге git.

have git || {
  warn "git не найден — пропускаю"
  return 0
}
have delta || {
  warn "delta не установлена (модуль packages) — пропускаю"
  return 0
}

# git config идемпотентен сам по себе: повторный запуск перезаписывает значение
# на месте, дубликатов секций не появляется. Имя и почту не трогаем — они личные.
set_git() {
  local key=$1 value=$2
  if [[ $(git config --global --get "$key" 2>/dev/null) == "$value" ]]; then
    ok "git $key — уже $value"
  else
    run git config --global "$key" "$value"
    ok "git $key = $value"
  fi
}

set_git core.pager delta
set_git interactive.diffFilter "delta --color-only"
set_git delta.navigate true
set_git delta.line-numbers true
set_git delta.hyperlinks true
