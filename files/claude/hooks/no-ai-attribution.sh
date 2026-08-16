#!/usr/bin/env bash
# PreToolUse-хук: не пропускает команды, вписывающие ИИ в авторство.
#
# Настройка attribution в settings.json убирает трейлеры у штатного механизма
# Claude Code, а правило в CLAUDE.md — договорённость. Этот хук — жёсткая
# проверка: он смотрит на саму команду и запрещает её выполнение.

set -uo pipefail

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0
subject=$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null)
[[ -n $subject ]] || exit 0

# Хук висит на всём Bash, поэтому отсекаем неинтересное сами: "if" в настройках
# сверяется с началом команды и пропустил бы "cd foo && git commit".
case $subject in
*"git commit"* | *"git merge"* | *"git tag"* | *"gh pr create"* | *"gh pr edit"* | *"gh issue create"*) ;;
*) exit 0 ;;
esac

# Ищем и трейлеры, и рекламные строки, и адрес, которым они подписываются.
forbidden='Co-Authored-By:[[:space:]]*(Claude|Anthropic|AI|Assistant)|noreply@anthropic\.com|Generated with \[?Claude|🤖 Generated|claude\.(com|ai)/claude-code|Co-authored-by:.*(claude|anthropic)'

if grep -qiE "$forbidden" <<<"$subject"; then
  offending=$(grep -ioE "$forbidden" <<<"$subject" | head -1)
  jq -n --arg found "$offending" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Команда вписывает ИИ в авторство (\($found)). " +
        "На этой машине автор коммитов и текстов один — владелец машины. " +
        "Убери трейлер соавторства и строку о генерации, остальное сообщение оставь как есть.")
    }
  }'
  exit 0
fi

exit 0
