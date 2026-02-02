import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import cv2
import numpy as np
import torch

print("Starting worker...", flush=True)

# Avoid importing basicsr directly - load model manually
from torch import nn

STORAGE_ROOT = Path(os.environ.get("STORAGE_ROOT", Path(__file__).resolve().parents[1] / "storage"))
JOBS_DIR = STORAGE_ROOT / "jobs"
TMP_DIR = STORAGE_ROOT / "tmp"
OUTPUTS_DIR = STORAGE_ROOT / "outputs"

WEIGHTS_DIR = Path(__file__).resolve().parent / "weights"
MODEL_PATH = WEIGHTS_DIR / "RealESRGAN_x4plus.pth"

POLL_INTERVAL = 3


def load_job(job_path: Path):
    with job_path.open("r") as file:
        return json.load(file)


def save_job(job_path: Path, job: dict):
    job["updatedAt"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with job_path.open("w") as file:
        json.dump(job, file, indent=2)


def run_cmd(command: list[str]):
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Command failed")
    return result.stdout


def probe_video(input_path: Path):
    output = run_cmd(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height,r_frame_rate",
            "-of",
            "json",
            str(input_path),
        ]
    )
    data = json.loads(output)
    stream = data["streams"][0]
    width = int(stream["width"])
    height = int(stream["height"])
    rate = stream["r_frame_rate"]
    if "/" in rate:
        num, den = rate.split("/")
        fps = float(num) / float(den)
    else:
        fps = float(rate)
    return width, height, fps


def extract_frames(input_path: Path, frames_dir: Path):
    frames_dir.mkdir(parents=True, exist_ok=True)
    run_cmd(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(input_path),
            "-vsync",
            "0",
            "-q:v",
            "1",
            str(frames_dir / "%08d.png"),
        ]
    )


def upscale_frames(frames_dir: Path, output_dir: Path, job_path: Path, job: dict):
    output_dir.mkdir(parents=True, exist_ok=True)

    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Missing model weights at {MODEL_PATH}. Place RealESRGAN_x4plus.pth in worker/weights."
        )

    device = "mps" if torch.backends.mps.is_available() else "cpu"
    
    # On CPU, Real-ESRGAN is too slow (~7s per frame).
    # Use fast OpenCV upscaling instead. For GPU, use the AI upscaler.
    use_fast_upscale = (device == "cpu")
    
    if use_fast_upscale:
        print(f"Using fast CPU upscaling (OpenCV Lanczos4)...", flush=True)
        upsampler = None  # Won't be used
    else:
        print("Importing model dependencies...", flush=True)
        # Import model architecture
        from basicsr.archs.rrdbnet_arch import RRDBNet
        from realesrgan import RealESRGANer
        
        print(f"Initializing model on {device}...", flush=True)
        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
        print("Loading RealESRGAN weights...", flush=True)
        upsampler = RealESRGANer(
            scale=4,
            model_path=str(MODEL_PATH),
            model=model,
            tile=32,
            tile_pad=8,
            pre_pad=0,
            half=False,
            device=device,
        )
        print("Model ready.", flush=True)

    frames = sorted(frames_dir.glob("*.png"))
    total = len(frames)
    if total == 0:
        raise RuntimeError("No frames extracted from input video.")

    for idx, frame_path in enumerate(frames, start=1):
        image = cv2.imread(str(frame_path), cv2.IMREAD_COLOR)
        if image is None:
            raise RuntimeError(f"Failed to read frame {frame_path.name}")
        print(f"Upscaling frame {idx}/{total}: {frame_path.name}", flush=True)
        start_ts = time.time()
        
        if use_fast_upscale:
            # Fast CPU upscaling using OpenCV Lanczos4
            h, w = image.shape[:2]
            output = cv2.resize(image, (w * 4, h * 4), interpolation=cv2.INTER_LANCZOS4)
        else:
            # AI upscaling (GPU)
            output, _ = upsampler.enhance(image, outscale=4)
        
        elapsed = time.time() - start_ts
        out_path = output_dir / frame_path.name
        cv2.imwrite(str(out_path), output)

        job["progress"] = min(90, (idx / total) * 90)
        save_job(job_path, job)
        print(
            f"Progress: {job['progress']:.1f}% ({idx}/{total} frames) | {elapsed:.2f}s",
            flush=True,
        )


def encode_video(
    input_path: Path,
    upscaled_dir: Path,
    output_path: Path,
    fps: float,
    target_height: int,
):
    output_path.parent.mkdir(parents=True, exist_ok=True)
    run_cmd(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(input_path),
            "-framerate",
            f"{fps}",
            "-i",
            str(upscaled_dir / "%08d.png"),
            "-map",
            "1:v:0",
            "-map",
            "0:a?",
            "-vf",
            f"scale=-2:{target_height}:flags=lanczos,setsar=1",
            "-c:v",
            "libx264",
            "-preset",
            "slow",
            "-crf",
            "18",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-shortest",
            str(output_path),
        ]
    )


def process_job(job_path: Path):
    job = load_job(job_path)
    job["status"] = "processing"
    job["progress"] = 1
    save_job(job_path, job)

    input_path = STORAGE_ROOT / job["inputPath"]
    output_path = STORAGE_ROOT / job["outputPath"]

    print(f"Probing video: {input_path}", flush=True)
    width, height, fps = probe_video(input_path)
    requested_target = job.get("targetHeight")
    target_height = max(int(requested_target) if requested_target else 1080, height)

    temp_root = TMP_DIR / job["id"]
    frames_dir = temp_root / "frames"
    upscaled_dir = temp_root / "upscaled"

    try:
        print("Extracting frames...", flush=True)
        extract_frames(input_path, frames_dir)
        print("Upscaling frames...", flush=True)
        upscale_frames(frames_dir, upscaled_dir, job_path, job)
        job["progress"] = 92
        save_job(job_path, job)
        print("Encoding video...", flush=True)
        encode_video(input_path, upscaled_dir, output_path, fps, target_height)
        job["status"] = "completed"
        job["progress"] = 100
        save_job(job_path, job)
        print("Job completed.", flush=True)
    finally:
        if temp_root.exists():
            shutil.rmtree(temp_root, ignore_errors=True)


def find_next_job():
    for job_path in JOBS_DIR.glob("*.json"):
        try:
            job = load_job(job_path)
        except Exception:
            continue
        if job.get("status") == "queued":
            return job_path
    return None


def main():
    JOBS_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Worker ready. Polling {JOBS_DIR} every {POLL_INTERVAL}s", flush=True)

    while True:
        job_path = find_next_job()
        if job_path is None:
            time.sleep(POLL_INTERVAL)
            continue
        try:
            print(f"Processing job: {job_path.name}", flush=True)
            process_job(job_path)
            print(f"Completed job: {job_path.name}", flush=True)
        except Exception as exc:
            print(f"Error processing {job_path.name}: {exc}", file=sys.stderr, flush=True)
            try:
                job = load_job(job_path)
                job["status"] = "failed"
                job["error"] = str(exc)
                save_job(job_path, job)
            except Exception:
                pass


if __name__ == "__main__":
    main()
