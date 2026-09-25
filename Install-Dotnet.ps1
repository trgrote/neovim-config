<#
.SYNOPSIS
    Installs the C#/.NET development dependencies this Neovim config expects.

.DESCRIPTION
    Install.ps1 handles the editor itself; this script handles the .NET side of
    it. It installs, skipping anything already present:

      * the .NET SDK (winget, Microsoft.DotNet.SDK.10)
      * roslyn-language-server - the official Roslyn LSP that roslyn.nvim
        drives, as a dotnet global tool. Installed from the Azure DevOps
        vs-impl feed rather than nuget.org, because nuget.org only gets
        occasional drops while roslyn.nvim tracks recent server versions.
      * EasyDotnet - the out-of-process server behind easy-dotnet.nvim's
        :Dotnet commands and test runner, also a dotnet global tool.
      * netcoredbg - the debug adapter nvim-dap talks to, via Mason.
      * vscode-langservers-extracted (npm) - the HTML server easy-dotnet uses
        for the markup half of Razor files. Skipped if npm isn't on PATH.
      * dotnet-ef - EF Core CLI, so the :Dotnet ef ... commands work. Optional,
        skip with -SkipEf.

    Ensures %USERPROFILE%\.dotnet\tools is on your user PATH, since both LSP
    and the easy-dotnet server are resolved from there by name.

    Safe to re-run: global tools are updated rather than reinstalled, and Mason
    packages already installed are left alone.

    Elevation: run this as a normal user. Every step is per-user - dotnet global
    tools go to %USERPROFILE%\.dotnet\tools, npm's global prefix is %APPDATA%\npm,
    Mason writes under %LOCALAPPDATA%, and only your *user* PATH is modified. The
    one exception is installing the .NET SDK itself, which winget puts under
    C:\Program Files and therefore needs elevation; the script checks for that
    up front and stops with instructions rather than failing halfway through.
    If the SDK is already present, admin is never needed.

.PARAMETER SkipMason
    Skip the Mason netcoredbg install (i.e. skip debugger support). Useful when
    Neovim's plugins haven't been bootstrapped yet - run Install.ps1 first.

.PARAMETER SkipEf
    Skip the dotnet-ef global tool. Only needed for Entity Framework projects.

.PARAMETER SdkWingetId
    winget package id for the .NET SDK. Override to pin a different major
    version (e.g. Microsoft.DotNet.SDK.9).

.EXAMPLE
    .\Install-Dotnet.ps1
    Full .NET toolchain install.

.EXAMPLE
    .\Install-Dotnet.ps1 -SkipEf
    Everything except the Entity Framework CLI.
#>

[CmdletBinding()]
param(
	[switch]$SkipMason,
	[switch]$SkipEf,
	[string]$SdkWingetId = "Microsoft.DotNet.SDK.10"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
	Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Write-Skip($msg) {
	Write-Host "    already present: $msg" -ForegroundColor DarkGray
}

function Test-Administrator {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	return (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole(
		[Security.Principal.WindowsBuiltInRole]::Administrator)
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
		Write-Skip "$Directory on user PATH"
		return
	}
	Write-Step "Adding $Directory to your user PATH"
	$newPath = ($entries + $Directory) -join ";"
	[System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
	Update-SessionPath
}

# --- 1. .NET SDK ---------------------------------------------------------

Update-SessionPath

if (Get-Command dotnet -ErrorAction SilentlyContinue) {
	# Running elevated once the SDK exists is actively harmful: the global tools
	# and PATH entry would land in the Administrator's profile, not yours, and
	# Neovim (running unelevated) would never find them.
	if (Test-Administrator) {
		Write-Warning "You're running elevated, but the .NET SDK is already installed so admin isn't needed. The dotnet global tools and PATH entry would be written to the Administrator profile instead of yours, and Neovim wouldn't find them. Re-run this script from a normal (non-elevated) PowerShell."
		$reply = Read-Host "Continue anyway? [y/N]"
		if ($reply -notmatch '^[Yy]') {
			throw "Aborting: re-run from a non-elevated shell."
		}
	}

	$sdks = (dotnet --list-sdks) -join "`n"
	Write-Skip "dotnet SDK`n$($sdks -replace '(?m)^', '        ')"
} else {
	if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
		throw "Neither dotnet nor winget was found. Install 'App Installer' from the Microsoft Store (or the .NET SDK from https://dotnet.microsoft.com/download), then re-run."
	}
	# Fail here rather than three minutes in: this is the only step that needs
	# elevation, because winget installs the SDK machine-wide under
	# C:\Program Files. Everything after it is per-user. winget would normally
	# raise its own UAC prompt, but that silently fails under a non-interactive
	# shell or a policy that blocks elevation, leaving a half-done install.
	if (-not (Test-Administrator)) {
		throw @"
The .NET SDK isn't installed, and installing it requires an elevated shell
(winget installs it machine-wide under C:\Program Files).

Either:
  * re-run this script from an Administrator PowerShell, or
  * install the SDK yourself from https://dotnet.microsoft.com/download,
    then re-run this script as a normal user.

No other step in this script needs admin - once 'dotnet' is on PATH you can
run it unelevated.
"@
	}
	Write-Step "Installing the .NET SDK ($SdkWingetId)"
	winget install -e --id $SdkWingetId --accept-source-agreements --accept-package-agreements
	if ($LASTEXITCODE -ne 0) {
		throw "winget install for $SdkWingetId failed (exit code $LASTEXITCODE)."
	}
	Update-SessionPath
	if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
		throw "Installed the SDK but 'dotnet' still isn't on PATH - restart your shell and re-run this script."
	}
}

# Both global tools below install here, and Neovim resolves them by bare name.
Add-UserPathEntry -Directory (Join-Path $env:USERPROFILE ".dotnet\tools")

# --- 2. dotnet global tools ----------------------------------------------

# Feed carrying near-daily roslyn-language-server builds. nuget.org's copy
# lags far enough behind that roslyn.nvim can reject it as too old.
$RoslynFeed = "https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json"

function Install-DotnetTool {
	param(
		[Parameter(Mandatory)][string]$PackageId,
		[string]$Label = $PackageId,
		[string]$Source,
		[switch]$Prerelease
	)

	$installed = (dotnet tool list -g) | Select-String -SimpleMatch -Pattern $PackageId -Quiet

	$verb = if ($installed) { "update" } else { "install" }
	Write-Step "$(if ($installed) { 'Updating' } else { 'Installing' }) $Label (dotnet tool $verb -g $PackageId)"

	$dotnetArgs = @("tool", $verb, "-g", $PackageId)
	if ($Prerelease) { $dotnetArgs += "--prerelease" }
	if ($Source) { $dotnetArgs += @("--source", $Source) }

	& dotnet @dotnetArgs
	if ($LASTEXITCODE -ne 0) {
		# `dotnet tool update` exits non-zero when already at the newest
		# version on some SDKs; treat that as success rather than aborting a
		# re-run of the whole script.
		if ($installed) {
			Write-Warning "dotnet tool update for $PackageId exited with code $LASTEXITCODE - it may already be up to date. Check the output above."
		} else {
			throw "dotnet tool install for $PackageId failed (exit code $LASTEXITCODE)."
		}
	}
}

Install-DotnetTool -PackageId "roslyn-language-server" -Label "Roslyn language server (LSP)" -Source $RoslynFeed -Prerelease
Install-DotnetTool -PackageId "EasyDotnet" -Label "EasyDotnet server (:Dotnet commands, test runner)"

if (-not $SkipEf) {
	Install-DotnetTool -PackageId "dotnet-ef" -Label "Entity Framework Core CLI"
}

Update-SessionPath

# --- 3. Razor's HTML language server (npm) --------------------------------

if (Get-Command npm -ErrorAction SilentlyContinue) {
	if (Get-Command vscode-html-language-server -ErrorAction SilentlyContinue) {
		Write-Skip "vscode-langservers-extracted (vscode-html-language-server on PATH)"
	} else {
		Write-Step "Installing vscode-langservers-extracted (HTML server for Razor files)"
		npm install -g vscode-langservers-extracted
		if ($LASTEXITCODE -ne 0) {
			Write-Warning "npm install -g vscode-langservers-extracted exited with code $LASTEXITCODE - Razor markup completion may not work. C# itself is unaffected."
		}
	}
} else {
	Write-Warning "npm not found - skipping vscode-langservers-extracted. Razor markup (HTML) completion will be unavailable; run Install.ps1 first to get Node.js."
}

# --- 4. netcoredbg via Mason ----------------------------------------------

if ($SkipMason) {
	Write-Step "Skipping Mason netcoredbg install (-SkipMason). Run ':MasonInstall netcoredbg' in nvim to enable debugging."
} elseif (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
	Write-Warning "nvim not found on PATH - skipping netcoredbg. Run Install.ps1 first, then re-run this script (or ':MasonInstall netcoredbg' inside nvim)."
} else {
	Write-Step "Installing netcoredbg via Mason (the debug adapter nvim-dap drives)"
	# `:MasonInstall` redownloads unconditionally even when a package is
	# already present, so query mason-registry directly and no-op if installed.
	# Suppress hit-enter prompts: an unrelated plugin erroring during startup
	# (a treesitter parser compile, say) otherwise blocks this headless nvim on
	# "Press ENTER" forever, with no terminal to press it in. Then drive the
	# install with vim.wait rather than a fixed `:sleep`, so it exits the moment
	# Mason is done instead of always burning the whole timeout.
	$masonScript = @'
vim.o.more = false
vim.opt.shortmess:append("F")

local done = false
local ok, registry = pcall(require, "mason-registry")
if not ok then
  print("mason-registry unavailable - run Install.ps1 (or :Lazy sync) first")
  vim.cmd("cq!")
  return
end

registry.refresh(function()
  local pkg = registry.get_package("netcoredbg")
  if pkg:is_installed() then
    print("netcoredbg already installed - skipping")
    done = true
    return
  end
  pkg:install():once("closed", function()
    print(pkg:is_installed() and "netcoredbg installed" or "netcoredbg install FAILED")
    done = true
  end)
end)

if not vim.wait(300000, function() return done end, 200) then
  print("timed out waiting for netcoredbg - run ':MasonInstall netcoredbg' in nvim")
end
vim.cmd("qa!")
'@
	$masonScriptPath = Join-Path $env:TEMP "mason-install-netcoredbg.lua"
	Set-Content -Path $masonScriptPath -Value $masonScript -Encoding utf8
	# A plain headless run (not `nvim -l`, which skips the user config) so the
	# plugins - and therefore mason-registry - are actually loaded.
	nvim --headless -c "luafile $masonScriptPath"
	Remove-Item -Path $masonScriptPath -ErrorAction SilentlyContinue
}

# --- 5. Verify ------------------------------------------------------------

Write-Step "Verifying"
# Executable names, which don't always match the package id - the EasyDotnet
# package installs a command called `dotnet-easydotnet`.
foreach ($tool in @("dotnet", "roslyn-language-server", "dotnet-easydotnet")) {
	$cmd = Get-Command $tool -ErrorAction SilentlyContinue
	if ($cmd) {
		Write-Host "    ok   $tool -> $($cmd.Source)" -ForegroundColor Green
	} else {
		Write-Warning "    MISSING: $tool (restart your shell so the PATH change takes effect, then re-check)"
	}
}

$netcoredbg = Join-Path $env:LOCALAPPDATA "nvim-data\mason\packages\netcoredbg\netcoredbg\netcoredbg.exe"
if (Test-Path $netcoredbg) {
	Write-Host "    ok   netcoredbg -> $netcoredbg" -ForegroundColor Green
} else {
	Write-Warning "    MISSING: netcoredbg - run ':MasonInstall netcoredbg' inside nvim."
}

Write-Step @"
Done. Restart your shell so PATH changes take effect, then open a .cs file
from inside a solution directory (not the .sln itself - Roslyn's root
detection walks out from the buffer's path):

  cd <your solution dir>
  nvim src\Something\Program.cs

  :checkhealth easy-dotnet   - confirms the .NET side
  :LspInfo                   - confirms roslyn attached
  <leader>nt                 - open the test runner
  <leader>db then <F5>       - breakpoint, then start debugging
"@
