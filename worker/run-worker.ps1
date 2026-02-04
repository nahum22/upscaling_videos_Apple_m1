Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Run worker with GPU support (outside Docker)
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "Setting up Python environment for GPU worker..."

$pythonExe = $null
$envPython = $env:WORKER_PYTHON
if ($envPython) {
    if (Test-Path -Path $envPython) {
        $pythonExe = (Resolve-Path $envPython).Path
    } else {
        Write-Error "Error: WORKER_PYTHON path not found: $envPython"
        exit 1
    }
}

$pyLauncher = Get-Command py -ErrorAction SilentlyContinue
if (-not $pythonExe -and $pyLauncher) {
    try {
        $py312 = & py -3.12 -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $py312) {
            $pythonExe = $py312
        }
    } catch {
        # ignore and fall back to python.exe
    }
}

if (-not $pythonExe) {
    $candidatePaths = @(
        "$env:LocalAppData\Programs\Python\Python312\python.exe",
        "$env:ProgramFiles\Python312\python.exe",
        "$env:ProgramFiles(x86)\Python312\python.exe"
    )
    foreach ($candidate in $candidatePaths) {
        if (Test-Path -Path $candidate) {
            $pythonExe = $candidate
            break
        }
    }
}

if (-not $pythonExe) {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $pythonExe = $pythonCmd.Source
    }
}

if (-not $pythonExe) {
    Write-Error "Error: Python 3.12.x is required but not found. Install Python 3.12, or set WORKER_PYTHON to the full path of python.exe."
    exit 1
}

$pyVersion = & $pythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
if ($LASTEXITCODE -ne 0 -or -not $pyVersion) {
    Write-Error "Error: Unable to determine Python version"
    exit 1
}

$versionParts = $pyVersion.Split('.')
$major = [int]$versionParts[0]
$minor = [int]$versionParts[1]
if ($major -ne 3 -or $minor -ne 12) {
    Write-Error "Error: Python 3.12.x is required but found $pyVersion"
    exit 1
}

Write-Host "Installing virtual environment with Python $pyVersion"

Write-Host "Checking ffmpeg/ffprobe..."
$ffmpegBin = $env:FFMPEG_BIN
if ($ffmpegBin) {
    if ((Test-Path -Path (Join-Path $ffmpegBin "ffmpeg.exe")) -and (Test-Path -Path (Join-Path $ffmpegBin "ffprobe.exe"))) {
        $env:Path = "$ffmpegBin;$env:Path"
    } else {
        Write-Error "Error: FFMPEG_BIN is set but ffmpeg.exe/ffprobe.exe not found in $ffmpegBin"
        exit 1
    }
}

$ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobeCmd = Get-Command ffprobe -ErrorAction SilentlyContinue
if (-not $ffmpegCmd -or -not $ffprobeCmd) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Error "Error: ffmpeg/ffprobe not found and winget is unavailable. Install ffmpeg and ensure it is on PATH."
        exit 1
    }
    Write-Host "ffmpeg not found. Installing via winget..."
    winget install -e --id Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
    $candidateDirs = @(
        "$env:ProgramFiles\ffmpeg\bin",
        "$env:ProgramFiles\Gyan\FFmpeg\bin",
        "$env:LocalAppData\Programs\ffmpeg\bin"
    )

    $wingetRoot = Join-Path $env:LocalAppData "Microsoft\WinGet\Packages"
    if (Test-Path -Path $wingetRoot) {
        $wingetFfmpeg = Get-ChildItem -Path $wingetRoot -Directory -Filter "Gyan.FFmpeg*" -ErrorAction SilentlyContinue
        foreach ($folder in $wingetFfmpeg) {
            $binPath = Join-Path $folder.FullName "bin"
            if (Test-Path -Path (Join-Path $binPath "ffmpeg.exe")) {
                $candidateDirs += $binPath
            }
            if (Test-Path -Path (Join-Path $folder.FullName "ffmpeg.exe")) {
                $candidateDirs += $folder.FullName
            }
        }
    }

    foreach ($dir in $candidateDirs) {
        if (Test-Path -Path (Join-Path $dir "ffmpeg.exe")) {
            $env:Path = "$dir;$env:Path"
            $env:FFMPEG_BIN = $dir
            break
        }
    }

    $ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    $ffprobeCmd = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffmpegCmd -or -not $ffprobeCmd) {
        $searchRoots = @(
            "$env:ProgramFiles",
            "$env:ProgramFiles(x86)",
            "$env:LocalAppData",
            "C:\ffmpeg"
        )
        foreach ($root in $searchRoots) {
            if (-not $root -or -not (Test-Path -Path $root)) { continue }
            $ffmpegFile = Get-ChildItem -Path $root -Recurse -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ffmpegFile) {
                $binDir = $ffmpegFile.DirectoryName
                $ffprobeFile = Join-Path $binDir "ffprobe.exe"
                if (Test-Path -Path $ffprobeFile) {
                    Write-Host "Using ffmpeg from: $binDir"
                    $env:Path = "$binDir;$env:Path"
                    $env:FFMPEG_BIN = $binDir
                    break
                }
            }
        }
    }

    $ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    $ffprobeCmd = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffmpegCmd -or -not $ffprobeCmd) {
        try {
            $ffmpegPath = (where.exe ffmpeg 2>$null | Select-Object -First 1)
            $ffprobePath = (where.exe ffprobe 2>$null | Select-Object -First 1)
            if ($ffmpegPath -and $ffprobePath) {
                $binDir = Split-Path -Parent $ffmpegPath
                Write-Host "Using ffmpeg from: $binDir"
                $env:Path = "$binDir;$env:Path"
                $env:FFMPEG_BIN = $binDir
            }
        } catch {
            # ignore
        }
    }

    $ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    $ffprobeCmd = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffmpegCmd -or -not $ffprobeCmd) {
        Write-Error "Error: ffmpeg/ffprobe still not found. Set FFMPEG_BIN to the folder containing ffmpeg.exe and ffprobe.exe, or add that folder to PATH."
        exit 1
    }
}

$weightsPath = Join-Path (Get-Location) "weights\RealESRGAN_x4plus.pth"
if (-not (Test-Path -Path $weightsPath)) {
    Write-Host "Downloading model weights..."
    $weightsUrl = "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"
    $weightsDir = Split-Path -Parent $weightsPath
    if (-not (Test-Path -Path $weightsDir)) {
        New-Item -ItemType Directory -Path $weightsDir | Out-Null
    }
    try {
        Invoke-WebRequest -Uri $weightsUrl -OutFile $weightsPath -UseBasicParsing
    } catch {
        Write-Error "Error: Failed to download model weights. Download manually to $weightsPath"
        exit 1
    }
}

if (Test-Path -Path "venv") {
    $existingVenvPython = Join-Path (Get-Location) "venv\Scripts\python.exe"
    if (Test-Path -Path $existingVenvPython) {
        $existingVersion = & $existingVenvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
        if ($LASTEXITCODE -ne 0 -or $existingVersion -ne "3.12") {
            Write-Host "Recreating virtual environment for Python 3.12..."
            Remove-Item -Recurse -Force "venv"
        }
    } else {
        Remove-Item -Recurse -Force "venv"
    }
}

if (-not (Test-Path -Path "venv")) {
    Write-Host "Creating virtual environment..."
    & $pythonExe -m venv venv
}

. .\venv\Scripts\Activate.ps1
$venvPython = Join-Path (Get-Location) "venv\Scripts\python.exe"

Write-Host "Installing dependencies..."
& $venvPython -m pip install --upgrade pip setuptools wheel
& $venvPython -m pip install --only-binary=numpy numpy==1.26.4
& $venvPython -m pip install -r requirements.txt --prefer-binary

# If NVIDIA GPU is present, install CUDA-enabled PyTorch
$nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($nvidiaSmi) {
    Write-Host "NVIDIA GPU detected. Installing CUDA-enabled PyTorch..."
    & $venvPython -m pip install --upgrade --index-url https://download.pytorch.org/whl/cu118 torch==2.2.0+cu118 torchvision==0.17.0+cu118
}

$storageRoot = Resolve-Path (Join-Path (Get-Location) "..\storage")
$env:STORAGE_ROOT = $storageRoot

Write-Host ""
Write-Host "Starting worker with GPU support..."
Write-Host "Storage root: $env:STORAGE_ROOT"
Write-Host ""

& $venvPython main.py
