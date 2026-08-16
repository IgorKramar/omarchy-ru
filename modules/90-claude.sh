#!/usr/bin/env bash
# Статусная строка Claude Code и глобальное правило об авторстве.

have jq || warn "jq не найден — статусная строка выведет заглушку, поставь его модулем packages"

install_file "$RU_ROOT/files/claude/statusline.sh" "$HOME/.claude/statusline.sh" 755

# Правило действует на все проекты машины: ~/.claude/CLAUDE.md подгружается
# в каждую сессию. Кладём его блоком, чтобы не затирать другие свои заметки.
ensure_block "$HOME/.claude/CLAUDE.md" authorship tail <"$RU_ROOT/files/claude/authorship.md"

# settings.json правим json-мерджем, а не целиком: там лежат тема, tui и
# прочее, что к этому проекту отношения не имеет. Программа одна на оба
# режима — так желаемые настройки описаны ровно в одном месте.
claude_settings_py='
import json, sys

path, mode = sys.argv[1], sys.argv[2]

with open(path, encoding="utf-8") as handle:
    try:
        settings = json.load(handle)
    except json.JSONDecodeError:
        sys.exit("settings.json не разбирается как JSON — правь руками")

wanted = {
    "statusLine": {
        "type": "command",
        "command": "~/.claude/statusline.sh",
        "padding": 0,
        # Событийных обновлений хватает, пока идёт диалог; таймер держит
        # свежими время сессии и лимиты, когда сессия просто ждёт.
        "refreshInterval": 30,
    },
    # Режим vim статусная строка печатает сама — незачем показывать дважды.
    "hideVimModeIndicator": True,
}

if all(settings.get(key) == value for key, value in wanted.items()):
    print("no")
    raise SystemExit

if mode == "check":
    print("yes")
    raise SystemExit

settings.update(wanted)
with open(path, "w", encoding="utf-8") as handle:
    json.dump(settings, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
print("yes")
'

settings=$HOME/.claude/settings.json
if ((DRY_RUN)); then
  printf '  %s(dry-run)%s дописал бы statusLine в %s\n' "$C_DIM" "$C_OFF" "$(short "$settings")"
else
  mkdir -p "$(dirname "$settings")"
  [[ -f $settings ]] || echo '{}' >"$settings"

  if [[ $(python3 -c "$claude_settings_py" "$settings" check) == yes ]]; then
    # Бэкап только когда правда правим, иначе копии плодятся на каждый прогон.
    backup "$settings"
    python3 -c "$claude_settings_py" "$settings" apply >/dev/null
    ok "$(short "$settings") — statusLine прописан"
  else
    ok "$(short "$settings") — statusLine уже настроен"
  fi
fi
