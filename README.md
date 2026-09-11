# Neovim config

Personal Neovim configuration, written in Lua, using
[lazy.nvim](https://github.com/folke/lazy.nvim) for plugins. Ported from an
older vim-plug based `~/.vim` config, with the vimwiki/ticket/diary
automation rewritten from scratch in Lua (see `lua/vimwiki/`).

## Requirements

- **Neovim >= 0.10** (developed and tested on 0.11.6). Check with `nvim --version`.
- **git** - lazy.nvim clones plugins with it.
- **curl** - used by lazy.nvim's bootstrap and by `:NewJiraTicket`.
- **A C compiler + make** (`build-essential` on Debian/Ubuntu, `base-devel`
  on Arch, Xcode Command Line Tools on macOS) - needed to compile
  treesitter parsers, `telescope-fzf-native`'s native sorter, and
  `vim-perl`'s supplementary syntax files. Without this the config still
  loads and works, just without treesitter highlighting/textobjects and
  with a slower (pure-Lua) telescope sorter.
- **ripgrep** (`rg`) - used by Telescope's live grep and file search.
- **node/npm** - needed by Mason to install some LSP servers (e.g.
  `ts_ls`, `bash-language-server`, `vscode-json-languageserver`).
- **python3** with `pip install sqlparse` - only needed for the
  `<leader>json` / `<leader>sql` visual-mode formatting mappings.

None of the above are hard requirements to get *a* working config - only
to get every feature working. lazy.nvim and the plugin configs degrade
gracefully when a tool is missing.

## Install

1. Clone this repo to Neovim's config directory:

   ```sh
   git clone <this-repo-url> ~/.config/nvim
   ```

   (If you don't have a remote for it yet, push it somewhere first, or
   just copy the directory across - e.g. `scp -r ~/.config/nvim
   newhost:~/.config/nvim`.)

2. Launch Neovim:

   ```sh
   nvim
   ```

   On first launch, `lua/config/lazy.lua` bootstraps lazy.nvim itself
   (clones it into `~/.local/share/nvim/lazy/lazy.nvim`), then lazy.nvim
   reads `lazy-lock.json` and installs every plugin pinned there. This
   happens automatically and opens the lazy.nvim UI so you can watch
   progress - just wait for it to finish.

3. Run a health check:

   ```vim
   :checkhealth
   ```

   Look especially at `:checkhealth lazy`, `:checkhealth nvim-treesitter`,
   and `:checkhealth vim.lsp`. Missing external tools (compiler, node,
   LSP servers not yet installed) show up here.

4. Install LSP servers on demand:

   ```vim
   :Mason
   ```

   `lua/plugins/lsp.lua` enables `lua_ls`, `ts_ls`, `jsonls`, and `bashls`,
   but Mason needs to actually download each one the first time (`i` on a
   package in the `:Mason` UI, or `:MasonInstall <name>`).

5. If a C compiler is available, treesitter parsers install themselves on
   first use. To force it:

   ```vim
   :TSUpdate
   ```

## Optional: Jira integration

`:NewJiraTicket <url>` (in a vimwiki buffer) fetches a Jira issue and
creates a ticket page from it. It needs two environment variables set
*before* Neovim starts (add to `.bashrc`/`.zshrc`/etc.):

```sh
export JIRA_EMAIL="you@example.com"
export JIRA_API_TOKEN="<token>"
```

Get a token from
<https://id.atlassian.com/manage-profile/security/api-tokens>. Without
these set, `:NewJiraTicket` just prints a reminder and does nothing - the
rest of the config is unaffected.

## Wiki data

This repo is only the *config*. The actual wiki content lives separately
at `~/vimwiki/mwl/` (configured in `lua/plugins/wiki.lua`) and isn't part
of this repository - back it up / sync it independently (e.g. its own git
repo, or a sync tool) when moving to a new machine.

## Layout

```
init.lua              entry point
lua/config/            options, keymaps, autocmds, user commands, lazy.nvim bootstrap
lua/util/               small standalone helpers (buffer close/wipe, sessions, :Search)
lua/vimwiki/            vimwiki automation: tickets, Jira/ADF, diary, surround, lists
lua/plugins/             one lazy.nvim spec file per plugin/group
ftplugin/                per-filetype config (javascript, perl, vimwiki)
templates/               skeleton.md / skeleton.diary.md used by the ticket/diary commands
spell/                   custom spellfile word list
```

## Known gaps

- No C compiler on the machine this was built on means treesitter
  parsers, `telescope-fzf-native`, and `vim-perl`'s build step haven't
  compiled there - install `build-essential` (or equivalent) and run
  `:Lazy sync` again to pick them up.
- Sessions autosave on quit and load via `<Leader>p`, but there's no
  explicit "save now under a name" command yet (matches what the
  original vim-startify setup exposed).
