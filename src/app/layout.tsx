import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Metal AI Video Upscaler",
  description: "Local Metal-accelerated AI video upscaler for Full HD output.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
