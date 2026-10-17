#!/usr/bin/env bash
#
# Bootstraps this Neovim config on a fresh macOS machine (Apple Silicon or Intel).
#
# Installs every tool listed in the README's "Requirements" section via
# Homebrew (installing Homebrew itself first if it's missing, which also
# pulls in the Xcode Command Line Tools for the C compiler + make), skipping
# anything already present, clones this repo into ~/.config/nvim if it isn't
# already there, and finishes by running Neovim headlessly to bootstrap
# lazy.nvim, sync plugins, and install the four Mason LSP servers this
# config enables.
#
# Node is managed by fnm rather than Homebrew's node: it installs the latest
# LTS Node and points fnm's "nvim" alias at it (lua/config/node.lua pins
# Neovim to that alias, so projects needing an older Node don't break
# Mason's LSP servers), makes it fnm's default if there isn't one yet, and
# adds fnm's --use-on-cd hook to your shell rc file (~/.zshrc, or
# ~/.bash_profile if your login shell is bash) so projects with an
# .nvmrc/.node-version switch Node automatically. FNM_DIR is pinned to
# ~/.local/share/fnm rather than fnm's macOS default of
# ~/Library/Application Support/fnm, since that's where lua/config/node.lua
# looks for the alias. The tree-sitter CLI comes from its GitHub release
# binary rather than npm, so it isn't tied to whichever fnm Node is active.
#
# Safe to re-run - every step checks for an existing install first.
#
# Usage:
#   ./install-mac.sh                  Full install: system tools, config clone, plugins, LSP servers.
#   ./install-mac.sh --skip-mason     Skip installing the Mason LSP servers at the end.
#
#   curl -fsSL https://raw.githubusercontent.com/trgrote/neovim-config/main/install-mac.sh | bash
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

if [ "$(uname -s)" != "Darwin" ]; then
	echo "This script is for macOS - use install.sh on Debian/Ubuntu (incl. WSL) or Install.ps1 on Windows." >&2
	exit 1
fi

MIN_NVIM_VERSION="0.12.0"
MIN_NODE_VERSION="18.0.0"

step() { printf '\n==> %s\n' "$1"; }
skip() { printf '    already present: %s\n' "$1"; }

# Prints the "major.minor.patch" out of `nvim --version`'s first line
# (e.g. "NVIM v0.12.5" -> "0.12.5").
nvim_version() {
	nvim --version | head -1 | sed -E 's/^NVIM v([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
}

# Always use the XDG-style location lua/config/node.lua checks, not fnm's
# macOS default under ~/Library/Application Support.
export FNM_DIR="${FNM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/fnm}"
# The Node that lua/config/node.lua pins Neovim to, regardless of which Node
# the shell / project has active.
NVIM_NODE="$FNM_DIR/aliases/nvim/bin/node"

# Prints the pinned Node's version without the leading "v" (e.g. "v18.0.0" -> "18.0.0").
node_version() {
	"$NVIM_NODE" --version | sed -E 's/^v//'
}

# Returns success if $1 >= $2 (both "major.minor.patch" version strings).
# Compares field by field rather than with `sort -V`, which older macOS
# releases' sort doesn't support.
version_ge() {
	local IFS=.
	local -a a=($1) b=($2)
	local i
	for i in 0 1 2; do
		if [ "${a[i]:-0}" -gt "${b[i]:-0}" ]; then return 0; fi
		if [ "${a[i]:-0}" -lt "${b[i]:-0}" ]; then return 1; fi
	done
	return 0
}

# Login shells on macOS (Terminal/iTerm) read ~/.zshrc for zsh, but bash
# login shells read ~/.bash_profile rather than ~/.bashrc.
case "$(basename "${SHELL:-/bin/zsh}")" in
	bash)
		SHELL_NAME="bash"
		SHELL_RC="$HOME/.bash_profile"
		;;
	*)
		SHELL_NAME="zsh"
		SHELL_RC="$HOME/.zshrc"
		;;
esac

# --- 1. Xcode Command Line Tools + Homebrew ------------------------------

if xcode-select -p >/dev/null 2>&1; then
	skip "Xcode Command Line Tools"
elif command -v brew >/dev/null 2>&1; then
	# The Homebrew installer below installs these itself, so this is only
	# reached when Homebrew is already present but the CLT were removed.
	step "Installing the Xcode Command Line Tools (C compiler + make) - accept the dialog that pops up"
	xcode-select --install
	until xcode-select -p >/dev/null 2>&1; do
		sleep 5
	done
fi

if command -v brew >/dev/null 2>&1; then
	skip "Homebrew"
else
	step "Installing Homebrew (also installs the Xcode Command Line Tools if missing)"
	# Read from the controlling terminal, not stdin, since this script is
	# commonly run as `curl ... | bash`, which leaves stdin attached to the
	# piped script rather than the user (Homebrew's installer prompts for
	# your password).
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
fi

# Homebrew lives in /opt/homebrew on Apple Silicon and /usr/local on Intel;
# the former isn't on PATH until `brew shellenv` runs.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
	if [ -x "$brew_bin" ]; then
		eval "$("$brew_bin" shellenv)"
		break
	fi
done

if [ "$SHELL_NAME" = "zsh" ]; then
	BREW_PROFILE="$HOME/.zprofile"
else
	BREW_PROFILE="$HOME/.bash_profile"
fi
if [ "$(brew --prefix)" = "/usr/local" ] || grep -qs 'brew shellenv' "$BREW_PROFILE"; then
	skip "Homebrew shellenv (already on PATH)"
else
	step "Adding Homebrew's shellenv to $BREW_PROFILE"
	cat >>"$BREW_PROFILE" <<EOF

eval "\$($(brew --prefix)/bin/brew shellenv)"
EOF
fi

# --- 2. Neovim + system tools -----------------------------------------------

if command -v nvim >/dev/null 2>&1; then
	current_version="$(nvim_version)"
	if version_ge "$current_version" "$MIN_NVIM_VERSION"; then
		skip "Neovim (v$current_version already on PATH)"
	else
		echo "nvim v$current_version is on PATH, but this config requires >= v$MIN_NVIM_VERSION - nvim-treesitter's main branch will fail on older Neovim (attempt to call method 'range' (a nil value))." >&2
		read -r -p "Install/upgrade Neovim now via Homebrew? [y/N] " reply </dev/tty
		case "$reply" in
			[Yy]|[Yy][Ee][Ss])
				step "Upgrading Neovim via Homebrew"
				if brew list neovim >/dev/null 2>&1; then
					brew upgrade neovim
				else
					brew install neovim
				fi
				hash -r
				if ! version_ge "$(nvim_version)" "$MIN_NVIM_VERSION"; then
					echo "Installed Neovim via Homebrew, but an older nvim at $(command -v nvim) still comes first on PATH - remove it or put $(brew --prefix)/bin ahead of it, then re-run this script." >&2
					exit 1
				fi
				;;
			*)
				echo "Aborting: Neovim must be >= v$MIN_NVIM_VERSION for this config to work." >&2
				exit 1
				;;
		esac
	fi
else
	step "Installing Neovim via Homebrew"
	brew install neovim
fi

# git and curl already ship with the Xcode Command Line Tools / macOS, but
# Homebrew's git is newer. `brew install` skips anything already installed.
step "Installing system packages (git, ripgrep, fnm, pipx)"
brew install git ripgrep fnm pipx

# --- 3. Neovim's pinned Node ---------------------------------------------

if [ -x "$NVIM_NODE" ]; then
	skip "Neovim's pinned Node (fnm alias 'nvim')"
else
	step "Installing the latest LTS Node via fnm and aliasing it as 'nvim'"
	fnm install --lts
	lts_version="$(fnm exec --using=lts-latest -- node --version)"
	fnm alias "$lts_version" nvim
fi

if [ -e "$FNM_DIR/aliases/default" ]; then
	skip "fnm default Node"
else
	nvim_node_version="$("$NVIM_NODE" --version)"
	step "Setting fnm's default Node to $nvim_node_version"
	fnm default "$nvim_node_version"
fi

# Mason's LSP servers crash on old Node - bash-language-server in particular
# crashes on startup with "SyntaxError: Unexpected token ." (optional
# chaining) on Node < 14, and other servers may need newer still. Abort
# rather than silently installing LSP servers that will crash-loop.
current_node_version="$(node_version)"
if ! version_ge "$current_node_version" "$MIN_NODE_VERSION"; then
	echo "Error: fnm's 'nvim' alias points at node v$current_node_version, but this config requires >= v$MIN_NODE_VERSION for Mason's LSP servers to run correctly. Re-point it with 'fnm install --lts && fnm alias <version> nvim', then re-run this script." >&2
	exit 1
fi

if grep -qs 'fnm env' "$SHELL_RC"; then
	skip "fnm shell hook (already in $SHELL_RC)"
else
	step "Adding fnm's --use-on-cd hook (and ~/.local/bin on PATH) to $SHELL_RC"
	cat >>"$SHELL_RC" <<EOF

# tree-sitter and pipx-installed tools (sqlformat) live here
export PATH="\$HOME/.local/bin:\$PATH"
# Keep fnm's Node installs where lua/config/node.lua looks for them
export FNM_DIR="$FNM_DIR"
# Switch Node per directory from .nvmrc/.node-version/package.json engines
eval "\$(fnm env --use-on-cd --version-file-strategy=recursive --resolve-engines --shell $SHELL_NAME)"
EOF
fi

# --- 4. tree-sitter CLI ----------------------------------------------------

if command -v tree-sitter >/dev/null 2>&1; then
	skip "tree-sitter CLI (already on PATH)"
else
	step "Installing the tree-sitter CLI (needed by nvim-treesitter's main branch to build parsers)"
	case "$(uname -m)" in
		arm64) ts_arch="arm64" ;;
		x86_64) ts_arch="x64" ;;
		*)
			echo "Unsupported architecture $(uname -m) for the tree-sitter release binary." >&2
			exit 1
			;;
	esac
	mkdir -p "$HOME/.local/bin"
	curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-macos-$ts_arch.gz" |
		gunzip >"$HOME/.local/bin/tree-sitter"
	chmod +x "$HOME/.local/bin/tree-sitter"
fi

# --- 5. sqlparse ---------------------------------------------------------

if command -v sqlformat >/dev/null 2>&1 || [ -x "$HOME/.local/bin/sqlformat" ]; then
	skip "sqlformat"
else
	# pipx rather than `pip3 install --user`: Homebrew's Python refuses
	# user-level pip installs (PEP 668 "externally-managed-environment").
	step "Installing sqlparse via pipx (for the <leader>sql mapping)"
	pipx install sqlparse
fi

# --- 6. Clone the config -------------------------------------------------

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

if [ "$script_dir" = "$CONFIG_PATH" ]; then
	skip "config repo (script is already running from $CONFIG_PATH)"
elif [ -d "$CONFIG_PATH" ]; then
	skip "config repo ($CONFIG_PATH already exists)"
else
	step "Cloning $REPO_URL into $CONFIG_PATH"
	git clone "$REPO_URL" "$CONFIG_PATH"
fi

# --- 7. Bootstrap plugins + LSP servers -----------------------------------

# So the headless Neovim runs below can find tree-sitter.
export PATH="$HOME/.local/bin:$PATH"

step "Bootstrapping lazy.nvim and syncing plugins (this compiles treesitter parsers and telescope-fzf-native - may take a minute)"
nvim --headless "+Lazy! sync" +qa

if [ "$SKIP_MASON" -eq 0 ]; then
	step "Installing Mason LSP servers (lua_ls, ts_ls, jsonls, bashls) if not already installed"
	# `:MasonInstall` reinstalls unconditionally even when a package is
	# already present, which is why a re-run of this script always redownloads
	# every server. Query mason-registry directly instead and only install
	# packages that aren't already installed. (BSD mktemp has no --suffix,
	# but :luafile doesn't care about the extension.)
	mason_script="$(mktemp "${TMPDIR:-/tmp}/nvim-mason.XXXXXX")"
	cat >"$mason_script" <<'LUA'
local registry = require("mason-registry")
local names = { "lua-language-server", "typescript-language-server", "json-lsp", "bash-language-server" }
local pending = 0
local function finish()
  pending = pending - 1
  if pending <= 0 then vim.cmd("qa!") end
end
registry.refresh(function()
  local to_install = {}
  for _, name in ipairs(names) do
    local pkg = registry.get_package(name)
    if pkg:is_installed() then
      print(name .. " already installed - skipping")
    else
      table.insert(to_install, pkg)
    end
  end
  if #to_install == 0 then
    vim.cmd("qa!")
    return
  end
  pending = #to_install
  for _, pkg in ipairs(to_install) do
    pkg:install():once("closed", finish)
  end
end)
LUA
	nvim --headless -c "luafile $mason_script" -c "sleep 30000m"
	rm -f "$mason_script"
fi

step "Done. Restart your shell so PATH changes take effect, then run 'nvim' and ':checkhealth' to confirm everything's green."
