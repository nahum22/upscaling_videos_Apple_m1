import fs from "fs/promises";
import path from "path";
import { NextResponse } from "next/server";
import { STORAGE_PATHS } from "@/lib/storage";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const entries = await fs.readdir(STORAGE_PATHS.jobs);
    const jobFiles = entries.filter((entry) => entry.endsWith(".json"));

    if (jobFiles.length === 0) {
      return NextResponse.json({ error: "No jobs found" }, { status: 404 });
    }

    const stats = await Promise.all(
      jobFiles.map(async (file) => {
        const fullPath = path.join(STORAGE_PATHS.jobs, file);
        const stat = await fs.stat(fullPath);
        return { file, fullPath, mtimeMs: stat.mtimeMs };
      })
    );

    stats.sort((a, b) => b.mtimeMs - a.mtimeMs);
    const latest = stats[0];
    const raw = await fs.readFile(latest.fullPath, "utf-8");
    const job = JSON.parse(raw);

    return NextResponse.json(job);
  } catch {
    return NextResponse.json({ error: "No jobs found" }, { status: 404 });
  }
}
