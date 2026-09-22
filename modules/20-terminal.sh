#!/usr/bin/env bash

[[ "$INSTALL_WEZTERM" == true ]] || return 0

wezterm_font_available() {
    local families
    command -v fc-match >/dev/null 2>&1 || return 1
    families="$(fc-match -f '%{family}\n' "$1")" || return 1
    # fc-match succeeds even when it substitutes an unrelated font.
    tr ',' '\n' <<< "$families" | grep -Fx -- "$1" >/dev/null
}

install_wezterm_font_fallback() (
    local family="$1" directory="$2" url="$3" pattern="$4" marker="$5"
    local target="$HOME/.local/share/fonts/$directory" temporary
    if wezterm_font_available "$family" || [[ -s "$target/$marker" ]]; then
        return 0
    fi
    temporary="$(mktemp -d)" || return 1
    trap 'rm -rf "$temporary"' EXIT
    log "Installing upstream font: $family"
    curl -fL --retry 3 --connect-timeout 15 --max-time 120 "$url" -o "$temporary/font.zip" || return 1
    unzip -q -j "$temporary/font.zip" "$pattern" -d "$temporary/fonts" || return 1
    [[ -s "$temporary/fonts/$marker" ]] || return 1
    mkdir -p "$target" || return 1
    cp "$temporary/fonts/"*.ttf "$target/" || return 1
)

# FAMILY is the detected distro, distinct from the font helper's local family.
# shellcheck disable=SC2153
install_package_manifest "packages/fonts-${FAMILY}.txt"
install_wezterm_font_fallback 'JetBrains Mono' jetbrains-mono \
    'https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip' \
    'fonts/ttf/*.ttf' JetBrainsMono-Regular.ttf || warn 'Could not install JetBrains Mono fallback'
install_wezterm_font_fallback 'Symbols Nerd Font Mono' symbols-nerd-font-mono \
    'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip' \
    'SymbolsNerdFontMono-Regular.ttf' SymbolsNerdFontMono-Regular.ttf || warn 'Could not install Symbols Nerd Font Mono fallback'

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f || warn 'Could not refresh the font cache'
fi
if command -v fc-match >/dev/null 2>&1; then
    for font in 'JetBrains Mono' 'Symbols Nerd Font Mono'; do
        if wezterm_font_available "$font"; then
            ok "Font available: $font"
        else
            warn "Required WezTerm font not found: $font"
        fi
    done
else
    warn 'fontconfig unavailable; skipping WezTerm font verification'
fi

if ! command -v wezterm >/dev/null 2>&1; then
    log "Installing WezTerm"
    case "$FAMILY" in
        debian)
            sudo install -d -m 0755 /usr/share/keyrings
            if [[ ! -f /usr/share/keyrings/wezterm-fury.gpg ]]; then
                curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
                sudo chmod 0644 /usr/share/keyrings/wezterm-fury.gpg
            fi
            if [[ ! -f /etc/apt/sources.list.d/wezterm.list ]]; then
                echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
            fi
            sudo apt-get update
            sudo apt-get install -y wezterm
            ;;
        fedora)
            install_pkg dnf-plugins-core
            sudo dnf copr enable -y wezfurlong/wezterm-nightly
            sudo dnf install -y wezterm
            ;;
        arch)
            install_pkg wezterm
            ;;
    esac
else
    ok "WezTerm already installed"
fi

config_dir="$HOME/.config/wezterm"
if [[ -d "$config_dir/.git" ]]; then
    remote="$(git -C "$config_dir" remote get-url origin 2>/dev/null || true)"
    if [[ "$remote" == "$WEZTERM_CONFIG_REPO" || "$remote" == "${WEZTERM_CONFIG_REPO%.git}" ]]; then
        if git -C "$config_dir" diff --quiet && git -C "$config_dir" diff --cached --quiet; then
            git -C "$config_dir" fetch origin "$WEZTERM_CONFIG_BRANCH"
            git -C "$config_dir" checkout "$WEZTERM_CONFIG_BRANCH" >/dev/null 2>&1 || true
            git -C "$config_dir" pull --ff-only origin "$WEZTERM_CONFIG_BRANCH" || warn "Could not update WezTerm config"
        else
            warn "Local changes in $config_dir; skipping automatic update"
        fi
    else
        backup_path "$config_dir"
        git clone --depth=1 --branch "$WEZTERM_CONFIG_BRANCH" "$WEZTERM_CONFIG_REPO" "$config_dir"
    fi
elif [[ -e "$config_dir" ]]; then
    backup_path "$config_dir"
    git clone --depth=1 --branch "$WEZTERM_CONFIG_BRANCH" "$WEZTERM_CONFIG_REPO" "$config_dir"
else
    mkdir -p "$HOME/.config"
    git clone --depth=1 --branch "$WEZTERM_CONFIG_BRANCH" "$WEZTERM_CONFIG_REPO" "$config_dir"
fi
