# Neovim config

Personal Neovim configuration, written in Lua, using
[lazy.nvim](https://github.com/folke/lazy.nvim) for plugins. Ported from an
older vim-plug based `~/.vim` config, with the vimwiki/ticket/diary
automation rewritten from scratch in Lua (see `lua/vimwiki/`).

## Requirements

- **Neovim >= 0.12** (developed and tested on 0.12.5). Check with `nvim --version`.
  `nvim-treesitter`'s `main` branch (see below) relies on core treesitter
  APIs that don't exist / don't work the same on older Neovim - on
  anything below 0.12 you'll see `attempt to call method 'range' (a nil
  value)` errors instead of highlighting.
- **git** - lazy.nvim clones plugins with it.
- **curl** - used by lazy.nvim's bootstrap and by `:NewJiraTicket`.
- **A C compiler + make**, needed to compile treesitter parsers,
  `telescope-fzf-native`'s native sorter, and `vim-perl`'s supplementary
  syntax files. (`base-devel` on Arch, Xcode Command Line Tools on
  macOS.) Without this the config still loads and works, just without
  treesitter highlighting/textobjects and with a slower (pure-Lua)
  telescope sorter.
- **The `tree-sitter` CLI**, needed alongside the C compiler above -
  `nvim-treesitter` is pinned to its `main` branch (`lua/plugins/treesitter.lua`),
  which compiles parsers via `tree-sitter build` instead of shelling out to
  the compiler directly like the old branch did. Without it on `PATH`,
  parser installs fail with `ENOENT: no such file or directory (cmd):
  'tree-sitter'` and you get the same no-highlighting symptom as missing
  a C compiler. Install with `npm install -g tree-sitter-cli`, `cargo
  install tree-sitter-cli`, or a prebuilt binary from
  <https://github.com/tree-sitter/tree-sitter/releases> if you don't want
  the npm/cargo global-install path.
- **ripgrep** (`rg`), used by Telescope's live grep and file search.
- **node/npm >= 18**, needed by Mason to install the npm-based LSP servers
  (`ts_ls`, `jsonls`, `bashls`). Older Node breaks these at runtime, not
  install time - `bash-language-server` in particular crash-loops with
  `SyntaxError: Unexpected token .` on Node < 14 (it uses optional
  chaining internally), and the install scripts below refuse to continue
  if `node` on `PATH` is under the minimum.

  **On WSL specifically:** if Node.js is only installed on the Windows
  side (e.g. via nvm-windows), `npm` on your WSL `PATH` can resolve to a
  Windows executable (something like `/mnt/c/.../npm`) that can't
  actually run from WSL - Mason installs then fail on every Neovim
  startup with `[mason-lspconfig.nvim] failed to install ...` /
  `npm failed with exit code 127 ... exec: node: not found` (see
  `:MasonLog` for the full error). Fix: install Node.js natively inside
  WSL with the command below, then restart your shell. Check with
  `which node` / `which npm` afterward - both should resolve under
  `/usr/bin` (or similar), not `/mnt/c/...`.

- **python3** with `pip install sqlparse` - only needed for the
  `<leader>json` / `<leader>sql` visual-mode formatting mappings.

On Debian/Ubuntu (incl. WSL):

```sh
sudo apt install build-essential ripgrep nodejs npm python3 python3-pip
npm install -g tree-sitter-cli
pip install sqlparse
```

None of the above are hard requirements to get *a* working config - only
to get every feature working. lazy.nvim and the plugin configs degrade
gracefully when a tool is missing.

### Installing on Debian/Ubuntu

#### Quick install: `install.sh`

[`install.sh`](./install.sh) installs Neovim (via the
`neovim-ppa/unstable` PPA, since Ubuntu/Debian's own `apt` package is
often years behind the `>= 0.12` this config requires), git, curl,
ripgrep, node/npm, the `tree-sitter` CLI (via `npm install -g
tree-sitter-cli`), a C compiler (`build-essential`), and
python3/sqlparse via `apt` - skipping anything already present, since a
fresh machine won't have any of it and an existing dev box might have
some of it already. If `nvim` is already on `PATH` but older than 0.12,
the script warns you to upgrade rather than silently leaving it in
place. It clones this repo into `~/.config/nvim` if it isn't already
there, and finishes by running Neovim headlessly to sync plugins and
install the Mason LSP servers. It's safe to re-run - every step checks
for an existing install first and skips it. If something doesn't work,
the script itself is the documentation - it's short and each step is
commented.

If you already have this repo cloned locally, run it from inside the
clone:

```sh
cd ~/.config/nvim
./install.sh
```

On a brand new machine that doesn't have the repo yet, run it straight
from GitHub - it'll clone the repo itself as one of its steps:

```sh
curl -fsSL https://raw.githubusercontent.com/trgrote/neovim-config/main/install.sh | bash
```

Pass `--skip-mason` to skip installing the LSP servers (`lua_ls`,
`ts_ls`, `jsonls`, `bashls`) if you just want the system tools and
plugins for now, and set the `CONFIG_PATH`/`REPO_URL` environment
variables to override where it clones to or from, e.g.:

```sh
CONFIG_PATH=/tmp/nvim-test ./install.sh
```

None of the tools it installs beyond Neovim itself are hard requirements
to get *a* working config, same caveat as above - lazy.nvim and the
plugin configs degrade gracefully when a tool is missing, just with
reduced functionality (no treesitter highlighting/textobjects, a slower
Telescope sorter, some LSP servers unavailable, etc).

### Installing on native Windows

Everything above works on native Windows too (not just WSL), but none of
it ships with Windows and the exact package names/PATH setup differ
enough from the Unix case to be worth spelling out separately. All
commands below are PowerShell, and all installs use
[winget](https://learn.microsoft.com/windows/package-manager/winget/)
(built into Windows 10 2004+/Windows 11).

#### Quick install: `Install.ps1`

[`Install.ps1`](./Install.ps1) installs Neovim, git, ripgrep, node, the
`tree-sitter` CLI, a C compiler + make (via WinLibs + ezwinports, since
Windows has no single "build-essential" equivalent and
`telescope-fzf-native`'s build step is hardcoded to run `make`), and
python/sqlparse via winget - skipping anything already present, since a
fresh machine won't have any of it and an existing dev box might have
some of it already. If `nvim` is already on `PATH` but older than the
`>= 0.12` this config requires, the script warns you to upgrade rather
than silently leaving it in place. It also fixes the `sqlformat.exe`
PATH gap (`pip install --user` puts it somewhere not on `PATH` by
default, which silently breaks the `<leader>sql` mapping), clones this
repo into `%LOCALAPPDATA%\nvim` (Windows' equivalent of `~/.config/nvim`)
if it isn't already there, and finishes by running Neovim headlessly to
sync plugins and install the Mason LSP servers. It's safe to re-run -
every step checks for an existing install first and skips it. If
something doesn't work, the script itself is the documentation - it's
short and each step is commented.

If you already have this repo cloned locally, run it from inside the
clone:

```powershell
cd "$env:LOCALAPPDATA\nvim"
.\Install.ps1
```

On a brand new machine that doesn't have the repo yet, run it straight
from GitHub - it'll clone the repo itself as one of its steps:

```powershell
irm https://raw.githubusercontent.com/trgrote/neovim-config/main/Install.ps1 | iex
```

Pass `-SkipMason` to skip installing the LSP servers (`lua_ls`, `ts_ls`,
`jsonls`, `bashls`) if you just want the system tools and plugins for
now, and `-ConfigPath`/`-RepoUrl` to override where it clones to or from.
**Restart your shell after it finishes** so the PATH changes (Neovim,
gcc/make, sqlformat) take effect in new sessions - the script updates
machine/user PATH via the registry, which only new processes pick up.

None of the tools it installs beyond Neovim itself are hard requirements
to get *a* working config, same caveat as the Unix case above - lazy.nvim
and the plugin configs degrade gracefully when a tool is missing, just
with reduced functionality (no treesitter highlighting/textobjects, a
slower Telescope sorter, some LSP servers unavailable, etc).

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

## Session management

Backed by [`rmagatti/auto-session`](https://github.com/rmagatti/auto-session)
(`lua/plugins/session.lua`), with the Telescope picker it ships
(`session_lens`) auto-detected since Telescope is already installed.

**Fully opt-in until you touch a session.** `auto_save`/`auto_restore`
are both disabled, so quitting never silently saves a session and
launching Neovim never silently restores one you didn't ask for.
Nothing happens until you explicitly save or restore one - see below.

**Create a named session:**

```vim
:AutoSession save nvim
```

run from inside `~/.config/nvim` (or whatever directory you want that
name tied to). `:AutoSession save grumbo` from `~/source/grumbo-web`,
etc.

**Once you've saved or restored a session, autosave turns on for the
rest of that run** (but only for that one, not globally) - so further
changes, like opening another file, get captured automatically on quit
into that same named session. If you don't want that for a particular
run, `:AutoSession disable` turns autosave back off until you save or
restore again.

**Find / switch to another session**, fuzzy-searchable by name or path,
without restarting Neovim:

```vim
:AutoSession search
```

or press `<Leader>p`. This opens a Telescope picker listing every saved
session (both auto-named-by-path ones and anything you explicitly
named) - type to fuzzy-filter, `<CR>` to switch. Switching changes `cwd`
and swaps in that session's buffers/windows in the same Neovim process.
From inside the picker: `<C-d>` deletes a session, `<C-s>` swaps to the
alternate (previous) session, `<C-y>` copies one.

Other useful commands: `:AutoSession restore <name>` (switch without the
picker, if you know the name), `:AutoSession delete <name>`,
`:AutoSession toggle` (pause/resume autosave for the current session).

## Autocomplete

Backed by [`saghen/blink.cmp`](https://github.com/saghen/blink.cmp)
(`lua/plugins/completion.lua`), sourcing from the attached LSP server,
file paths, and the current buffer's words.

**It's manual, not automatic.** The menu doesn't pop up while you type -
`completion.trigger.show_on_keyword`/`show_on_trigger_character` are
both disabled. You ask for it:

- **`<C-space>`** - opens the menu. The top match is pre-selected
  automatically (`preselect = true`, blink's default), so you can accept
  immediately without moving the selection first.
- **`<Up>` / `<Down>`** - move the selection.
- **`<C-y>`** - accept whichever item is currently selected.
- **`<C-e>`** - cancel/dismiss the menu without accepting anything.

**`<CR>` (Enter) does *not* accept a completion** with this keymap
preset ("default") - it just inserts a newline as usual, menu open or
not. This trips people up coming from editors where Enter accepts. If
you'd rather have Enter accept (closer to VSCode), swap
`keymap = { preset = "default" }` to `preset = "enter"` in
`lua/plugins/completion.lua` - that preset adds `<CR>` = accept and
changes nothing else.

Other keys from the same preset: `<C-k>` toggles function-signature
help; `<C-b>` / `<C-f>` scroll the documentation preview pane; `<Tab>` /
`<S-Tab>` jump between snippet placeholders *after* accepting a snippet
completion (not for navigating the menu itself).

Accepting a completion is merged into the same undo block as the rest
of your insert-mode session (`completion.accept.create_undo_point =
false`), so a single `u` after leaving insert mode undoes the whole
insertion, completion included - not just back to the moment you
accepted it.

## C# / .NET

Full .NET development - LSP, debugger, test UI - lives in
`lua/plugins/dotnet.lua`. Three plugins, each doing one job:

| Plugin | Job |
| ------ | --- |
| [`seblyng/roslyn.nvim`](https://github.com/seblyng/roslyn.nvim) | The LSP, and nothing else. Wraps nvim-lspconfig's `roslyn_ls` and adds what lspconfig deliberately won't: finding *every* solution in a tree and letting you switch between them with `:Roslyn target`. |
| [`GustavEikaas/easy-dotnet.nvim`](https://github.com/GustavEikaas/easy-dotnet.nvim) | `:Dotnet ...` - build, run, watch, test, NuGet packages, solution selection - plus a Rider-style test runner tree and a neotest adapter. |
| [`mfussenegger/nvim-dap`](https://github.com/mfussenegger/nvim-dap) + `nvim-dap-ui` | Debugging, driven by [netcoredbg](https://github.com/Samsung/netcoredbg). |

**OmniSharp isn't used.** Microsoft's own Roslyn language server (the same
engine behind Visual Studio and the VS Code C# extension) superseded it,
and it's what every current Neovim C# setup has moved to.

easy-dotnet ships its own bundled Roslyn support, which is switched off
here (`lsp = { enabled = false }`) so roslyn.nvim solely owns the LSP -
running both attaches two C# clients and every diagnostic shows up twice.

### Dependencies: `Install-Dotnet.ps1`

[`Install-Dotnet.ps1`](./Install-Dotnet.ps1) is the .NET counterpart to
`Install.ps1`. It installs the .NET SDK (winget), the
`roslyn-language-server` and `EasyDotnet` dotnet global tools,
`netcoredbg` via Mason, `vscode-langservers-extracted` (npm, the HTML
half of Razor files), and `dotnet-ef`. Safe to re-run: global tools get
updated rather than reinstalled, and Mason packages already present are
left alone.

```powershell
cd "$env:LOCALAPPDATA\nvim"
.\Install-Dotnet.ps1
```

**Run it unelevated.** Every step is per-user - global tools go to
`%USERPROFILE%\.dotnet\tools`, Mason writes under `%LOCALAPPDATA%`, and
only your *user* PATH is touched. Running it as admin once the SDK
exists would put the tools in the Administrator's profile where Neovim
(unelevated) can't find them, so the script warns and asks before
continuing. The single exception is installing the SDK itself, which
winget puts under `C:\Program Files`; if `dotnet` is missing the script
checks for elevation up front and stops with instructions rather than
failing halfway through.

`roslyn-language-server` comes from the Azure DevOps `vs-impl` feed, not
nuget.org - nuget.org only gets occasional drops, far enough behind that
roslyn.nvim can reject the version as too old.

Flags: `-SkipMason` (skip netcoredbg, i.e. no debugger - useful before
Neovim's plugins are bootstrapped), `-SkipEf` (skip the Entity Framework
CLI), `-SdkWingetId` (pin a different SDK major version).

### Keymaps

`<leader>n` for .NET, `<leader>d` for the debugger:

| Key | Does |
| --- | ---- |
| `<leader>nb` / `<leader>nB` | build project / solution |
| `<leader>nr` / `<leader>nR` | run (pick a project) / re-run last picked |
| `<leader>nd` | debug |
| `<leader>nw` / `<leader>nx` | watch / clean |
| `<leader>nt` | easy-dotnet test runner (the tree UI) |
| `<leader>nS` | neotest summary |
| `<leader>nc` / `<leader>nf` | run nearest test / all tests in file |
| `<leader>no` | test output |
| `<leader>np` / `<leader>nP` | add NuGet package / list outdated |
| `<leader>ns` / `<leader>nn` | select solution / new project or file |
| `<F5>` or `<leader>dc` | start/continue debugging |
| `<F10>` / `<F11>` / `<S-F11>` | step over / into / out |
| `<leader>dn` / `<leader>di` / `<leader>do` | same three steps, for terminals that swallow `<S-F11>` |
| `<leader>db` / `<leader>dB` | toggle breakpoint / conditional breakpoint |
| `<leader>du` / `<leader>dr` | toggle dap-ui / REPL |
| `<leader>dh` | hover the value under the cursor (also visual mode) |
| `<leader>dl` / `<leader>dq` | re-run last session / terminate |

The dap-ui panes open and close with the session automatically, so `<F5>`
is usually all you need.

**`<F5>` doesn't debug tests** - it launches a project, and a test project
has no entry point. Debug a test from the test runner's `<leader>d`
instead, which starts the test host with netcoredbg attached.

### Test runner window

These are buffer-local to the runner (`filetype=easy-dotnet`), so they
don't shadow anything - `<leader>d` is still the debug prefix in a normal
`.cs` buffer.

| Key | Does |
| --- | ---- |
| `o` | toggle expand |
| `E` / `W` | expand / collapse all children |
| `]f` / `[f` | next / previous failing test |
| `<leader>r` | run the node under the cursor (a test, class, or whole project) |
| `<leader>R` | run every test in the solution |
| `<leader>d` | debug the node under the cursor |
| `<leader>p` | peek results |
| `<leader>g` | go to source |
| `<leader>e` | show build errors |
| `<C-r>` | invalidate the node, forcing re-discovery |
| `<C-c>` | cancel the active operation |
| `q` or `<Esc>` | close the runner |

### Notes

- **neotest depends on easy-dotnet's runner.** The neotest adapter reads
  the test runner's discovery state rather than parsing files itself, so
  until the runner has started there are no tests to show.
  `test_runner.auto_start_testrunner = true` starts it silently in the
  background once a solution loads, which is why `<leader>nS` works
  without visiting `<leader>nt` first. If neotest ever looks empty, open
  the runner once.
- **Open a file inside the solution, not the solution file.** Roslyn's
  root detection walks out from the buffer's path looking for
  `.sln`/`.slnx`/`.csproj`; `broad_search = true` also lets it walk *down*
  into subdirectories, so a repo whose solution lives below the cwd still
  attaches.
- `.slnx` (the XML solution format that `dotnet new sln` defaults to as
  of .NET 10) is supported by both roslyn.nvim and easy-dotnet.
- Telescope no longer ignores `.csproj`/`.sln` - it did, from this
  config's Unity days - and now ignores `bin/` and `obj/` instead.
- Health checks: `:checkhealth easy-dotnet` for the .NET side,
  `:checkhealth lsp` / `:LspInfo` to confirm `roslyn` attached.

### Playground project

`D:\Code\NvimDotnetPlayground` is a scratch solution for exercising all
of the above - a console app plus an xUnit project with 11 passing tests
and 1 deliberately skipped one, including `[Theory]` cases so the runner
tree has child nodes to expand. See its own README.

## Wiki data

This repo is only the *config*. The actual wiki content lives separately
at `~/vimwiki/mwl/` (configured in `lua/plugins/wiki.lua`) and isn't part
of this repository - back it up / sync it independently (e.g. its own git
repo, or a sync tool) when moving to a new machine.

## Layout

```
init.lua              entry point
lua/config/            options, keymaps, autocmds, lazy.nvim bootstrap
lua/util/               small standalone helpers (buffer close/wipe)
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

## Deviations from a literal port

The port initially tried to preserve the old `.vim` config's behavior as
closely as possible. An audit afterward found several of those choices
were redundant or actively working against either Neovim's own
(different-from-Vim) defaults or a plugin that's now installed - all of
these have since been fixed. Documented here so it's clear *why* the
config no longer matches the original line-for-line in these spots.

- **Session management went through three iterations before landing on
  `rmagatti/auto-session`** (`lua/plugins/session.lua`): first a
  hand-rolled `lua/util/sessions.lua` wrapper around
  `:mksession`/`:source`, then `mini.sessions` (part of `mini.nvim`,
  which was also providing an unused `mini.bracketed` at the time - the
  whole plugin was dropped rather than keep it installed for one
  undecided module), then this. See the "Session management" section
  below for how to use it day-to-day.

- **The statusline format string was deleted, not overridden.**
  `lualine.nvim` (which replaced vim-airline) takes over
  `'statusline'`/`'laststatus'` entirely once it loads - confirmed by
  direct inspection: `laststatus` ends up `3` and `'statusline'` gets
  overwritten to lualine's own render string regardless of what
  `vim.opt.statusline` was set to. The dead `%F%m%r%h%w [FORMAT=...]...`
  format string is gone from `lua/config/options.lua`. **Use today:**
  the statusline's actual content/format is controlled by the `sections`
  table in `lua/plugins/ui.lua`.

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

- **Telescope's `<c-p>` now auto-detects the project root,** matching
  what `ctrlp_working_path_mode = 'ra'` did in the original. It was
  missing from the initial port entirely - a genuine gap, not an
  intentional change. Fixed in `lua/plugins/telescope.lua` using
  `vim.fs.root()` (built into Neovim 0.10+) to search upward from the
  current buffer for a `.git` marker, falling back to `:pwd` if none is
  found - no behavior to change on your end, `<c-p>` just works from the
  project root now.

- **Several ported options were deleted as pure no-ops** - they already
  matched Neovim's built-in defaults (which differ from Vim's), so
  porting them from the old `vimrc` accomplished nothing:
  `hidden`, `backspace`, `incsearch`, `hlsearch`, `ruler`, `wrap`,
  `textwidth=0`, `wrapmargin=0`, and `undolevels=1000` are no longer set
  anywhere in `lua/config/options.lua` - Neovim's defaults already
  matched them exactly.

- **`history = 1000` is gone; Neovim's own default (`10000`) is used
  instead.** The original set `1000` because vanilla Vim's default
  history was much smaller; Neovim's own built-in default is already
  `10000`, so the ported value was quietly *shrinking* your command/search
  history rather than matching old behavior.

- **`formatoptions` changed from `"cqt"` to `"cqtj"`.** Neovim's own
  default `formatoptions` is `"tcqj"` - the extra `j` flag (introduced
  after this option's Vim-era defaults were set) strips the comment
  leader automatically when joining commented lines with `J`. The
  ported value was silently dropping that; it's now kept.

- **`lazyredraw` is gone.** It was a real performance aid in Vim's
  synchronous terminal redraw loop (e.g. during macros); Neovim's UI
  renders asynchronously over a decoupled event protocol, where
  `lazyredraw` mostly just risks visual glitches instead of helping. If
  a specific macro ever feels slow, that's worth investigating on its
  own rather than via this global flag.

- **Two separate ignore-pattern lists still exist for two different
  tools** - this one's inherent, not something to fix. `wildignore` in
  `options.lua` (native `:e<Tab>`/`:find` completion) and
  `file_ignore_patterns` in `telescope.lua` (Telescope's own search)
  don't share config - Telescope never reads `wildignore`. Just
  something to remember to update in both places if you add another
  directory to ignore.
