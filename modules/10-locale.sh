#!/usr/bin/env bash
# Собирает локаль ru_RU.UTF-8 и делает её системной (LANG).

if locale -a 2>/dev/null | grep -qix 'ru_RU.utf8'; then
  ok "локаль ru_RU.UTF-8 уже собрана"
else
  need_root
  log "включаю ru_RU.UTF-8 в /etc/locale.gen и собираю локали"
  run sudo sed -i 's/^#[[:space:]]*\(ru_RU\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  run sudo locale-gen
  ok "ru_RU.UTF-8 собрана"
fi

# /etc/locale.conf — то, что localectl в итоге и пишет; читать файл надёжнее,
# чем разбирать вывод localectl, у которого набор ключей разъезжается по версиям.
current=$(sed -n 's/^LANG=//p' /etc/locale.conf 2>/dev/null | tail -1)
if [[ -z $current ]]; then
  current=$(localectl status 2>/dev/null | sed -n 's/.*LANG=\([^ ]*\).*/\1/p' | head -1)
fi

if [[ $current == ru_RU.UTF-8 ]]; then
  ok "LANG уже ru_RU.UTF-8"
else
  need_root
  run sudo localectl set-locale LANG=ru_RU.UTF-8
  ok "LANG=ru_RU.UTF-8 — подхватится после перелогина (было: ${current:-не задан})"
fi
