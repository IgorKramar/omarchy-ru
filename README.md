<div align="center">

# Omarchy RU

**English** · [Русский](README.ru.md)

### Russian menus. Shared keyboard layouts. A comfortable shell.

[![CI](https://github.com/IgorKramar/omarchy-ru/actions/workflows/lint.yml/badge.svg)](https://github.com/IgorKramar/omarchy-ru/actions/workflows/lint.yml)
![Bash](https://img.shields.io/badge/Bash-e0af68?style=flat-square)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-7aa2f7?style=flat-square)
![Hyprland](https://img.shields.io/badge/Hyprland-bb9af7?style=flat-square)
[![MIT](https://img.shields.io/badge/license-MIT-9ece6a?style=flat-square)](LICENSE)

[Install](#install) · [Modules](#modules) · [Keys](#keys) · [Customize](#customize) · [Uninstall](#uninstall)

</div>

Russian locale, keyboard layout, translated menus, Ghostty and a Bash setup for **Omarchy 4**. Run the complete installer or choose individual modules. Existing configuration is updated through marked blocks with backups.

## Install

```bash
git clone https://github.com/IgorKramar/omarchy-ru.git ~/Projects/omarchy-ru
cd ~/Projects/omarchy-ru
./install.sh
```

Run as a **regular user**, not root. The installer requests `sudo` for the operations that need it, including locale generation and package installation. It targets Linux/Arch with Omarchy; it is not a general Linux localization tool.

On an Omarchy version older than 4, the initial module runs `omarchy update` and checks the version again. Review the modules and use dry-run before applying a setup that changes your desktop preferences:

```bash
./install.sh --list             # list modules
./install.sh keyboard menu      # install selected modules
./install.sh --dry-run          # preview changes
./install.sh --force            # rebuild installed components such as ble.sh
./install.sh --skip-update      # do not update an older Omarchy installation
```

The Omarchy compatibility check runs first even when modules are selected explicitly.

## Modules

| Module | What it does |
|:---|:---|
| `omarchy` | Require Omarchy 4 (Quattro); update older installations and recheck |
| `locale` | Generate `ru_RU.UTF-8` and set the system `LANG` |
| `keyboard` | Configure `us,ru` with Alt+Shift and synchronize layouts across keyboards |
| `touchpad` | Enable natural scrolling |
| `menu` | Translate menu labels, generate the extension and install a rebuild hook |
| `packages` | Install `ghostty`, `atuin`, `yazi`, `git-delta`, `television` |
| `blesh` | Build ble.sh for Bash syntax highlighting and suggestions |
| `bash` | Connect ble.sh, atuin, television and yazi to `~/.bashrc` |
| `git` | Use delta as the diff pager |
| `terminal` | Make Ghostty the default terminal |
| `theme` | Apply the theme, background and font from `files/theme.env` |
| `claude` | Configure the Claude Code status line, authorship rule and guard hook |

## A look inside

The Omarchy menu opened with <kbd>Super</kbd> uses Russian labels. Search remains bilingual because the shell searches both label and item ID: «тема» and `theme` find the same item.

```text
  Приложения      Оформление      Установить
  Справка         Настройки       Удалить
  Действия        О системе       Обновить
```

The optional status line uses terminal palette colors, so it follows the current theme. It shows the model and effort, directory, branch and changes, PR state, context usage, cost, diff size, usage limits and elapsed time. Its layout is two rows; the exact values depend on the active session.

## Keys

| Key | Action |
|:---|:---|
| <kbd>Alt</kbd> + <kbd>Shift</kbd> | Switch us ↔ ru across physical keyboards |
| <kbd>Ctrl</kbd> + <kbd>R</kbd> | Search history with atuin |
| <kbd>Ctrl</kbd> + <kbd>T</kbd> | television: file picker on an empty line, word completion otherwise |
| <kbd>Alt</kbd> + <kbd>C</kbd> | Change directory with fzf, as in stock Omarchy |
| <kbd>↑</kbd> | Regular Bash history |
| `y` | Run yazi and change to the directory where it exits |

## Rerunning and backups

Installer-owned changes in existing files live inside marked blocks:

```text
# >>> omarchy-ru:<block> >>>
...
# <<< omarchy-ru:<block> <<<
```

The block is replaced rather than duplicated. Lua and Markdown use their own comment syntax. Before a changed file is written, a sibling `<file>.bak.<timestamp>` is created. Identical files are not rewritten, so reruns do not accumulate unnecessary backups.

The block removal also removes the separator inserted with it, preserving the surrounding configuration. This does not make every system-level operation reversible: theme choices and backups are deliberately retained.

## After installation

1. **Log out and back in.** Hyprland, the shell supervisor and running applications need the new `LANG=ru_RU.UTF-8`. Restarting only the Omarchy shell keeps the old inherited environment.
2. **Open a new terminal.** ble.sh, atuin and television are loaded by Bash. The first start may pause briefly while ble.sh builds its keymap cache.

## Customize

<details>
<summary><strong>Menu labels and updates</strong></summary>

Edit [`files/omarchy/menu-ru.json`](files/omarchy/menu-ru.json), mapping item IDs to `label` and optionally `title`, then run:

```bash
./install.sh menu
```

Items absent from the table are left alone, including product names such as Firefox. Do not edit the generated `~/.config/omarchy/extensions/omarchy-menu.jsonc`: it is overwritten.

The shell merges normalized menu records by field. A partial label-only record would overwrite missing action, icon and condition fields with empty values. The generator therefore copies complete original records and changes their labels. `post-update.d/rebuild-ru-menu` rebuilds those copies after Omarchy updates.

</details>

<details>
<summary><strong>Keyboard layout and switcher</strong></summary>

```bash
RU_KB_SWITCH=grp:ctrl_shift_toggle RU_KB_SECOND_LAYOUT=de ./install.sh keyboard
```

The module reads live Hyprland `kb_layout` and `kb_options`, replaces the previous `grp:*` option and preserves unrelated options such as `compose:caps`. Without a running Hyprland session it uses Omarchy defaults.

Hyprland tracks the XKB group per keyboard. `hypr-sync-kb-layout` listens for `activelayout` events and propagates changes to other physical keyboards.

</details>

<details>
<summary><strong>Theme, background and font</strong></summary>

Defaults live in [`files/theme.env`](files/theme.env):

```bash
RU_THEME="tokyo-night"
RU_THEME_REPO=""                      # Git repository for a non-stock theme
RU_BACKGROUND="0-winding-road.jpg"    # file in the theme's backgrounds/
RU_FONT="JetBrainsMono Nerd Font"
```

Environment variables override the file:

```bash
RU_THEME=gruvbox ./install.sh theme
```

A non-stock theme is installed through `omarchy theme install "$RU_THEME_REPO"` if absent. An empty value means “leave unchanged”.

</details>

<details>
<summary><strong>Status line and authorship settings</strong></summary>

[`files/claude/statusline.sh`](files/claude/statusline.sh) renders the two-row status line; Git status is cached for three seconds to avoid rereading it for every update.

The `claude` module configures three layers:

1. Empty `attribution.commit` and `attribution.pr` settings disable the built-in commit trailer and PR attribution block.
2. A rule from [`files/claude/authorship.md.tmpl`](files/claude/authorship.md.tmpl) is added to `~/.claude/CLAUDE.md`.
3. [`files/claude/hooks/no-ai-attribution.sh`](files/claude/hooks/no-ai-attribution.sh) checks commit and PR-creation commands before execution.

The author name comes from `git config user.name`, then the account's full name in `/etc/passwd`, then the login name. Override it explicitly with:

```bash
RU_AUTHOR="Your Name" ./install.sh claude
```

The installer merges `statusLine` and its hook into `settings.json` while retaining unrelated keys and hooks. On removal, only this project’s hook entry is selected, but `statusLine`, `hideVimModeIndicator` and `attribution` are deleted as whole settings rather than restored to their previous values. Recover previous custom values from backups if needed.

</details>

<details>
<summary><strong>Shell environment</strong></summary>

[`files/bash/head.sh`](files/bash/head.sh) and [`files/bash/tail.sh`](files/bash/tail.sh) are installed into `~/.config/omarchy-ru/bash/`; `~/.bashrc` keeps small loader blocks.

Loading order determines bindings: stock fzf first owns `Ctrl+T`, `Ctrl+R` and `Alt+C`; television replaces the first two; atuin finally takes `Ctrl+R`.

</details>

## Uninstall

```bash
./uninstall.sh              # remove managed blocks, files, hook, menu and Git settings
./uninstall.sh --packages   # also remove packages and ble.sh
./uninstall.sh --locale     # also restore LANG=en_US.UTF-8
./uninstall.sh --dry-run
```

The selected theme, background, font, atuin history and `*.bak.*` backups remain intentionally. The uninstaller unsets global `core.pager`, `interactive.diffFilter` and the configured `delta.*` options; it does not restore earlier custom values. Review backups before uninstalling if those settings were customized before installation.

## Limits

This is **not a complete translation of Omarchy**. Bar widgets, OSD, notification titles, CLI output and the descriptions in `omarchy menu keybindings` remain in their original language. Those strings live in upstream code rather than a localization layer; changing installed files under `/usr/share/omarchy/` would be overwritten by updates.

Atuin synchronization is not configured. Register or sign in separately with `atuin register` / `atuin login` if you want it.

## License

[MIT](LICENSE), like upstream [Omarchy](https://omarchy.org). Copyright © Igor Kramar for this project.
