<#
.SYNOPSIS
    Bootstraps a native Windows install of this Neovim config on a fresh machine.

.DESCRIPTION
    Installs every tool listed in the README's "Installing on native Windows"
    section via winget (skipping anything already present, since some of
    these - git, curl, ripgrep, node, tree-sitter CLI, python - may already
    be on the target machine and some may not). If an existing nvim on PATH
    is older than this config requires, it prompts to upgrade via winget and
    aborts if you decline; if an existing node is too old for Mason's LSP
    servers, it aborts outright (no in-place Node upgrade path via winget).
    Prompts to install and activate a Nerd Font (JetBrainsMono NF) for
    terminal icons, skipping the prompt entirely if it's already installed.
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

function Test-NodeVersion {
	if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
		return
	}
	$raw = (node --version).Trim()
	if ($raw -match "^v(\d+\.\d+\.\d+)") {
		$current = [version]$Matches[1]
		if ($current -lt $MinNodeVersion) {
			throw "node v$current is on PATH, but this config requires >= v$MinNodeVersion for Mason's LSP servers to run correctly (bash-language-server in particular crashes on startup with 'SyntaxError: Unexpected token .' on older Node). Upgrade Node yourself (e.g. 'winget upgrade OpenJS.NodeJS.LTS', or via nvm-windows) so 'node' on PATH resolves to >= v$MinNodeVersion, then re-run this script."
		}
	}
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

	$reply = Read-Host "Install and activate '$NerdFontFamily' for terminal icons (nvim-web-devicons, lualine, etc.)? [Y/n]"
	if ($reply -match '^[Nn]') {
		Write-Warning "Skipping Nerd Font install - file/git icons in nvim will render as boxes/question marks until a Nerd Font is set as your terminal's font."
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
Install-WingetPackage -Id "OpenJS.NodeJS.LTS"                  -CheckCommand "node"  -Label "Node.js"
Test-NodeVersion
Install-WingetPackage -Id "tree-sitter.tree-sitter-cli"        -CheckCommand "tree-sitter" -Label "tree-sitter CLI"
Install-WingetPackage -Id "Python.Python.3.13"                 -CheckCommand "python" -Label "Python 3"

# gcc/make: both required (telescope-fzf-native's build step literally runs
# `make`), see README "Installing on native Windows" for why it's two
# separate packages rather than one all-in-one toolchain.
Install-WingetPackage -Id "BrechtSanders.WinLibs.POSIX.UCRT"   -CheckCommand "gcc"   -Label "WinLibs mingw-w64 (gcc)"
Install-WingetPackage -Id "ezwinports.make"                    -CheckCommand "make"  -Label "GNU make"

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
	Write-Step "Installing Mason LSP servers (lua_ls, ts_ls, jsonls, bashls)"
	nvim --headless -c "MasonInstall lua-language-server typescript-language-server json-lsp bash-language-server" -c "sleep 30000m" -c "qa!"
}

Write-Step "Done. Restart your shell so PATH changes take effect, then run 'nvim' and ':checkhealth' to confirm everything's green."
