import fs from "fs/promises";
import { NextResponse } from "next/server";
import { createJob } from "@/lib/jobs";
import { ensureStorage, resolveStoragePath } from "@/lib/storage";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  await ensureStorage();
  const formData = await request.formData();
  const file = formData.get("file");

  if (!file || typeof file !== "object" || !("arrayBuffer" in file)) {
    return NextResponse.json({ error: "Missing file" }, { status: 400 });
  }

  const typedFile = file as File;
  const job = await createJob(typedFile.name || "upload.mp4");
  const buffer = Buffer.from(await typedFile.arrayBuffer());

  await fs.writeFile(resolveStoragePath(job.inputPath), buffer);

  return NextResponse.json({ jobId: job.id });
}
