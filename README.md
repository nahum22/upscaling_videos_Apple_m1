# Metal AI Video Upscaler (Native)

Local web app with AI worker that upscales videos to 1080p, 4K, or 8K with GPU-accelerated Real-ESRGAN running natively on Apple Silicon.

## Requirements

- **macOS with Apple Silicon** (M1, M2, M3, M4, etc.)
- Node.js 20+
- Python 3.12+
- Real-ESRGAN model weights (see Quick Start below)

## Quick Start

### 1. Download Model Weights

```bash
cd worker/weights
curl -L -o RealESRGAN_x4plus.pth https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth
cd ../..
```

### 2. Install Dependencies (First Time Only)

```bash
# Install Node.js dependencies
npm install

# Create Python virtual environment and install dependencies
python3 -m venv .venv
.venv/bin/pip install -r worker/requirements.txt
```

### 3. Start All Services

```bash
./start-native.sh
```

This starts:
- Next.js web UI on localhost:3000
- Python GPU worker with Metal (MPS) acceleration

**To stop services:**
```bash
./stop-native.sh
```

**Manual start (alternative):**
```bash
# Terminal 1: Web service
npm run dev

# Terminal 2: GPU worker
cd worker
STORAGE_ROOT="../storage" "../.venv/bin/python" main.py
```

## Usage

1. Open localhost:3000 in your browser
2. Select target quality: 1080p (Full HD), 2160p (4K), or 4320p (8K)
3. Upload a video
4. Worker processes with Metal GPU and Real-ESRGAN AI upscaler
5. Download the completed video

## GPU Acceleration

- Uses PyTorch with Metal Performance Shaders (MPS) backend
- Leverages Apple Silicon GPU for AI inference
- No Docker required - runs natively for best performance
- GPU diagnostics printed per job (torch version, MPS availability, device info)

## Docker Setup (Legacy)

If you prefer Docker:
```bash
./start.sh  # Uses docker-compose
```

## Notes

- Aspect ratio is preserved automatically
- Quality prioritized over speed
- First run may take longer as PyTorch initializes Metal backend
- Progress updates every 3 seconds during processing
