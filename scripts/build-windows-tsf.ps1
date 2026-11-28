# Builds the T-Time Text Services Framework DLL against ttime-ffi (Windows MSVC).
# Output: build/windows/TTimeTSF.dll
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
$targetDir = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { "target" }

New-Item -ItemType Directory -Force -Path build\windows | Out-Null
cargo build --release -p ttime-ffi
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# System libraries the Rust staticlib needs (ws2_32, bcrypt, …).
$nativeNote = cargo rustc --color never -p ttime-ffi --release -- --print=native-static-libs 2>&1 |
    Select-String -Pattern "native-static-libs:" |
    Select-Object -Last 1
$nativeLibs = @()
if ($nativeNote) {
    $line = $nativeNote.ToString()
    $idx = $line.IndexOf("native-static-libs:")
    if ($idx -ge 0) {
        $rest = $line.Substring($idx + "native-static-libs:".Length).Trim()
        foreach ($tok in $rest.Split(@(" "), [System.StringSplitOptions]::RemoveEmptyEntries)) {
            if ($tok.StartsWith("-l")) {
                $nativeLibs += ($tok.Substring(2) + ".lib")
            } elseif ($tok.StartsWith("/")) {
                # A linker flag (/defaultlib:msvcrt): /MD links that runtime anyway, and
                # CMake would take the flag for a file name.
            } else {
                $nativeLibs += $tok
            }
        }
    }
}
if ($nativeLibs.Count -eq 0) {
    Write-Error "could not read the native libraries ttime-ffi needs"
}

# Visual Studio developer environment (cmake + MSVC).
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

$lib = (Resolve-Path (Join-Path $targetDir "release\ttime_ffi.lib")).Path
$inc = (Resolve-Path "crates\ttime-ffi\include").Path
$nativeJoined = ($nativeLibs -join " ")
$buildDir = "build\windows\ninja"  # not ...\cmake: an older Visual Studio cache there would clash
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

# Ninja comes with the Visual Studio C++ tools and is on PATH in the developer shell,
# so this does not depend on which Visual Studio version is installed.
cmake -S windows\tsf -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE=Release `
    "-DTTIME_FFI_LIB=$lib" `
    "-DTTIME_FFI_INCLUDE=$inc" `
    "-DTTIME_NATIVE_LIBS=$nativeJoined"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cmake --build $buildDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$built = Get-ChildItem -Path $buildDir -Recurse -Filter TTimeTSF.dll | Select-Object -First 1

if (-not $built) {
    Write-Error "TTimeTSF.dll was not produced"
}
Copy-Item -Force $built.FullName "build\windows\TTimeTSF.dll"
# Also keep the import lib next to it when present (useful for debugging).
$implib = Get-ChildItem -Path $buildDir -Recurse -Filter TTimeTSF.lib -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($implib) {
    Copy-Item -Force $implib.FullName "build\windows\TTimeTSF.lib"
}
Copy-Item -Force $lib "build\windows\ttime_ffi.lib"

Write-Host "built build\windows\TTimeTSF.dll"
Write-Host "Register (elevated): pwsh -File windows\register.ps1"
