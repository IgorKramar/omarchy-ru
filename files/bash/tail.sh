#!/usr/bin/env bash
# Подключается из ~/.bashrc ПОСЛЕ слоя Omarchy — последней строкой.
#
# Порядок здесь и определяет, кто выигрывает горячие клавиши: Omarchy выше
# навесил на fzf сразу Ctrl+T, Ctrl+R и Alt+C, television перебивает первые две,
# atuin забирает Ctrl+R себе. Итог: Ctrl+T — television, Ctrl+R — atuin,
# Alt+C — fzf, стрелка вверх — обычная история bash.

[[ $- == *i* ]] || return 0

command -v tv &>/dev/null && eval "$(tv init bash)"

# Штатный Ctrl+T у television дополняет уже набранное слово и на пустой строке
# молча выходит. Отдаём пустому промпту полноценный выбор файлов, а строку с
# текстом оставляем родному дополнению.
tv_ctrl_t() {
  if [[ -n ${READLINE_LINE//[[:space:]]/} ]]; then
    tv_smart_autocomplete
    return
  fi

  local -a picks=()
  mapfile -t picks < <(tv files </dev/tty)
  ((${#picks[@]})) || return

  # %q бережёт пробелы и прочие спецсимволы в путях.
  local text
  printf -v text '%q ' "${picks[@]}"
  text=${text% }

  READLINE_LINE="${READLINE_LINE:0:READLINE_POINT}${text}${READLINE_LINE:READLINE_POINT}"
  ((READLINE_POINT += ${#text}))
}
command -v tv &>/dev/null && bind -x '"\C-t": tv_ctrl_t'

# atuin: история в SQLite вместо ~/.bash_history.
#   --disable-up-arrow  оставляет стрелку вверх обычной истории bash;
#   --disable-ai        обязателен, иначе atuin вешает ИИ-режим на клавишу "?"
#                       и перехватывает обычный печатный символ в пустой строке.
command -v atuin &>/dev/null && eval "$(atuin init bash --disable-up-arrow --disable-ai)"

# yazi: y открывает файловый менеджер и переходит в каталог, где ты вышел.
y() {
  local cwd_file cwd
  cwd_file=$(mktemp -t "yazi-cwd.XXXXXX")
  yazi "$@" --cwd-file="$cwd_file"
  IFS= read -r -d '' cwd <"$cwd_file"
  rm -f -- "$cwd_file"

  if [[ -n $cwd && $cwd != "$PWD" ]]; then
    builtin cd -- "$cwd" || return
  fi
}

[[ ${BLE_VERSION-} ]] && ble-attach
