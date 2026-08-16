#!/usr/bin/env bash
# Подключается из ~/.bashrc ДО слоя Omarchy.
#
# ble.sh требует такого порядка: загрузиться раньше всего, а прикрепиться самым
# последним действием — иначе он не увидит биндинги, навешанные ниже (atuin,
# television, fzf). Прикрепление живёт в tail.sh.

[[ $- == *i* ]] || return 0

[[ -r ~/.local/share/blesh/ble.sh ]] && source ~/.local/share/blesh/ble.sh --noattach
