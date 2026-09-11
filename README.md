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

## Ported settings worth reconsidering

The port tried to preserve the old `.vim` config's behavior closely. A
few of those choices turned out to be redundant or actively working
against either Neovim's own (different-from-Vim) defaults, or a plugin
that's now installed. None of these are broken - they're just not doing
what they did in the original config anymore, or aren't doing anything
at all. Listed here instead of silently fixed, so you can decide whether
to keep, change, or remove each one.

- **Session management (`<Leader>p`) - your instinct was right, but not
  because Neovim itself changed.** Neovim doesn't have a different
  *native* session mechanism - it's still the same `:mksession` /
  `:source` primitives Vim has always had, and `lua/util/sessions.lua`
  is just a thin wrapper around them (mirroring what vim-startify did).
  **What's actually different now:** `mini.nvim` is already installed
  (for `mini.bracketed` in `lua/plugins/editor.lua`), and that same
  plugin ships a `mini.sessions` module that does this job in a more
  complete, battle-tested way (detects sessions from multiple
  directories, read/write hooks, etc.) for zero additional dependency
  cost. **Use today:** `<Leader>p` still works as before (prompts for a
  session name, defaults to the current directory's name, autosaves on
  quit). If you want the fuller `mini.sessions` experience instead, add
  `require('mini.sessions').setup()` next to the `mini.bracketed` setup
  in `lua/plugins/editor.lua`, then use `:lua MiniSessions.write('name')`
  and `:lua MiniSessions.read('name')` (or `.select()` for a picker) -
  at that point `lua/util/sessions.lua` and its `<Leader>p` mapping
  become redundant and can be deleted.

- **The custom statusline format string is dead code.** `vim.opt.statusline`
  in `lua/config/options.lua` still contains the old
  `%F%m%r%h%w [FORMAT=...] [TYPE=...] [POS=...]` format string ported
  from the original `vimrc`, but `lualine.nvim` (which replaced
  vim-airline) takes over `'statusline'`/`'laststatus'` entirely once it
  loads and ignores that setting completely - confirmed by direct
  inspection: `laststatus` ends up `3` and `'statusline'` gets
  overwritten to lualine's own render string. **Use today:** the
  statusline's actual content/format is controlled by the `sections`
  table in `lua/plugins/ui.lua`, not `vim.opt.statusline`. The
  `vim.opt.statusline` block in `options.lua` can be deleted.

- **`gcc`/`gc` replace nerdcommenter's mappings, not just the plugin.**
  nerdcommenter is dropped in favor of Neovim's built-in commenting
  (added in 0.10), which is why there's no `Comment.nvim`-style plugin in
  `lua/plugins/`. This is a real muscle-memory change, not just an
  internal swap: nerdcommenter's own default mappings (its
  `<leader>c...` family) no longer exist at all. **Use instead:** `gcc`
  toggles a comment on the current line, `gc{motion}` comments a motion
  (e.g. `gcap` for a paragraph), and visual-mode `gc` comments the
  selection.

- **`g<C-a>`/`g<C-x>` replace vim-visual-increment.** That plugin is
  dropped because sequential increment across a visual selection has
  been a native Vim/Neovim feature for a long time already - it didn't
  need a plugin in the first place. **Use instead:** select a block of
  numbers visually and press `g<C-a>` (or `g<C-x>` to decrement) to
  increment each one sequentially, same result the plugin gave.

- **Telescope's `<c-p>` doesn't auto-detect the project root the way
  CtrlP did.** The original's `g:ctrlp_working_path_mode = 'ra'` made
  CtrlP automatically search from the nearest ancestor directory
  containing a `.git` (or similar) marker, regardless of Neovim's actual
  `:pwd`. `lua/plugins/telescope.lua` was never given an equivalent, so
  `<c-p>` now searches from Neovim's current working directory only -
  this is a genuine gap in the port, not an intentional change. **Use
  today:** `:cd` (or `:lcd`) to the project root before searching, or
  pass a directory explicitly with `:Telescope find_files
  cwd=/path/to/project`. Say the word if you'd like me to wire up
  automatic root detection (a few lines using `vim.fs.root()`) instead.

- **A few ported options are pure no-ops on Neovim** - they already
  match Neovim's built-in defaults (which differ from Vim's), so porting
  them from the old `vimrc` accomplished nothing: `hidden`, `backspace`,
  `incsearch`, `hlsearch`, `ruler`, `wrap`, `textwidth=0`, `wrapmargin=0`,
  and `undolevels=1000` in `lua/config/options.lua`. Harmless, but safe
  to delete as clutter.

- **`history = 1000` is a downgrade, not a match.** The original set
  this because vanilla Vim's default history was small; Neovim's own
  built-in default is already `10000`. As written, this line makes
  command/search history *shorter* than what you'd get by deleting it.
  **Use instead:** remove the line (keeps Neovim's `10000`), or set it
  explicitly higher if you have a reason to.

- **`formatoptions = "cqt"` drops a newer Neovim default you might
  want back.** Neovim's own default `formatoptions` is `"tcqj"` - the
  extra `j` flag (introduced after this option's Vim-era defaults were
  set) strips the comment leader automatically when joining commented
  lines with `J`. The ported value overwrites that. **Use instead:** if
  you want that behavior, change it to `"cqtj"` in `options.lua`.

- **`lazyredraw = true` is a Vim-era workaround that doesn't fit
  Neovim's redraw model.** It was a real performance aid in Vim's
  synchronous terminal redraw loop (e.g. during macros); Neovim's UI
  renders asynchronously over a decoupled event protocol, where
  `lazyredraw` mostly just risks visual glitches instead of helping.
  **Use instead:** removing this line from `options.lua` is likely a
  safe cleanup; if a specific macro feels slow, that's worth
  investigating on its own rather than via this global flag.

- **Two separate ignore-pattern lists now exist for two different
  tools.** `wildignore` in `options.lua` (native `:e<Tab>`/`:find`
  completion) and `file_ignore_patterns` in `telescope.lua` (Telescope's
  own search) don't share config - Telescope never reads `wildignore`.
  Not wrong, just something to remember to update in both places if you
  add another directory to ignore.
