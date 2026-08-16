#!/usr/bin/env bash
# Статусная строка Claude Code. Получает JSON сессии на stdin, печатает две
# строки: слева — что и где, справа — сколько потрачено.
#
#   ◆ Opus 5 · max │  ~/Projects/omarchy-ru │  master ●3 │ PR #4 ✓
#
#   ███░░░░░░░ 34% из 1M │ $2.14 │ +412/-88 │ 5ч 41% · 7д 12% │ 18м
#
# Цвета берутся из палитры терминала (ANSI 30-37), а не задаются в hex, —
# поэтому строка сама следует текущей теме Omarchy и не требует перенастройки
# после `omarchy theme set`.

set -uo pipefail

input=$(cat)

command -v jq >/dev/null 2>&1 || {
  printf 'statusline: нужен jq\n'
  exit 0
}

# Поля читаются по строке на значение, а не через @tsv: IFS=$'\t' у read
# схлопывает подряд идущие табы (таб — пробельный разделитель), и пустой
# effort или fast_mode сдвинул бы все последующие поля.
mapfile -t FIELDS < <(
  jq -r '[
    (.model.display_name // "?"),
    (.effort.level // ""),
    (if .fast_mode then "fast" else "" end),
    (.workspace.current_dir // .cwd // ""),
    (.context_window.used_percentage // 0 | floor),
    (.context_window.context_window_size // 200000),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.seven_day.used_percentage // -1 | floor),
    (.pr.number // ""),
    (.pr.review_state // ""),
    (.vim.mode // "")
  ] | .[] | tostring' <<<"$input" 2>/dev/null
)

MODEL=${FIELDS[0]:-?} EFFORT=${FIELDS[1]:-} FAST=${FIELDS[2]:-}
DIR=${FIELDS[3]:-$PWD} PCT=${FIELDS[4]:-0} WINDOW=${FIELDS[5]:-200000}
COST=${FIELDS[6]:-0} DURATION=${FIELDS[7]:-0}
ADDED=${FIELDS[8]:-0} REMOVED=${FIELDS[9]:-0}
RL5=${FIELDS[10]:--1} RL7=${FIELDS[11]:--1}
PR_NUMBER=${FIELDS[12]:-} PR_STATE=${FIELDS[13]:-} VIM=${FIELDS[14]:-}

DIM=$'\033[2m' RESET=$'\033[0m'
RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m'
BLUE=$'\033[34m' MAGENTA=$'\033[35m' CYAN=$'\033[36m'
SEP="${DIM}│${RESET}"

# --- Строка 1: модель, каталог, git, пулл-реквест -----------------------------

model="${MAGENTA}◆ ${MODEL}${RESET}"
[[ -n ${EFFORT:-} ]] && model+="${DIM} · ${EFFORT}${RESET}"
[[ ${FAST:-} == fast ]] && model+="${YELLOW} ⚡${RESET}"

home_short=${DIR/#$HOME/\~}
directory="${BLUE} ${home_short}${RESET}"

# git status на большом репозитории заметно тормозит, а скрипт дёргается на
# каждое сообщение ассистента — поэтому ответ кешируется на пару секунд.
git_segment() {
  [[ -d $DIR ]] || return 0
  git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1 || return 0

  local cache_dir=${XDG_RUNTIME_DIR:-/tmp}/claude-statusline
  local cache_file
  cache_file="$cache_dir/$(printf '%s' "$DIR" | cksum | tr -d ' ')"
  mkdir -p "$cache_dir" 2>/dev/null

  if [[ -f $cache_file ]]; then
    local age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
    if ((age < 3)); then
      cat "$cache_file"
      return 0
    fi
  fi

  local branch dirty out
  branch=$(git -C "$DIR" branch --show-current 2>/dev/null)
  [[ -z $branch ]] && branch=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
  [[ -z $branch ]] && return 0
  dirty=$(git -C "$DIR" status --porcelain 2>/dev/null | wc -l)

  if ((dirty > 0)); then
    out="${YELLOW} ${branch}${RESET}${RED} ●${dirty}${RESET}"
  else
    out="${GREEN} ${branch}${RESET}"
  fi

  printf '%s' "$out" | tee "$cache_file"
}

line1="$model $SEP $directory"
git_info=$(git_segment)
[[ -n $git_info ]] && line1+=" $SEP $git_info"

if [[ -n ${PR_NUMBER:-} ]]; then
  case ${PR_STATE:-} in
  approved) pr="${GREEN}PR #${PR_NUMBER} ✓${RESET}" ;;
  changes_requested) pr="${RED}PR #${PR_NUMBER} ✗${RESET}" ;;
  draft) pr="${DIM}PR #${PR_NUMBER} draft${RESET}" ;;
  *) pr="${YELLOW}PR #${PR_NUMBER}${RESET}" ;;
  esac
  line1+=" $SEP $pr"
fi

[[ -n ${VIM:-} ]] && line1+=" $SEP ${CYAN}${VIM}${RESET}"

# --- Строка 2: контекст, деньги, лимиты, время --------------------------------

if ((PCT >= 90)); then
  bar_color=$RED
elif ((PCT >= 70)); then
  bar_color=$YELLOW
else
  bar_color=$GREEN
fi

filled=$((PCT / 10))
((filled > 10)) && filled=10
empty=$((10 - filled))
bar=""
for ((i = 0; i < filled; i++)); do bar+="█"; done
for ((i = 0; i < empty; i++)); do bar+="░"; done

if ((WINDOW >= 1000000)); then
  window_label="$((WINDOW / 1000000))M"
else
  window_label="$((WINDOW / 1000))k"
fi

line2="${bar_color}${bar}${RESET} ${PCT}%${DIM} из ${window_label}${RESET}"
line2+=" $SEP ${CYAN}$(printf '$%.2f' "$COST")${RESET}"

if ((ADDED > 0 || REMOVED > 0)); then
  line2+=" $SEP ${GREEN}+${ADDED}${RESET}${DIM}/${RESET}${RED}-${REMOVED}${RESET}"
fi

# Лимиты приходят только на подписках с ними — при их отсутствии сегмент молчит.
limits=""
((RL5 >= 0)) && limits+="5ч ${RL5}%"
((RL7 >= 0)) && limits+="${limits:+ · }7д ${RL7}%"
if [[ -n $limits ]]; then
  worst=$((RL5 > RL7 ? RL5 : RL7))
  if ((worst >= 80)); then
    limit_color=$RED
  elif ((worst >= 50)); then
    limit_color=$YELLOW
  else
    limit_color=$DIM
  fi
  line2+=" $SEP ${limit_color}${limits}${RESET}"
fi

minutes=$((DURATION / 60000))
if ((minutes >= 60)); then
  line2+=" $SEP ${DIM}$((minutes / 60))ч $((minutes % 60))м${RESET}"
else
  line2+=" $SEP ${DIM}${minutes}м${RESET}"
fi

# Между строками — пустая строка для воздуха. В ней стоит пробел, а не ничего:
# строку из одних пробелов интерфейс точно отрисует как пустой ряд.
printf '%s\n%s\n%s\n' "$line1" " " "$line2"
