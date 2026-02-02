# Metal AI Video Upscaler (Local)

Local web app with AI worker that upscales videos to at least 1080p, preserving aspect ratio.

## Requirements

- Docker Desktop
- Real-ESRGAN model weights (see Quick Start below)

## Quick Start

### 1. Download Model Weights

```bash
cd worker/weights
curl -L -o RealESRGAN_x4plus.pth https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth
cd ../..
```

### 2. Start All Services

```bash
docker compose --profile cpu up
```

This starts both the web UI and the worker. Open localhost:3000 in your browser.

## Usage

1. Upload a video in the web UI
2. Worker picks up the job and upscales to 1080p
3. Download the completed video

## Notes

- Videos are always upscaled, regardless of input resolution
- Aspect ratio is preserved automatically
- Quality prioritized over speed (slower but better results)
- Worker runs in Docker (CPU mode) - for Metal acceleration on M3 Mac, run the worker natively on the host instead
