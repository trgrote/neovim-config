<#
.SYNOPSIS
    Bootstraps a native Windows install of this Neovim config on a fresh machine.

.DESCRIPTION
    Installs every tool listed in the README's "Installing on native Windows"
    section via winget (skipping anything already present, since some of
    these - git, curl, ripgrep, node, python - may already be on the target
    machine and some may not), clones this repo into %LOCALAPPDATA%\nvim if
    it isn't already there, fixes the sqlformat.exe PATH gap, and finishes by
    running Neovim headlessly to bootstrap lazy.nvim, sync plugins, and
    install the four Mason LSP servers this config enables.

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
Install-WingetPackage -Id "Git.Git"                            -CheckCommand "git"   -Label "git"
Install-WingetPackage -Id "BurntSushi.ripgrep.MSVC"            -CheckCommand "rg"    -Label "ripgrep"
Install-WingetPackage -Id "OpenJS.NodeJS.LTS"                  -CheckCommand "node"  -Label "Node.js"
Install-WingetPackage -Id "Python.Python.3.13"                 -CheckCommand "python" -Label "Python 3"

# gcc/make: both required (telescope-fzf-native's build step literally runs
# `make`), see README "Installing on native Windows" for why it's two
# separate packages rather than one all-in-one toolchain.
Install-WingetPackage -Id "BrechtSanders.WinLibs.POSIX.UCRT"   -CheckCommand "gcc"   -Label "WinLibs mingw-w64 (gcc)"
Install-WingetPackage -Id "ezwinports.make"                    -CheckCommand "make"  -Label "GNU make"

Update-SessionPath

# --- 2. sqlparse + its PATH gotcha -------------------------------------

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

# --- 3. Clone the config -------------------------------------------------

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

# --- 4. Bootstrap plugins + LSP servers -----------------------------------

Write-Step "Bootstrapping lazy.nvim and syncing plugins (this compiles treesitter parsers and telescope-fzf-native - may take a minute)"
nvim --headless "+Lazy! sync" +qa

if (-not $SkipMason) {
	Write-Step "Installing Mason LSP servers (lua_ls, ts_ls, jsonls, bashls)"
	nvim --headless -c "MasonInstall lua-language-server typescript-language-server json-lsp bash-language-server" -c "sleep 30000m" -c "qa!"
}

Write-Step "Done. Restart your shell so PATH changes take effect, then run 'nvim' and ':checkhealth' to confirm everything's green."
