<#
.SYNOPSIS
    Bootstraps a native Windows install of this Neovim config on a fresh machine.

.DESCRIPTION
    Installs every tool listed in the README's "Installing on native Windows"
    section via winget (skipping anything already present, since some of
    these - git, curl, ripgrep, fnm, tree-sitter CLI, python - may already
    be on the target machine and some may not). If an existing nvim on PATH
    is older than this config requires, it prompts to upgrade via winget and
    aborts if you decline.
    Node is managed by fnm rather than a system-wide install: it installs
    the latest LTS Node and points fnm's "nvim" alias at it (lua/config/node.lua
    pins Neovim to that alias, so projects needing an older Node don't break
    Mason's LSP servers), makes it fnm's default if there isn't one yet, and
    adds fnm's --use-on-cd hook to your PowerShell $PROFILE so projects with
    an .nvmrc/.node-version switch Node automatically. If the pinned Node is
    too old for Mason's LSP servers, it aborts.
    Installs and activates a Nerd Font (JetBrainsMono NF) for terminal icons,
    and installs Neovide (a standalone GUI client for this config), skipping
    each if already installed.
    It clones this repo into %LOCALAPPDATA%\nvim if it isn't already there,
    fixes the sqlformat.exe PATH gap, and finishes by running Neovim
    headlessly to bootstrap lazy.nvim, sync plugins, and install the four
    Mason LSP servers this config enables.

    Safe to re-run - every step checks for an existing install first.

.PARAMETER RepoUrl
    Git URL to clone when the config isn't already checked out.

.PARAMETER ConfigPath
    Target Neovim config directory. Defaults to %LOCALAPPDATA%\nvim, which is
    where Neovim looks natively on Windows (the equivalent of ~/.config/nvim).

.PARAMETER SkipMason
    Skip installing the Mason LSP servers (lua_ls, ts_ls, jsonls, bashls) at
    the end. Useful if you just want the system tools installed quickly.

.EXAMPLE
    .\Install.ps1
    Full install: system tools, config clone, plugins, LSP servers.

.EXAMPLE
    irm https://raw.githubusercontent.com/trgrote/neovim-config/main/Install.ps1 | iex
    Run directly from GitHub on a brand new machine, before the repo is even
    cloned locally.
#>

[CmdletBinding()]
param(
	[string]$RepoUrl = "https://github.com/trgrote/neovim-config.git",
	[string]$ConfigPath = "$env:LOCALAPPDATA\nvim",
	[switch]$SkipMason
)

function Write-Step($msg) {
	Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Write-Skip($msg) {
	Write-Host "    already present: $msg" -ForegroundColor DarkGray
}

function Test-Winget {
	if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
		throw "winget was not found. Install 'App Installer' from the Microsoft Store, then re-run this script."
	}
}

$MinNvimVersion = [version]"0.12.0"

function Test-NvimVersion {
	if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
		return
	}
	$firstLine = (nvim --version | Select-Object -First 1)
	if ($firstLine -match "NVIM v(\d+\.\d+\.\d+)") {
		$current = [version]$Matches[1]
		if ($current -lt $MinNvimVersion) {
			Write-Warning "nvim v$current is on PATH, but this config requires >= v$MinNvimVersion - nvim-treesitter's main branch will fail on older Neovim (attempt to call method 'range' (a nil value))."
			$reply = Read-Host "Upgrade Neovim now via winget? [y/N]"
			if ($reply -notmatch '^[Yy]') {
				throw "Aborting: Neovim must be >= v$MinNvimVersion for this config to work."
			}

			Write-Step "Upgrading Neovim"
			winget upgrade -e --id Neovim.Neovim --accept-source-agreements --accept-package-agreements
			if ($LASTEXITCODE -ne 0) {
				# winget refuses to "upgrade" a package it doesn't consider
				# already installed under its own tracking (e.g. a manual
				# install) - fall back to a plain install in that case.
				winget install -e --id Neovim.Neovim --accept-source-agreements --accept-package-agreements
				if ($LASTEXITCODE -ne 0) {
					throw "winget upgrade/install for Neovim.Neovim failed (exit code $LASTEXITCODE) - upgrade nvim manually to >= v$MinNvimVersion and re-run this script."
				}
			}
			Update-SessionPath
		}
	}
}

$MinNodeVersion = [version]"18.0.0"

function Get-FnmDir {
	if ($env:FNM_DIR) {
		return $env:FNM_DIR
	}
	return Join-Path $env:APPDATA "fnm"
}

# The Node that lua/config/node.lua pins Neovim to, regardless of which Node
# the shell / project has active.
$NvimNodeDir = Join-Path (Get-FnmDir) "aliases\nvim"

function Install-FnmNode {
	if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
		Write-Warning "fnm isn't on PATH yet - skipping the pinned Node install. Restart your shell and re-run this script."
		return
	}

	if (Test-Path "$NvimNodeDir\node.exe") {
		Write-Skip "Neovim's pinned Node (fnm alias 'nvim')"
	} else {
		Write-Step "Installing the latest LTS Node via fnm and aliasing it as 'nvim'"
		fnm install --lts
		$ltsVersion = (fnm exec --using=lts-latest -- node --version).Trim()
		fnm alias $ltsVersion nvim
	}

	if (Test-Path (Join-Path (Get-FnmDir) "aliases\default")) {
		Write-Skip "fnm default Node"
	} else {
		$nvimVersion = (& "$NvimNodeDir\node.exe" --version).Trim()
		Write-Step "Setting fnm's default Node to $nvimVersion"
		fnm default $nvimVersion
	}
}

function Test-NodeVersion {
	if (-not (Test-Path "$NvimNodeDir\node.exe")) {
		return
	}
	$raw = (& "$NvimNodeDir\node.exe" --version).Trim()
	if ($raw -match "^v(\d+\.\d+\.\d+)") {
		$current = [version]$Matches[1]
		if ($current -lt $MinNodeVersion) {
			throw "fnm's 'nvim' alias points at node v$current, but this config requires >= v$MinNodeVersion for Mason's LSP servers to run correctly (bash-language-server in particular crashes on startup with 'SyntaxError: Unexpected token .' on older Node). Re-point it with 'fnm install --lts; fnm alias <version> nvim', then re-run this script."
		}
	}
}

function Add-FnmProfileHook {
	$hook = "fnm env --use-on-cd --version-file-strategy=recursive --resolve-engines --shell powershell | Out-String | Invoke-Expression"

	if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -Pattern "fnm env" -SimpleMatch -Quiet)) {
		Write-Skip "fnm shell hook (already in $PROFILE)"
		return
	}

	Write-Step "Adding fnm's --use-on-cd hook to $PROFILE"
	$profileDir = Split-Path $PROFILE -Parent
	if (-not (Test-Path $profileDir)) {
		New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
	}
	Add-Content -Path $PROFILE -Value "`n# Switch Node per directory from .nvmrc/.node-version/package.json engines`n$hook" -Encoding utf8
}

function Install-WingetPackage {
	param(
		[Parameter(Mandatory)][string]$Id,
		[Parameter(Mandatory)][string]$CheckCommand,
		[string]$Label = $Id
	)

	if (Get-Command $CheckCommand -ErrorAction SilentlyContinue) {
		Write-Skip "$Label ($CheckCommand already on PATH)"
		return
	}

	Write-Step "Installing $Label ($Id)"
	winget install -e --id $Id --accept-source-agreements --accept-package-agreements
	if ($LASTEXITCODE -ne 0) {
		Write-Warning "winget install for $Id exited with code $LASTEXITCODE - continuing, but check the output above."
	}
}

$NerdFontFamily = "JetBrainsMono NF"
$NerdFontWingetId = "DEVCOM.JetBrainsMonoNerdFont"

function Test-FontInstalled {
	param([Parameter(Mandatory)][string]$FamilyName)
	Add-Type -AssemblyName System.Drawing
	$installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
	return $installed -contains $FamilyName
}

function Set-WindowsTerminalFont {
	param([Parameter(Mandatory)][string]$FamilyName)

	$settingsPaths = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal*" -ErrorAction SilentlyContinue |
		ForEach-Object { Join-Path $_.FullName "LocalState\settings.json" } |
		Where-Object { Test-Path $_ }

	if (-not $settingsPaths) {
		Write-Warning "Could not find Windows Terminal's settings.json - set the font yourself (Settings > Defaults > Appearance > Font face > $FamilyName)."
		return
	}

	foreach ($path in $settingsPaths) {
		try {
			$settings = Get-Content $path -Raw | ConvertFrom-Json
			if (-not $settings.profiles) {
				continue
			}
			if (-not $settings.profiles.defaults) {
				$settings.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value ([PSCustomObject]@{})
			}
			if (-not $settings.profiles.defaults.font) {
				$settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value ([PSCustomObject]@{ face = $FamilyName })
			} else {
				$settings.profiles.defaults.font.face = $FamilyName
			}
			$settings | ConvertTo-Json -Depth 100 | Set-Content -Path $path -Encoding utf8
			Write-Step "Set Windows Terminal's default font to $FamilyName ($path)"
		} catch {
			Write-Warning "Failed to update Windows Terminal settings at $path - set the font yourself. $_"
		}
	}
}

function Install-NerdFont {
	if (Test-FontInstalled -FamilyName $NerdFontFamily) {
		Write-Skip "$NerdFontFamily (already installed)"
		return
	}

	Write-Step "Installing $NerdFontFamily ($NerdFontWingetId)"
	winget install -e --id $NerdFontWingetId --accept-source-agreements --accept-package-agreements
	if ($LASTEXITCODE -ne 0) {
		Write-Warning "winget install for $NerdFontWingetId exited with code $LASTEXITCODE - continuing, but check the output above."
		return
	}

	Set-WindowsTerminalFont -FamilyName $NerdFontFamily
}

function Update-SessionPath {
	$machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
	$user = [System.Environment]::GetEnvironmentVariable("Path", "User")
	$env:Path = "$machine;$user"
}

function Add-UserPathEntry {
	param([Parameter(Mandatory)][string]$Directory)

	$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
	$entries = $userPath -split ";" | Where-Object { $_ -ne "" }
	if ($entries -contains $Directory) {
		return
	}
	Write-Step "Adding $Directory to your user PATH"
	$newPath = ($entries + $Directory) -join ";"
	[System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
	Update-SessionPath
}

# --- 1. System tools ---------------------------------------------------

# Pick up PATH entries from any earlier run of this script in the same
# session (or anything else that touched machine/user PATH since this shell
# started) before checking what's already installed.
Update-SessionPath

Test-Winget

# curl ships natively with Windows 10 2004+/Windows 11 (System32\curl.exe) -
# there's no winget package for it, just confirm it's actually there.
if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
	Write-Skip "curl (native Windows curl.exe)"
} else {
	Write-Warning "curl.exe not found. It ships natively on Windows 10 2004+/Windows 11 - if it's missing, check for Windows updates."
}

Install-WingetPackage -Id "Neovim.Neovim"                     -CheckCommand "nvim"  -Label "Neovim"
Test-NvimVersion
Install-WingetPackage -Id "Git.Git"                            -CheckCommand "git"   -Label "git"
Install-WingetPackage -Id "BurntSushi.ripgrep.MSVC"            -CheckCommand "rg"    -Label "ripgrep"
Install-WingetPackage -Id "Schniz.fnm"                         -CheckCommand "fnm"   -Label "fnm (Node version manager)"
Update-SessionPath
Install-FnmNode
Test-NodeVersion
Add-FnmProfileHook
Install-WingetPackage -Id "tree-sitter.tree-sitter-cli"        -CheckCommand "tree-sitter" -Label "tree-sitter CLI"
Install-WingetPackage -Id "Python.Python.3.13"                 -CheckCommand "python" -Label "Python 3"

# gcc/make: both required (telescope-fzf-native's build step literally runs
# `make`), see README "Installing on native Windows" for why it's two
# separate packages rather than one all-in-one toolchain.
Install-WingetPackage -Id "BrechtSanders.WinLibs.POSIX.UCRT"   -CheckCommand "gcc"   -Label "WinLibs mingw-w64 (gcc)"
Install-WingetPackage -Id "ezwinports.make"                    -CheckCommand "make"  -Label "GNU make"

Install-WingetPackage -Id "Neovide.Neovide" -CheckCommand "neovide" -Label "Neovide"

Update-SessionPath

# --- 2. Nerd Font (for file/git icons in nvim-web-devicons, lualine, etc.) ---

Install-NerdFont

# --- 3. sqlparse + its PATH gotcha -------------------------------------

Write-Step "Installing sqlparse (for the <leader>sql mapping)"
python -m pip install --user --quiet sqlparse

if (Get-Command sqlformat -ErrorAction SilentlyContinue) {
	Write-Skip "sqlformat (already on PATH)"
} else {
	$siteLocation = (python -m pip show sqlparse | Select-String "^Location:").ToString() -replace "^Location:\s*", ""
	if ($siteLocation) {
		$scriptsDir = Join-Path (Split-Path $siteLocation -Parent) "Scripts"
		if (Test-Path "$scriptsDir\sqlformat.exe") {
			Add-UserPathEntry -Directory $scriptsDir
		} else {
			Write-Warning "Installed sqlparse but couldn't find sqlformat.exe under $scriptsDir - the <leader>sql mapping may not work until you add its Scripts dir to PATH by hand."
		}
	} else {
		Write-Warning "Could not determine sqlparse's install location - skipping PATH fix for sqlformat.exe."
	}
}

# --- 4. Clone the config -------------------------------------------------

$resolvedConfigPath = Resolve-Path -ErrorAction SilentlyContinue $ConfigPath
$alreadyInPlace = $PSScriptRoot -and $resolvedConfigPath -and ((Resolve-Path $PSScriptRoot).Path -eq $resolvedConfigPath.Path)

if ($alreadyInPlace) {
	Write-Skip "config repo (script is already running from $ConfigPath)"
} elseif (Test-Path $ConfigPath) {
	Write-Skip "config repo ($ConfigPath already exists)"
} else {
	Write-Step "Cloning $RepoUrl into $ConfigPath"
	git clone $RepoUrl $ConfigPath
}

# --- 5. Bootstrap plugins + LSP servers -----------------------------------

Write-Step "Bootstrapping lazy.nvim and syncing plugins (this compiles treesitter parsers and telescope-fzf-native - may take a minute)"
nvim --headless "+Lazy! sync" +qa

if (-not $SkipMason) {
	Write-Step "Installing Mason LSP servers (lua_ls, ts_ls, jsonls, bashls) if not already installed"
	# `:MasonInstall` reinstalls unconditionally even when a package is
	# already present, which is why a re-run of this script always redownloads
	# every server. Query mason-registry directly instead and only install
	# packages that aren't already installed.
	$masonScript = @'
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
'@
	$masonScriptPath = Join-Path $env:TEMP "mason-install-if-missing.lua"
	Set-Content -Path $masonScriptPath -Value $masonScript -Encoding utf8
	# Use a normal headless invocation (not `nvim -l`, which skips loading the
	# user's config/plugins) so mason-registry is available, then luafile the
	# script in on top of it.
	nvim --headless -c "luafile $masonScriptPath" -c "sleep 30000m"
	Remove-Item -Path $masonScriptPath -ErrorAction SilentlyContinue
}

Write-Step "Done. Restart your shell so PATH changes take effect, then run 'nvim' and ':checkhealth' to confirm everything's green."
