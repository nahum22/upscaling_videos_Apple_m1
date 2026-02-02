import fs from "fs/promises";
import { createReadStream } from "fs";
import { Readable } from "stream";
import { NextResponse } from "next/server";
import { jobFilePath, resolveStoragePath } from "@/lib/storage";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const id = searchParams.get("id");

  if (!id) {
    return NextResponse.json({ error: "Missing id" }, { status: 400 });
  }

  try {
    const raw = await fs.readFile(jobFilePath(id), "utf-8");
    const job = JSON.parse(raw) as { outputPath?: string; status?: string };

    if (!job.outputPath || job.status !== "completed") {
      return NextResponse.json({ error: "Output not ready" }, { status: 400 });
    }

    const outputPath = resolveStoragePath(job.outputPath);
    const stat = await fs.stat(outputPath);
    const stream = createReadStream(outputPath);
    const body = Readable.toWeb(stream) as ReadableStream;

    return new NextResponse(body, {
      headers: {
        "Content-Type": "video/mp4",
        "Content-Length": stat.size.toString(),
        "Content-Disposition": `attachment; filename="upscaled-${id}.mp4"`,
      },
    });
  } catch {
    return NextResponse.json({ error: "Output not found" }, { status: 404 });
  }
}
