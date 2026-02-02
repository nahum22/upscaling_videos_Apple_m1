import fs from "fs/promises";
import path from "path";

const STORAGE_ROOT = process.env.STORAGE_ROOT
  ? path.resolve(process.env.STORAGE_ROOT)
  : path.join(process.cwd(), "storage");

export const STORAGE_PATHS = {
  root: STORAGE_ROOT,
  uploads: path.join(STORAGE_ROOT, "uploads"),
  outputs: path.join(STORAGE_ROOT, "outputs"),
  jobs: path.join(STORAGE_ROOT, "jobs"),
  tmp: path.join(STORAGE_ROOT, "tmp"),
};

export async function ensureStorage() {
  await Promise.all(
    Object.values(STORAGE_PATHS).map((dir) => fs.mkdir(dir, { recursive: true }))
  );
}

export function jobFilePath(jobId: string) {
  return path.join(STORAGE_PATHS.jobs, `${jobId}.json`);
}

export function relativeOutputPath(jobId: string) {
  return path.join("outputs", `${jobId}.mp4`);
}

export function relativeUploadPath(jobId: string, originalName: string) {
  const safeName = originalName.replace(/[^a-zA-Z0-9._-]/g, "_");
  return path.join("uploads", `${jobId}-${safeName}`);
}

export function resolveStoragePath(relativePath: string) {
  return path.join(STORAGE_PATHS.root, relativePath);
}
