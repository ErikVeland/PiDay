import type { Metadata } from "next";
import { Nunito } from "next/font/google";
import "./globals.css";

// Nunito is the closest Google Font match for SF Rounded —
// same circular letter forms and friendly rounded terminals.
const nunito = Nunito({
  subsets: ["latin"],
  weight: ["400", "600", "700", "800", "900"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "PiDay — App Store Screenshots",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={nunito.className}>
      <body>{children}</body>
    </html>
  );
}
