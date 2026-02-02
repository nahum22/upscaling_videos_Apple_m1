"use client";

import { useEffect, useMemo, useState } from "react";

type JobStatus = "queued" | "processing" | "completed" | "failed";

interface JobState {
  id: string;
  status: JobStatus;
  progress: number;
  error?: string;
}

export default function Home() {
  const [file, setFile] = useState<File | null>(null);
  const [job, setJob] = useState<JobState | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const downloadUrl = useMemo(() => {
    if (!job || job.status !== "completed") return null;
    return `/api/download?id=${job.id}`;
  }, [job]);

  useEffect(() => {
    if (!job || job.status === "completed" || job.status === "failed") return;

    const interval = setInterval(async () => {
      try {
        const response = await fetch(`/api/status?id=${job.id}`);
        if (!response.ok) return;
        const next = await response.json();
        setJob({
          id: next.id,
          status: next.status,
          progress: next.progress ?? 0,
          error: next.error,
        });
      } catch {
        setError("Failed to refresh job status.");
      }
    }, 3000);

    return () => clearInterval(interval);
  }, [job]);

  const handleUpload = async () => {
    if (!file) {
      setError("Please select a video file.");
      return;
    }

    setError(null);
    setIsUploading(true);
    setJob(null);

    try {
      const formData = new FormData();
      formData.append("file", file);

      const response = await fetch("/api/upload", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        throw new Error(payload.error || "Upload failed");
      }

      const payload = await response.json();
      setJob({ id: payload.jobId, status: "queued", progress: 0 });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed");
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <main className="min-h-screen bg-slate-950 text-slate-100">
      <section className="mx-auto flex w-full max-w-4xl flex-col gap-8 px-6 py-16">
        <header className="space-y-3">
          <p className="text-sm uppercase tracking-[0.3em] text-slate-400">
            Local AI Video Upscaler
          </p>
          <h1 className="text-4xl font-semibold md:text-5xl">
            Upgrade video quality to Full HD with Metal-accelerated AI
          </h1>
          <p className="max-w-2xl text-lg text-slate-300">
            Upload a video and the local worker will upscale it to at least 1080p
            while preserving aspect ratio. Quality is prioritized over speed.
          </p>
        </header>

        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-6">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <h2 className="text-xl font-semibold">Upload a video</h2>
              <p className="text-sm text-slate-400">
                Supported formats: mp4, mov, mkv, webm.
              </p>
            </div>
            <input
              type="file"
              accept="video/*"
              onChange={(event) => setFile(event.target.files?.[0] ?? null)}
              className="text-sm text-slate-200 file:mr-4 file:rounded-full file:border-0 file:bg-slate-100/10 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-slate-200 hover:file:bg-slate-100/20"
            />
          </div>

          <div className="mt-6 flex flex-wrap items-center gap-3">
            <button
              onClick={handleUpload}
              disabled={isUploading}
              className="rounded-full bg-blue-500 px-6 py-2 text-sm font-semibold text-white transition hover:bg-blue-400 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {isUploading ? "Uploading..." : "Start Upscale"}
            </button>
            {job && (
              <div className="text-sm text-slate-300">
                Job <span className="font-semibold">{job.id}</span>
              </div>
            )}
          </div>

          {error && (
            <p className="mt-4 rounded-lg border border-rose-500/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
              {error}
            </p>
          )}
        </div>

        {job && (
          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-6">
            <div className="flex flex-col gap-4">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold">Upscale status</h3>
                <span className="rounded-full border border-slate-700 px-3 py-1 text-xs uppercase tracking-widest text-slate-400">
                  {job.status}
                </span>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm text-slate-300">
                  <span>Progress</span>
                  <span>{Math.round(job.progress)}%</span>
                </div>
                <div className="h-2 w-full rounded-full bg-slate-800">
                  <div
                    className="h-2 rounded-full bg-blue-500 transition-all"
                    style={{ width: `${Math.min(job.progress, 100)}%` }}
                  />
                </div>
              </div>

              {job.status === "failed" && job.error && (
                <p className="rounded-lg border border-rose-500/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
                  {job.error}
                </p>
              )}

              {downloadUrl && (
                <div className="flex flex-col gap-4">
                  <video
                    controls
                    className="w-full rounded-xl border border-slate-800"
                    src={downloadUrl}
                  />
                  <a
                    href={downloadUrl}
                    className="inline-flex w-fit items-center justify-center rounded-full bg-emerald-500 px-5 py-2 text-sm font-semibold text-white transition hover:bg-emerald-400"
                  >
                    Download upscaled video
                  </a>
                </div>
              )}
            </div>
          </div>
        )}
      </section>
    </main>
  );
}
