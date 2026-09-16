#!/usr/bin/env bash
#
# Bootstraps this Neovim config on a fresh Debian/Ubuntu machine (including WSL).
#
# Installs every tool listed in the README's "Requirements" section via apt
# (skipping anything already present, since some of these - git, curl,
# ripgrep, node, python - may already be on the target machine and some may
# not), clones this repo into ~/.config/nvim if it isn't already there, and
# finishes by running Neovim headlessly to bootstrap lazy.nvim, sync
# plugins, and install the four Mason LSP servers this config enables.
#
# Safe to re-run - every step checks for an existing install first.
#
# Usage:
#   ./install.sh                  Full install: system tools, config clone, plugins, LSP servers.
#   ./install.sh --skip-mason     Skip installing the Mason LSP servers at the end.
#
#   curl -fsSL https://raw.githubusercontent.com/trgrote/neovim-config/main/install.sh | bash
#   Run directly from GitHub on a brand new machine, before the repo is even cloned locally.
#
# Environment variables:
#   REPO_URL     Git URL to clone when the config isn't already checked out.
#                Defaults to https://github.com/trgrote/neovim-config.git
#   CONFIG_PATH  Target Neovim config directory. Defaults to ~/.config/nvim.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/trgrote/neovim-config.git}"
CONFIG_PATH="${CONFIG_PATH:-$HOME/.config/nvim}"
SKIP_MASON=0

for arg in "$@"; do
	case "$arg" in
		--skip-mason) SKIP_MASON=1 ;;
		*)
			echo "Unknown argument: $arg" >&2
			echo "Usage: $0 [--skip-mason]" >&2
			exit 1
			;;
	esac
done

step() { printf '\n==> %s\n' "$1"; }
skip() { printf '    already present: %s\n' "$1"; }

# --- 1. System tools ---------------------------------------------------

if ! command -v apt-get >/dev/null 2>&1; then
	echo "apt-get was not found. This script is for Debian/Ubuntu (incl. WSL) - see the README for other platforms." >&2
	exit 1
fi

# Neovim isn't installed via apt: Ubuntu/Debian's repo Neovim package is
# often years behind (well under the >= 0.10 this config requires), so the
# official PPA/release is used instead of apt's own "neovim" package.
if command -v nvim >/dev/null 2>&1; then
	skip "Neovim (nvim already on PATH)"
else
	step "Installing Neovim (via the neovim-ppa/unstable PPA, for a version >= 0.10)"
	sudo apt-get update -y
	sudo apt-get install -y software-properties-common
	sudo add-apt-repository -y ppa:neovim-ppa/unstable
	sudo apt-get update -y
	sudo apt-get install -y neovim
fi

step "Installing system packages (build-essential, git, curl, ripgrep, node/npm, python3)"
sudo apt-get update -y
sudo apt-get install -y build-essential git curl ripgrep nodejs npm python3 python3-pip

# --- 2. sqlparse ---------------------------------------------------------

if command -v sqlformat >/dev/null 2>&1; then
	skip "sqlformat (already on PATH)"
else
	step "Installing sqlparse (for the <leader>sql mapping)"
	pip3 install --user --quiet sqlparse
	if ! command -v sqlformat >/dev/null 2>&1; then
		echo "Installed sqlparse but sqlformat isn't on PATH yet - make sure ~/.local/bin is in your PATH (add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your shell rc file), then restart your shell." >&2
	fi
fi

# --- 3. Clone the config -------------------------------------------------

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

if [ "$script_dir" = "$CONFIG_PATH" ]; then
	skip "config repo (script is already running from $CONFIG_PATH)"
elif [ -d "$CONFIG_PATH" ]; then
	skip "config repo ($CONFIG_PATH already exists)"
else
	step "Cloning $REPO_URL into $CONFIG_PATH"
	git clone "$REPO_URL" "$CONFIG_PATH"
fi

# --- 4. Bootstrap plugins + LSP servers -----------------------------------

step "Bootstrapping lazy.nvim and syncing plugins (this compiles treesitter parsers and telescope-fzf-native - may take a minute)"
nvim --headless "+Lazy! sync" +qa

if [ "$SKIP_MASON" -eq 0 ]; then
	step "Installing Mason LSP servers (lua_ls, ts_ls, jsonls, bashls)"
	nvim --headless -c "MasonInstall lua-language-server typescript-language-server json-lsp bash-language-server" -c "sleep 30000m" -c "qa!"
fi

step "Done. Restart your shell so PATH changes take effect, then run 'nvim' and ':checkhealth' to confirm everything's green."
