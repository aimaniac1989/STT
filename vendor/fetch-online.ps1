# Downloads the offline bundle onto this PC. Run once while this PC has internet.
# The H100 never runs this script. Re-running skips files that already finished.
# Default is the training bundle only. Pass -IncludeAndroid to also build the app.
param(
    [switch]$IncludeAndroid
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root "training\README.md"))) {
    $Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
Set-Location $Root

$GradleVersion = "8.13"
$SherpaVersion = "1.13.6"
$PythonAbi = "cp312"

function New-Dir([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Write-Text([string]$Path, $Value) {
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Dir $dir }
    if ($Value -is [System.Array]) {
        $text = (($Value | ForEach-Object { "$_" }) -join "`n")
    } else {
        $text = [string]$Value
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $text.TrimEnd() + "`n", $utf8)
}

function Get-File([string]$Url, [string]$Dest) {
    New-Dir (Split-Path -Parent $Dest)
    $marker = "$Dest.complete"
    if (Test-Path $marker) {
        Write-Host "skip $Dest"
        return
    }
    $attempt = 0
    while ($attempt -lt 5) {
        $attempt++
        Write-Host "get $Url (attempt $attempt)"
        if (Test-Path $Dest) {
            & curl.exe -fL --retry 5 --retry-delay 2 -C - -o $Dest $Url
        } else {
            & curl.exe -fL --retry 5 --retry-delay 2 -o $Dest $Url
        }
        if ($LASTEXITCODE -eq 0) {
            New-Item -ItemType File -Path $marker -Force | Out-Null
            return
        }
        Write-Host "transfer broke, retrying $Url"
        Start-Sleep -Seconds (10 * $attempt)
    }
    throw "Download failed: $Url"
}

function Find-Cuda13TorchWheel {
    $indexUrl = "https://download.pytorch.org/whl/cu130/torch/"
    Write-Host "read $indexUrl"
    $html = (& curl.exe -fsL $indexUrl) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not $html) {
        return $null
    }
    $pattern = 'torch-(\d+\.\d+\.\d+)\+cu130-' + $PythonAbi + '-' + $PythonAbi + '-win_amd64\.whl'
    $found = [regex]::Matches($html, $pattern) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    if (-not $found) {
        return $null
    }
    $best = $found | Sort-Object { [version]$_ } | Select-Object -Last 1
    return $best
}

Write-Host "Root $Root"

New-Dir "$Root\vendor\windows"
New-Dir "$Root\vendor\h100\wheels"
New-Dir "$Root\vendor\packs"
New-Dir "$Root\vendor\checkpoints"

if ($IncludeAndroid) {
New-Dir "$Root\vendor\gradle"
New-Dir "$Root\vendor\maven\com\k2fsa\sherpa\sherpa-onnx\$SherpaVersion"
New-Dir "$Root\stt-android\gradle\wrapper"

$jdkZip = "$Root\vendor\windows\jdk-17.zip"
Get-File "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk" $jdkZip
$jdkExpand = "$Root\vendor\windows\jdk"
if (-not (Test-Path "$jdkExpand\.extracted")) {
    if (Test-Path $jdkExpand) { Remove-Item -Recurse -Force $jdkExpand }
    New-Dir $jdkExpand
    Expand-Archive -Path $jdkZip -DestinationPath $jdkExpand -Force
    New-Item -ItemType File -Path "$jdkExpand\.extracted" -Force | Out-Null
}
$javaExe = Get-ChildItem -Path $jdkExpand -Recurse -Filter java.exe |
    Where-Object { $_.FullName -match '\\bin\\java.exe$' } |
    Select-Object -First 1
if (-not $javaExe) { throw "JDK zip did not contain bin\java.exe" }
$javaHome = $javaExe.Directory.Parent.FullName
Write-Text "$Root\vendor\windows\jdk-home.txt" $javaHome
Write-Host "JAVA_HOME $javaHome"

$gradleZip = "$Root\vendor\gradle\gradle-$GradleVersion-bin.zip"
Get-File "https://services.gradle.org/distributions/gradle-$GradleVersion-bin.zip" $gradleZip

$wrapperJar = "$Root\stt-android\gradle\wrapper\gradle-wrapper.jar"
Get-File "https://raw.githubusercontent.com/gradle/gradle/v$GradleVersion.0/gradle/wrapper/gradle-wrapper.jar" $wrapperJar
$gradlewBat = "$Root\stt-android\gradlew.bat"
Get-File "https://raw.githubusercontent.com/gradle/gradle/v$GradleVersion.0/gradlew.bat" $gradlewBat

$gradleUrl = ($gradleZip -replace '\\', '/')
$props = @"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=file\:///$gradleUrl
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@
$propFile = "$Root\stt-android\gradle\wrapper\gradle-wrapper.properties"
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($propFile, $props.Trim() + "`n", $utf8)

$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
if (-not (Test-Path $sdk)) { throw "Android SDK not found at $sdk" }
$sdkEsc = $sdk -replace '\\', '\\'
Write-Text "$Root\stt-android\local.properties" "sdk.dir=$sdkEsc"

$aarName = "sherpa-onnx-$SherpaVersion.aar"
$aarDest = "$Root\vendor\maven\com\k2fsa\sherpa\sherpa-onnx\$SherpaVersion\$aarName"
Get-File "https://github.com/k2-fsa/sherpa-onnx/releases/download/v$SherpaVersion/$aarName" $aarDest
$pom = @"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.k2fsa.sherpa</groupId>
  <artifactId>sherpa-onnx</artifactId>
  <version>$SherpaVersion</version>
  <packaging>aar</packaging>
</project>
"@
Write-Text "$Root\vendor\maven\com\k2fsa\sherpa\sherpa-onnx\$SherpaVersion\sherpa-onnx-$SherpaVersion.pom" $pom

$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $sdk
$env:GRADLE_USER_HOME = "$Root\vendor\gradle-user-home"
New-Dir $env:GRADLE_USER_HOME
Write-Host "assembleDebug (fills the Gradle cache used for later offline builds)"
Push-Location "$Root\stt-android"
$code = 1
foreach ($try in 1..3) {
    & .\gradlew.bat assembleDebug --no-daemon
    $code = $LASTEXITCODE
    if ($code -eq 0) { break }
    Write-Host "assembleDebug attempt $try failed, waiting for file locks to clear"
    Start-Sleep -Seconds (5 * $try)
}
Pop-Location
if ($code -ne 0) { throw "assembleDebug failed with exit $code" }
} else {
    Write-Host "Skipping the Android build. Training bundle only. Pass -IncludeAndroid to build the app."
}

Write-Host "English training checkpoint"
Get-File "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2/resolve/main/parakeet-tdt-0.6b-v2.nemo" "$Root\vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo"

Get-File "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" "$Root\vendor\windows\Miniconda3-latest-Windows-x86_64.exe"
Get-File "https://repo.anaconda.com/miniconda/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe" "$Root\vendor\windows\Miniconda3-py312_25.7.0-2-Windows-x86_64.exe"

$condaPrefix = "$Root\vendor\windows\miniconda"
$condaPython = Join-Path $condaPrefix "python.exe"
if (-not (Test-Path $condaPython)) {
    Write-Host "install Miniconda into $condaPrefix"
    $installArgs = "/InstallationType=JustMe /AddToPath=0 /RegisterPython=0 /S /D=$condaPrefix"
    $proc = Start-Process -FilePath "$Root\vendor\windows\Miniconda3-latest-Windows-x86_64.exe" -ArgumentList $installArgs -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "Miniconda installer exit $($proc.ExitCode)" }
}
if (-not (Test-Path $condaPython)) { throw "Miniconda python.exe missing at $condaPython" }

& $condaPython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed" }

$torchVersion = Find-Cuda13TorchWheel
$missing = "$Root\vendor\h100\CUDA13_WHEEL_MISSING.txt"
if (-not $torchVersion) {
    $note = @"
No stable Windows win_amd64 cp312 wheel was found on https://download.pytorch.org/whl/cu130/torch/ .
The H100 toolkit is CUDA 13.2 (driver 597.95). PyTorch serves that toolkit as a cu130 wheel, not cu132.
Do not downgrade driver 597.95. Do not copy this bundle to the H100 until a cu130 wheel is listed.
"@
    Write-Text $missing $note
    throw $note
}
if (Test-Path $missing) { Remove-Item -Force $missing }
Write-Text "$Root\vendor\h100\torch-pin.txt" "torch==$torchVersion+cu130"
Write-Host "CUDA 13.2 toolkit, torch pin torch==$torchVersion+cu130"

$wheels = "$Root\vendor\h100\wheels"
$pipPlatform = @(
    "--python-version", "312",
    "--platform", "win_amd64",
    "--implementation", "cp",
    "--abi", "cp312",
    "--only-binary=:all:"
)
& $condaPython -m pip download `
    "torch==$torchVersion+cu130" torchvision torchaudio `
    --index-url "https://download.pytorch.org/whl/cu130" `
    -d $wheels @pipPlatform
if ($LASTEXITCODE -ne 0) { throw "PyTorch cu130 wheel download failed (needed for the CUDA 13.2 toolkit)" }

$constraint = "$Root\vendor\h100\constraints.txt"
Write-Text $constraint "torch==$torchVersion+cu130"
& $condaPython -m pip download `
    -r "$Root\training\requirements-h100.txt" `
    -c $constraint `
    --extra-index-url "https://download.pytorch.org/whl/cu130" `
    -d $wheels @pipPlatform
if ($LASTEXITCODE -ne 0) { throw "H100 wheel download failed. Fix it on this PC. Do not use the network on the H100." }

$lock = Get-ChildItem $wheels -File | ForEach-Object { $_.Name } | Sort-Object
Write-Text "$Root\vendor\h100\requirements-lock.txt" $lock

$qwenDir = "$Root\vendor\checkpoints\Qwen3-ASR-0.6B-hf"
foreach ($name in @(
    "config.json", "generation_config.json", "model.safetensors",
    "processor_config.json", "tokenizer.json", "tokenizer_config.json", "chat_template.jinja"
)) {
    Get-File "https://huggingface.co/Qwen/Qwen3-ASR-0.6B-hf/resolve/main/$name" (Join-Path $qwenDir $name)
}

$packFiles = @(
    @{ Url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2"; Name = "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2" },
    @{ Url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2"; Name = "sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2" },
    @{ Url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2"; Name = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2" },
    @{ Url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx"; Name = "silero_vad.onnx" }
)
foreach ($pack in $packFiles) {
    Get-File $pack.Url (Join-Path "$Root\vendor\packs" $pack.Name)
}

function Write-Sums([string]$ListPath, [string[]]$Files) {
    $lines = foreach ($file in $Files) {
        $hash = (Get-FileHash -Algorithm SHA256 -Path $file).Hash.ToLower()
        $rel = Resolve-Path -Relative $file
        "{0}  {1}" -f $hash, ($rel -replace '\\', '/')
    }
    Write-Text $ListPath $lines
}

$bundleFiles = @()
$named = @(
    "$Root\vendor\windows\jdk-17.zip",
    "$Root\vendor\windows\Miniconda3-latest-Windows-x86_64.exe",
    "$Root\vendor\windows\Miniconda3-py312_25.7.0-2-Windows-x86_64.exe",
    "$Root\vendor\gradle\gradle-$GradleVersion-bin.zip",
    "$Root\vendor\maven\com\k2fsa\sherpa\sherpa-onnx\$SherpaVersion\sherpa-onnx-$SherpaVersion.aar"
)
$bundleFiles += $named | Where-Object { Test-Path $_ } | ForEach-Object { Get-Item $_ }
$bundleFiles += Get-ChildItem $wheels -File
$bundleFiles += Get-ChildItem "$Root\vendor\packs" -File
$bundleFiles += Get-ChildItem "$Root\vendor\checkpoints" -File
Write-Sums "$Root\vendor\checksums.sha256" ($bundleFiles | ForEach-Object { $_.FullName })

$packOnly = Get-ChildItem "$Root\vendor\packs" -File
$packLines = foreach ($file in $packOnly) {
    $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLower()
    "{0}  {1}" -f $hash, $file.Name
}
Write-Text "$Root\packs\checksums.sha256" $packLines

Write-Host "Bundle ready. Checksums: vendor\checksums.sha256 and packs\checksums.sha256"
