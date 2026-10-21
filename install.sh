#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/chiikawa-rice
noctalia_dir="$config_home/noctalia"
settings_file="$noctalia_dir/settings.json"
plugins_file="$noctalia_dir/plugins.json"
niri_dir="$config_home/niri"
ghostty_dir="$config_home/ghostty"
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
wallpapers_file=${XDG_CACHE_HOME:-"$HOME/.cache"}/noctalia/wallpapers.json

say() { printf 'chiikawa: %s\n' "$*"; }
warn() { printf 'chiikawa: warning: %s\n' "$*" >&2; }
die() { printf 'chiikawa: %s\n' "$*" >&2; exit 1; }

for cmd in noctalia-shell quickshell niri jq flock; do
  command -v "$cmd" >/dev/null 2>&1 || die "missing '$cmd' (see Requirements in README.md)"
done
command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1 \
  || die "missing ImageMagick (see Requirements in README.md)"
[ -f "$settings_file" ] || die "no $settings_file yet; start Noctalia once, then rerun"
for font in Nunito "Maple Mono NF"; do
  fc-list : family 2>/dev/null | grep -qiF "$font" || warn "font '$font' not found; the rice will fall back to another face"
done

# Rerunning keeps the backup from before the first install.
backup=$(cat "$state_dir/last-backup" 2>/dev/null || true)
rerun=true
if [ -z "$backup" ] || [ ! -d "$backup" ]; then
  rerun=false
  backup="$state_dir/backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup"
  for file in "$settings_file" "$plugins_file" "$wallpapers_file" "$niri_dir/config.kdl" \
              "$ghostty_dir/config" "$ghostty_dir/config.ghostty"; do
    if [ -f "$file" ]; then cp -p "$file" "$backup/$(basename "$file")"; fi
  done
  printf '%s\n' "$backup" > "$state_dir/last-backup"
  say "backed up your configs to $backup"
fi

# Move real files into the backup and note links to elsewhere for uninstall.sh.
link() {
  if [ -L "$2" ]; then
    case $(readlink "$2") in
      "$root"/*) ;;
      *) printf '%s\t%s\n' "$2" "$(readlink "$2")" >> "$backup/links" ;;
    esac
  elif [ -e "$2" ]; then
    moved="$backup/moved-$(basename "$2")"
    mv "$2" "$moved"
    printf '%s\t%s\n' "$2" "$moved" >> "$backup/moved"
    warn "moved existing $2 to the backup"
  fi
  ln -sfnT "$1" "$2"
}

# Noctalia rewrites settings.json on exit, so stop it before editing.
noctalia_running() { timeout 3 noctalia-shell ipc call wallpaper get all >/dev/null 2>&1; }
noctalia_pids() { timeout 5 noctalia-shell list 2>/dev/null | sed -n 's/^ *Process ID: //p'; }
# Ask Noctalia to quit, then escalate: a shell can hang while tearing down.
stop_noctalia() {
  pids=$(noctalia_pids)
  [ -n "$pids" ] || return 0
  timeout 5 noctalia-shell kill >/dev/null 2>&1 || true
  for sig in TERM KILL; do
    for _ in $(seq 1 25); do
      alive=
      for pid in $pids; do kill -0 "$pid" 2>/dev/null && alive=1; done
      [ -n "$alive" ] || return 0
      sleep 0.2
    done
    kill -s "$sig" $pids 2>/dev/null || true
  done
}
stop_noctalia

mkdir -p "$noctalia_dir/plugins" "$noctalia_dir/colorschemes"
# Plugins import the theme as ../../chiikawa.
link "$root/theme" "$noctalia_dir/chiikawa"
# Light and night colors for Noctalia's own panels and widgets.
link "$root/noctalia/colorschemes/Chiikawa" "$noctalia_dir/colorschemes/Chiikawa"
plugin_ids=
for plugin_dir in "$root"/plugins/*/; do
  plugin_id=$(basename "$plugin_dir")
  link "$root/plugins/$plugin_id" "$noctalia_dir/plugins/$plugin_id"
  plugin_ids="$plugin_ids $plugin_id"
done

[ -f "$plugins_file" ] || printf '{"states": {}}\n' > "$plugins_file"
settings_tmp=$(mktemp "$noctalia_dir/.settings.XXXXXX")
plugins_tmp=$(mktemp "$noctalia_dir/.plugins.XXXXXX")
trap 'rm -f "$settings_tmp" "$plugins_tmp"' EXIT HUP INT TERM
# A rerun keeps the light/dark choice. The dark mode hook is only claimed if
# it's free, and hooks are only switched on if no others would wake up.
jq --slurpfile rice "$root/noctalia/settings.json" --arg lock "$root/scripts/lock-screen" \
   --arg hook "\"$root/scripts/chiikawa-mode\" \$1" --argjson rerun "$rerun" '
  .colorSchemes.darkMode as $dark
  | (.hooks // {}) as $hooks
  | . * $rice[0]
  | if $rerun and $dark != null then .colorSchemes.darkMode = $dark else . end
  | if .sessionMenu.powerOptions then
      .sessionMenu.powerOptions |= map(if .action == "lock" then .command = $lock else . end)
    else . end
  | if ($hooks.darkModeChange // "") == "" or ($hooks.darkModeChange | contains("chiikawa-mode")) then
      .hooks.darkModeChange = $hook
      | if [$hooks | to_entries[] | select(.key != "enabled" and .key != "darkModeChange" and .value != "")] == []
        then .hooks.enabled = true else . end
    else . end
' "$settings_file" > "$settings_tmp"
# shellcheck disable=SC2086
jq --args '.states += ([$ARGS.positional[] | {(.): {enabled: true, sourceUrl: "local"}}] | add)' \
  $plugin_ids < "$plugins_file" > "$plugins_tmp"
chmod --reference="$settings_file" "$settings_tmp"
chmod --reference="$plugins_file" "$plugins_tmp"
mv -f "$settings_tmp" "$settings_file"
mv -f "$plugins_tmp" "$plugins_file"
trap - EXIT HUP INT TERM
dark_mode=$(jq -r '.colorSchemes.darkMode == true' "$settings_file")
jq -e '.hooks.enabled == true and (.hooks.darkModeChange | contains("chiikawa-mode"))' "$settings_file" >/dev/null \
  || warn "niri and Dolphin won't follow dark mode; in Noctalia's hooks, enable hooks and set the dark mode hook to: \"$root/scripts/chiikawa-mode\" \$1"

"$root/scripts/apply-noctalia-bar" "$root/noctalia/bar.json"
say "linked the theme and $(echo "$plugin_ids" | wc -w) plugins, applied the bar"

# The cast picker saves its choices here.
mkdir -p "$config_home/chiikawa-rice"

mkdir -p "$niri_dir"
link "$root/niri/chiikawa.kdl" "$niri_dir/chiikawa.kdl"
cat > "$niri_dir/chiikawa-binds.kdl" <<EOF
// Generated by $root/install.sh
// niri treats Mod+ and Super+ as different keys, so both are bound to
// replace whichever one the main config uses.
binds {
    Mod+Space hotkey-overlay-title="Chiikawa Launcher" { spawn "noctalia-shell" "ipc" "call" "plugin" "togglePanel" "chiikawa-launcher"; }
    Super+Space hotkey-overlay-title=null { spawn "noctalia-shell" "ipc" "call" "plugin" "togglePanel" "chiikawa-launcher"; }
    Mod+Alt+L repeat=false allow-inhibiting=false hotkey-overlay-title="Lock Screen" { spawn "$root/scripts/lock-screen"; }
    Super+Alt+L repeat=false allow-inhibiting=false hotkey-overlay-title=null { spawn "$root/scripts/lock-screen"; }
}
EOF
niri_config="$niri_dir/config.kdl"
if [ -f "$niri_config" ]; then
  if ! grep -qF 'chiikawa.kdl' "$niri_config"; then
    [ -z "$(tail -c 1 "$niri_config")" ] || echo >> "$niri_config"
    printf '// Chiikawa rice (%s)\ninclude optional=true "chiikawa.kdl"\ninclude optional=true "chiikawa-binds.kdl"\n' \
      "$root" >> "$niri_config"
  fi
  niri validate -c "$niri_config" >/dev/null 2>&1 || warn "niri says $niri_config is invalid; check it with: niri validate"
  say "niri includes chiikawa.kdl and chiikawa-binds.kdl"
else
  warn "no $niri_config; add include \"chiikawa.kdl\" and include \"chiikawa-binds.kdl\" to yours"
fi

if command -v ghostty >/dev/null 2>&1 || [ -d "$ghostty_dir" ]; then
  mkdir -p "$ghostty_dir"
  link "$root/ghostty/chiikawa.ghostty" "$ghostty_dir/chiikawa.ghostty"
  mkdir -p "$ghostty_dir/themes"
  link "$root/ghostty/themes/chiikawa" "$ghostty_dir/themes/chiikawa"
  link "$root/ghostty/themes/chiikawa-night" "$ghostty_dir/themes/chiikawa-night"
  ghostty_config="$ghostty_dir/config.ghostty"
  [ -f "$ghostty_config" ] || [ ! -f "$ghostty_dir/config" ] || ghostty_config="$ghostty_dir/config"
  if ! grep -qsF chiikawa.ghostty "$ghostty_config"; then
    [ ! -s "$ghostty_config" ] || [ -z "$(tail -c 1 "$ghostty_config")" ] || echo >> "$ghostty_config"
    printf 'config-file = ?%s\n' "$ghostty_dir/chiikawa.ghostty" >> "$ghostty_config"
  fi
  say "Ghostty loads chiikawa.ghostty last"
fi

mkdir -p "$data_home/color-schemes"
link "$root/kde/Chiikawa.colors" "$data_home/color-schemes/Chiikawa.colors"
link "$root/kde/ChiikawaNight.colors" "$data_home/color-schemes/ChiikawaNight.colors"
if command -v kwriteconfig6 >/dev/null 2>&1; then
  if [ ! -f "$backup/dolphin-color-scheme" ]; then
    kreadconfig6 --file dolphinrc --group UiSettings --key ColorScheme > "$backup/dolphin-color-scheme"
  fi
  kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme Chiikawa
  say "Dolphin uses the Chiikawa color schemes (reopen its windows)"
fi

# Bring niri and Dolphin in line with the current mode.
"$root/scripts/chiikawa-mode" "$dark_mode"

if command -v fastfetch >/dev/null 2>&1; then
  mkdir -p "$config_home/fastfetch"
  sed "s|@LOGO@|$root/fastfetch/momonga.png|" "$root/fastfetch/chiikawa.jsonc" \
    > "$config_home/fastfetch/chiikawa.jsonc"
  say "run 'fastfetch -c chiikawa' for Momonga"
fi

stop_noctalia

# Noctalia keeps a light and a dark wallpaper per screen and swaps them with
# dark mode. It only reads this file at startup, so write it while it's down.
mkdir -p "$(dirname "$wallpapers_file")"
[ -s "$wallpapers_file" ] || printf '{}\n' > "$wallpapers_file"
wallpapers_tmp=$(mktemp "$(dirname "$wallpapers_file")/.wallpapers.XXXXXX")
trap 'rm -f "$wallpapers_tmp"' EXIT HUP INT TERM
# shellcheck disable=SC2046
jq --arg light "$root/wallpaper/chiikawa.jpg" --arg dark "$root/wallpaper/rakko.jpg" --args '
  .wallpapers = ((.wallpapers // {}) + ([$ARGS.positional[] | {(.): {}}] | add // {})
    | map_values({light: $light, dark: $dark}))
' $(niri msg --json outputs 2>/dev/null | jq -r 'keys[]' 2>/dev/null) < "$wallpapers_file" > "$wallpapers_tmp"
mv -f "$wallpapers_tmp" "$wallpapers_file"
trap - EXIT HUP INT TERM
say "wallpapers: chiikawa in light mode, rakko in dark mode"

if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  setsid -f noctalia-shell -d >/dev/null 2>&1 < /dev/null
  for _ in $(seq 1 50); do
    noctalia_running && break
    sleep 0.2
  done
  say "restarted Noctalia"
else
  say "not in a Wayland session; log into niri to see it"
fi

say "done! reload Ghostty with Ctrl+Shift+, and try Mod+Space, Mod+O and Mod+Alt+L"
say "dark mode is a tile in the control center, or: noctalia-shell ipc call darkMode toggle"
