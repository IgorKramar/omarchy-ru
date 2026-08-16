#!/usr/bin/env bash
# Статусная строка Claude Code, правило об авторстве и хук, который его стережёт.

have jq || warn "jq не найден — статусная строка и хук выведут заглушку, поставь его модулем packages"

install_file "$RU_ROOT/files/claude/statusline.sh" "$HOME/.claude/statusline.sh" 755
install_file "$RU_ROOT/files/claude/hooks/no-ai-attribution.sh" \
  "$HOME/.claude/hooks/no-ai-attribution.sh" 755

# Имя автора берём с машины, а не зашиваем в репозиторий: у каждого, кто
# развернёт проект, в правиле должно стоять его собственное имя.
#   1. git config user.name — то, чем реально подписаны коммиты;
#   2. полное имя из /etc/passwd (поле GECOS);
#   3. логин.
: "${RU_AUTHOR:=}"
if [[ -z $RU_AUTHOR ]]; then
  RU_AUTHOR=$(git config --global user.name 2>/dev/null || true)
fi
if [[ -z $RU_AUTHOR ]]; then
  RU_AUTHOR=$(getent passwd "$USER" 2>/dev/null | cut -d: -f5 | cut -d, -f1)
fi
[[ -n $RU_AUTHOR ]] || RU_AUTHOR=$USER
ok "автор в правиле: $RU_AUTHOR"

# Правило действует на все проекты машины: ~/.claude/CLAUDE.md подгружается
# в каждую сессию. Кладём его блоком, чтобы не затирать другие свои заметки.
sed "s/{{AUTHOR}}/$RU_AUTHOR/g" "$RU_ROOT/files/claude/authorship.md.tmpl" |
  ensure_block "$HOME/.claude/CLAUDE.md" authorship tail

# settings.json правим json-мерджем, а не целиком: там лежат тема, tui и
# прочее, что к этому проекту отношения не имеет. Программа одна на оба
# режима — так желаемые настройки описаны ровно в одном месте.
claude_settings_py='
import json, sys

path, mode = sys.argv[1], sys.argv[2]
HOOK = "~/.claude/hooks/no-ai-attribution.sh"

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
    # Штатный способ убрать соавторство: пустая строка прячет и трейлер
    # коммита, и рекламный блок в описании PR.
    "attribution": {"commit": "", "pr": ""},
}

changed = not all(settings.get(key) == value for key, value in wanted.items())

# Хуки — список групп по матчеру, поэтому дописываемся в существующий список,
# а не заменяем его: у пользователя могут быть свои хуки на тот же Bash.
hooks = settings.setdefault("hooks", {})
pre = hooks.setdefault("PreToolUse", [])
entry = {"type": "command", "command": HOOK}

installed = any(
    hook.get("command") == HOOK
    for group in pre
    if isinstance(group, dict)
    for hook in group.get("hooks", [])
    if isinstance(hook, dict)
)

if not installed:
    changed = True

if not changed:
    print("no")
    raise SystemExit

if mode == "check":
    print("yes")
    raise SystemExit

settings.update(wanted)
if not installed:
    bash_group = next(
        (group for group in pre if isinstance(group, dict) and group.get("matcher") == "Bash"),
        None,
    )
    if bash_group is None:
        pre.append({"matcher": "Bash", "hooks": [entry]})
    else:
        bash_group.setdefault("hooks", []).append(entry)

with open(path, "w", encoding="utf-8") as handle:
    json.dump(settings, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
print("yes")
'

settings=$HOME/.claude/settings.json
if ((DRY_RUN)); then
  printf '  %s(dry-run)%s дописал бы statusLine, attribution и хук в %s\n' \
    "$C_DIM" "$C_OFF" "$(short "$settings")"
else
  mkdir -p "$(dirname "$settings")"
  [[ -f $settings ]] || echo '{}' >"$settings"

  if [[ $(python3 -c "$claude_settings_py" "$settings" check) == yes ]]; then
    # Бэкап только когда правда правим, иначе копии плодятся на каждый прогон.
    backup "$settings"
    python3 -c "$claude_settings_py" "$settings" apply >/dev/null
    ok "$(short "$settings") — statusLine, attribution и хук прописаны"
  else
    ok "$(short "$settings") — настройки Claude Code уже на месте"
  fi
fi
