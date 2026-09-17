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

MIN_NVIM_VERSION="0.12.0"
MIN_NODE_VERSION="18.0.0"

step() { printf '\n==> %s\n' "$1"; }
skip() { printf '    already present: %s\n' "$1"; }

# Prints the "major.minor.patch" out of `nvim --version`'s first line
# (e.g. "NVIM v0.12.5" -> "0.12.5").
nvim_version() {
	nvim --version | head -1 | sed -E 's/^NVIM v([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
}

# Prints node's version without the leading "v" (e.g. "v18.0.0" -> "18.0.0").
node_version() {
	node --version | sed -E 's/^v//'
}

# Returns success if $1 >= $2 (both "major.minor.patch" version strings).
version_ge() {
	[ "$(printf '%s\n%s' "$2" "$1" | sort -V | head -1)" = "$2" ]
}

# --- 1. System tools ---------------------------------------------------

if ! command -v apt-get >/dev/null 2>&1; then
	echo "apt-get was not found. This script is for Debian/Ubuntu (incl. WSL) - see the README for other platforms." >&2
	exit 1
fi

# Neovim isn't installed via apt: Ubuntu/Debian's repo Neovim package is
# often years behind (well under the >= 0.12 this config requires), so the
# official PPA/release is used instead of apt's own "neovim" package.
install_neovim_ppa() {
	step "Installing Neovim (via the neovim-ppa/unstable PPA, for a version >= $MIN_NVIM_VERSION)"
	sudo apt-get update -y
	sudo apt-get install -y software-properties-common
	sudo add-apt-repository -y ppa:neovim-ppa/unstable
	sudo apt-get update -y
	sudo apt-get install -y neovim
}

if command -v nvim >/dev/null 2>&1; then
	current_version="$(nvim_version)"
	if version_ge "$current_version" "$MIN_NVIM_VERSION"; then
		skip "Neovim (v$current_version already on PATH)"
	else
		echo "nvim v$current_version is on PATH, but this config requires >= v$MIN_NVIM_VERSION - nvim-treesitter's main branch will fail on older Neovim (attempt to call method 'range' (a nil value))." >&2
		# Read from the controlling terminal, not stdin, since this script is
		# commonly run as `curl ... | bash`, which leaves stdin attached to
		# the piped script rather than the user.
		read -r -p "Upgrade Neovim now via the neovim-ppa/unstable PPA? [y/N] " reply </dev/tty
		case "$reply" in
			[Yy]|[Yy][Ee][Ss])
				install_neovim_ppa
				;;
			*)
				echo "Aborting: Neovim must be >= v$MIN_NVIM_VERSION for this config to work." >&2
				exit 1
				;;
		esac
	fi
else
	install_neovim_ppa
fi

step "Installing system packages (build-essential, git, curl, ripgrep, node/npm, python3)"
sudo apt-get update -y
sudo apt-get install -y build-essential git curl ripgrep nodejs npm python3 python3-pip

# Ubuntu/Debian's apt repos often ship a Node version well below what Mason's
# LSP servers need - bash-language-server in particular crashes on startup
# with "SyntaxError: Unexpected token ." (optional chaining) on Node < 14,
# and other servers may need newer still. Abort rather than silently
# installing LSP servers that will crash-loop.
current_node_version="$(node_version)"
if ! version_ge "$current_node_version" "$MIN_NODE_VERSION"; then
	echo "Error: node v$current_node_version is on PATH (likely from apt's own package), but this config requires >= v$MIN_NODE_VERSION for Mason's LSP servers to run correctly. Install a newer Node yourself (e.g. via nvm, or the NodeSource repo: https://github.com/nodesource/distributions) so that 'node' on PATH resolves to >= v$MIN_NODE_VERSION, then re-run this script." >&2
	exit 1
fi

if command -v tree-sitter >/dev/null 2>&1; then
	skip "tree-sitter CLI (already on PATH)"
else
	step "Installing the tree-sitter CLI (needed by nvim-treesitter's main branch to build parsers)"
	sudo npm install -g tree-sitter-cli
fi

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
