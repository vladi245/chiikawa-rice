#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/chiikawa-rice
noctalia_dir="$config_home/noctalia"
niri_dir="$config_home/niri"
ghostty_dir="$config_home/ghostty"
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}

say() { printf 'chiikawa: %s\n' "$*"; }

backup=$(cat "$state_dir/last-backup" 2>/dev/null || true)
[ -n "$backup" ] && [ -d "$backup" ] || { say "no install backup found in $state_dir"; exit 1; }

noctalia-shell kill >/dev/null 2>&1 || true
for _ in $(seq 1 25); do
  noctalia-shell ipc call wallpaper get all >/dev/null 2>&1 || break
  sleep 0.2
done

for name in settings.json plugins.json; do
  [ -f "$backup/$name" ] && cp -p "$backup/$name" "$noctalia_dir/$name"
done

for path in "$noctalia_dir/chiikawa" "$noctalia_dir"/plugins/* \
            "$niri_dir/chiikawa.kdl" "$ghostty_dir/chiikawa.ghostty" \
            "$data_home/color-schemes/Chiikawa.colors"; do
  [ -L "$path" ] || continue
  case $(readlink "$path") in "$root"/*) rm -f "$path" ;; esac
done
if [ -f "$backup/links" ]; then
  while IFS="$(printf '\t')" read -r path target; do
    [ -e "$path" ] || ln -sfnT "$target" "$path"
  done < "$backup/links"
fi
if [ -f "$backup/moved" ]; then
  while IFS="$(printf '\t')" read -r path moved; do
    [ -e "$path" ] || [ ! -e "$moved" ] || mv "$moved" "$path"
  done < "$backup/moved"
fi

rm -f "$niri_dir/chiikawa-binds.kdl"
rm -f "$config_home/fastfetch/chiikawa.jsonc"
[ -f "$niri_dir/config.kdl" ] && sed -i '/^\/\/ Chiikawa rice (/d; /^include optional=true "chiikawa\(-binds\)\?\.kdl"$/d' "$niri_dir/config.kdl"
for config in "$ghostty_dir/config.ghostty" "$ghostty_dir/config"; do
  [ -f "$config" ] && sed -i '/chiikawa\.ghostty$/d' "$config"
done
if [ -f "$backup/dolphin-color-scheme" ] && command -v kwriteconfig6 >/dev/null 2>&1; then
  scheme=$(cat "$backup/dolphin-color-scheme")
  if [ -n "$scheme" ]; then
    kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme "$scheme"
  else
    kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme --delete
  fi
fi

if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  noctalia-shell -d >/dev/null 2>&1 < /dev/null
fi
rm -f "$state_dir/last-backup"
say "removed; your configs from $backup are back (pick your old wallpaper in Noctalia)"
