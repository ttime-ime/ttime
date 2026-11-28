# Builds ffi-smoke against the ttime-ffi static library (Windows MSVC).
# Output: build/ffi-smoke.exe
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
$targetDir = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { "target" }

New-Item -ItemType Directory -Force -Path build | Out-Null
cargo build --release -p ttime-ffi
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# System libraries the Rust staticlib needs (ws2_32, bcrypt, …).
# --color never: CI sets CARGO_TERM_COLOR=always, and colour codes end up in the library names.
$nativeNote = cargo rustc --color never -p ttime-ffi --release -- --print=native-static-libs 2>&1 |
    Select-String -Pattern "native-static-libs:" |
    Select-Object -Last 1
$nativeLibs = @()
if ($nativeNote) {
    $line = $nativeNote.ToString()
    $idx = $line.IndexOf("native-static-libs:")
    if ($idx -ge 0) {
        $rest = $line.Substring($idx + "native-static-libs:".Length).Trim()
        # Rust prints flags like -lws2_32 -ladvapi32; cl wants ws2_32.lib.
        foreach ($tok in $rest.Split(@(" "), [System.StringSplitOptions]::RemoveEmptyEntries)) {
            if ($tok.StartsWith("-l")) {
                $nativeLibs += ($tok.Substring(2) + ".lib")
            } elseif ($tok.StartsWith("/DEFAULTLIB:")) {
                $nativeLibs += $tok.Substring("/DEFAULTLIB:".Length)
            } else {
                $nativeLibs += $tok
            }
        }
    }
}

if ($nativeLibs.Count -eq 0) {
    Write-Error "could not read the native libraries ttime-ffi needs"
}

# Load the Visual Studio developer environment so cl.exe is on PATH.
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Error "vswhere.exe not found; install Visual Studio Build Tools with the C++ workload."
}
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) {
    Write-Error "No Visual Studio C++ tools found."
}
$devShell = Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Import-Module $devShell
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments "-arch=x64" | Out-Null

$lib = Join-Path $targetDir "release\ttime_ffi.lib"
$inc = "crates\ttime-ffi\include"
$out = "build\ffi-smoke.exe"

# /utf-8: the sources are UTF-8; Windows runners default to code page 1252 (warning C4819).
# /MD: the DLL C runtime, as Rust's MSVC staticlib uses; cl's default (/MT, LIBCMT) mixes
# two runtimes (LNK4098), which a TSF DLL loaded into other processes must not do.
$linkArgs = @("/nologo", "/utf-8", "/W4", "/MD", "/O2", "/Fe:$out", "ffi-smoke\main.c", "/I$inc", "/link", $lib) + $nativeLibs
& cl @linkArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "built $out"
& $out
exit $LASTEXITCODE
