import fs from "fs/promises";
import crypto from "crypto";
import { ensureStorage, jobFilePath, relativeOutputPath, relativeUploadPath } from "./storage";

export type JobStatus = "queued" | "processing" | "completed" | "failed";

export interface UpscaleJob {
  id: string;
  status: JobStatus;
  progress: number;
  inputPath: string;
  outputPath: string;
  originalName: string;
  error?: string;
  createdAt: string;
  updatedAt: string;
}

export async function createJob(originalName: string) {
  await ensureStorage();
  const id = crypto.randomUUID();
  const inputPath = relativeUploadPath(id, originalName);
  const outputPath = relativeOutputPath(id);
  const now = new Date().toISOString();

  const job: UpscaleJob = {
    id,
    status: "queued",
    progress: 0,
    inputPath,
    outputPath,
    originalName,
    createdAt: now,
    updatedAt: now,
  };

  await fs.writeFile(jobFilePath(id), JSON.stringify(job, null, 2));
  return job;
}

export async function readJob(jobId: string) {
  const raw = await fs.readFile(jobFilePath(jobId), "utf-8");
  return JSON.parse(raw) as UpscaleJob;
}
