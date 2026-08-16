#!/usr/bin/env bash
# Подключает ble.sh, atuin, television и yazi к ~/.bashrc двумя строчками.

install_file "$RU_ROOT/files/bash/head.sh" "$HOME/.config/omarchy-ru/bash/head.sh" 644
install_file "$RU_ROOT/files/bash/tail.sh" "$HOME/.config/omarchy-ru/bash/tail.sh" 644

# В самом ~/.bashrc держим только две заглушки: вся логика живёт в файлах выше,
# поэтому обновление окружения не требует новой правки пользовательского rc.
# Заголовок встаёт сразу после проверки интерактивности и до слоя Omarchy.
ensure_block "$HOME/.bashrc" bash-head 'after:[[ $- != *i* ]] && return' <<'EOF'
source ~/.config/omarchy-ru/bash/head.sh
EOF

ensure_block "$HOME/.bashrc" bash-tail tail <<'EOF'
source ~/.config/omarchy-ru/bash/tail.sh
EOF
