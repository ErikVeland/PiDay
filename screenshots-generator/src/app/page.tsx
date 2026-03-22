"use client";

import { toPng } from "html-to-image";
import { useRef, useEffect, useState, useCallback } from "react";

// ─── Ember palette ────────────────────────────────────────────────────────
// Extracted from AppTheme.swift — Ember light (signature) + dark (contrast)
const E = {
  // Light (parchment)
  bgLight: "#FCF3E8",
  bgLight2: "#FFF8F2",
  surfLight: "#FFFAF6",
  inkLight: "#2D180F",
  mutedLight: "rgba(45,24,15,0.45)",
  accent: "#D95C28",   // terracotta — rgb(0.851, 0.361, 0.157)
  rose: "#C73058",     // month — rgb(0.780, 0.188, 0.345)
  plum: "#902490",     // year — rgb(0.565, 0.157, 0.565)
  border: "rgba(223,200,189,0.55)",
  // Dark (contrast slides)
  bgDark: "#1A0E08",
  bgDark2: "#200F07",
  surfDark: "#2A1810",
  inkDark: "#F7EDE1",
  mutedDark: "rgba(247,237,225,0.45)",
  accentDark: "#F3733A",
};

// ─── Canvas / export sizes ────────────────────────────────────────────────
// Apple requires 1320×2868 for 6.9" iPhone (Pro Max). Design at this size,
// scale down for older devices during export.
const CW = 1320;
const CH = 2868;

const SIZES = [
  { label: '6.9" (2868)', w: 1320, h: 2868 },
  { label: '6.5" (2778)', w: 1284, h: 2778 },
  { label: '6.3" (2622)', w: 1206, h: 2622 },
  { label: '6.1" (2436)', w: 1125, h: 2436 },
] as const;

type SizeLabel = (typeof SIZES)[number]["label"];

// ─── Phone mockup constants ───────────────────────────────────────────────
// Pre-measured from mockup.png pixel layout.
const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

// ─── Phone mockup component ───────────────────────────────────────────────
function Phone({
  src, alt, style, className = "",
}: {
  src: string; alt: string; style?: React.CSSProperties; className?: string;
}) {
  return (
    <div
      className={className}
      style={{ position: "absolute", aspectRatio: `${MK_W}/${MK_H}`, ...style }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/mockup.png"
        alt=""
        style={{ display: "block", width: "100%", height: "100%" }}
        draggable={false}
      />
      <div
        style={{
          position: "absolute",
          left: `${SC_L}%`, top: `${SC_T}%`,
          width: `${SC_W}%`, height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
          overflow: "hidden",
          zIndex: 10,
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={src}
          alt={alt}
          style={{
            display: "block", width: "100%", height: "100%",
            objectFit: "cover", objectPosition: "top",
          }}
          draggable={false}
        />
      </div>
    </div>
  );
}

// ─── Caption component ────────────────────────────────────────────────────
// All sizes are proportional to canvasW so they stay correct at every export size.
function Caption({
  label, headline, dark = false, canvasW, style,
}: {
  label: string;
  headline: React.ReactNode;
  dark?: boolean;
  canvasW: number;
  style?: React.CSSProperties;
}) {
  const ink = dark ? E.inkDark : E.inkLight;
  const muted = dark ? E.mutedDark : E.mutedLight;
  return (
    <div style={style}>
      <div style={{
        fontSize: canvasW * 0.028, fontWeight: 600, color: muted,
        letterSpacing: "0.08em", textTransform: "uppercase" as const,
        marginBottom: canvasW * 0.018,
      }}>
        {label}
      </div>
      <div style={{
        fontSize: canvasW * 0.092, fontWeight: 900, color: ink, lineHeight: 1.05,
      }}>
        {headline}
      </div>
    </div>
  );
}

// ─── Slide 1 — Hero: Calendar heat map ───────────────────────────────────
function Slide1({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(160deg, ${E.bgLight} 0%, ${E.bgLight2} 55%, #FFF0E4 100%)`,
    }}>
      {/* Terracotta glow — top right */}
      <div style={{
        position: "absolute", top: -canvasW * 0.3, right: -canvasW * 0.25,
        width: canvasW * 1.0, height: canvasW * 1.0, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.accent}18 0%, transparent 70%)`,
      }} />
      {/* Rose glow — bottom left */}
      <div style={{
        position: "absolute", bottom: canvasH * 0.1, left: -canvasW * 0.3,
        width: canvasW * 0.8, height: canvasW * 0.8, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.rose}12 0%, transparent 70%)`,
      }} />
      {/* π watermark */}
      <div style={{
        position: "absolute", top: canvasH * 0.04, left: pad,
        fontSize: canvasW * 0.55, fontWeight: 900, color: `${E.accent}08`,
        lineHeight: 1, userSelect: "none" as const,
      }}>π</div>

      <Caption
        label="PiDay"
        headline={<>Find your<br />birthday in π.</>}
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      <Phone
        src="/screenshots/calendar.png"
        alt="Calendar heat map"
        style={{
          width: canvasW * 0.84,
          left: "50%", bottom: -canvasH * 0.01,
          transform: "translateX(-50%)",
        }}
      />
    </div>
  );
}

// ─── Slide 2 — Exact digit position ──────────────────────────────────────
function Slide2({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(170deg, #FFF8F2 0%, ${E.bgLight} 60%, #FDEBD8 100%)`,
    }}>
      <div style={{
        position: "absolute", bottom: canvasH * 0.1, right: -canvasW * 0.15,
        width: canvasW * 0.9, height: canvasW * 0.9, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.accent}1E 0%, transparent 65%)`,
      }} />
      <div style={{
        position: "absolute", top: canvasH * 0.2, left: -canvasW * 0.2,
        width: canvasW * 0.6, height: canvasW * 0.6, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.plum}10 0%, transparent 70%)`,
      }} />

      <Caption
        label="Your Digit"
        headline={<>Pinpointed<br />to the<br />exact digit.</>}
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      {/* Position callout badge */}
      <div style={{
        position: "absolute", top: canvasH * 0.44, left: pad,
        background: E.surfLight, border: `2px solid ${E.border}`,
        borderRadius: canvasW * 0.04,
        padding: `${canvasW * 0.022}px ${canvasW * 0.04}px`,
        boxShadow: `0 ${canvasW * 0.015}px ${canvasW * 0.05}px rgba(45,24,15,0.12)`,
      }}>
        <div style={{
          fontSize: canvasW * 0.022, fontWeight: 600, color: E.mutedLight,
          marginBottom: canvasW * 0.008, letterSpacing: "0.06em", textTransform: "uppercase" as const,
        }}>
          Position in π
        </div>
        <div style={{ fontSize: canvasW * 0.07, fontWeight: 900, color: E.accent, lineHeight: 1.1 }}>
          12,930,978
        </div>
      </div>

      <Phone
        src="/screenshots/canvas-ember.png"
        alt="Pi digits canvas"
        style={{ width: canvasW * 0.82, right: -canvasW * 0.05, bottom: -canvasH * 0.02 }}
      />
    </div>
  );
}

// ─── Slide 3 — Heat map explained (dark contrast) ────────────────────────
function Slide3({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(165deg, ${E.bgDark} 0%, #250E06 55%, ${E.bgDark2} 100%)`,
    }}>
      <div style={{
        position: "absolute", top: -canvasW * 0.3, right: -canvasW * 0.2,
        width: canvasW * 0.9, height: canvasW * 0.9, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.accent}20 0%, transparent 65%)`,
      }} />
      <div style={{
        position: "absolute", bottom: canvasH * 0.05, left: -canvasW * 0.2,
        width: canvasW * 0.7, height: canvasW * 0.7, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.rose}16 0%, transparent 70%)`,
      }} />

      <Caption
        label="Heat Map"
        headline={<>The earlier<br />it appears,<br />the hotter<br />it glows.</>}
        dark
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      {/* Heat level legend */}
      <div style={{
        position: "absolute", top: canvasH * 0.52, left: pad,
        display: "flex", flexDirection: "column" as const, gap: canvasW * 0.02,
      }}>
        {[
          { label: "Top 1,000",  heat: "#FF7A3A", bg: "rgba(107,26,8,0.8)" },
          { label: "Top 100K",   heat: "#F3A07A", bg: "rgba(74,18,5,0.8)" },
          { label: "Top 10M",    heat: "#C87060", bg: "rgba(50,16,8,0.8)" },
          { label: "Not found",  heat: "rgba(247,237,225,0.30)", bg: "rgba(42,24,16,0.8)" },
        ].map(({ label, heat, bg }) => (
          <div key={label} style={{ display: "flex", alignItems: "center", gap: canvasW * 0.028 }}>
            <div style={{
              width: canvasW * 0.068, height: canvasW * 0.068,
              borderRadius: canvasW * 0.014, background: bg,
              border: `2px solid ${heat}50`, flexShrink: 0,
            }} />
            <span style={{ fontSize: canvasW * 0.032, fontWeight: 700, color: heat }}>{label}</span>
          </div>
        ))}
      </div>

      <Phone
        src="/screenshots/calendar.png"
        alt="Calendar heat map"
        style={{ width: canvasW * 0.80, right: -canvasW * 0.05, bottom: -canvasH * 0.01 }}
      />
    </div>
  );
}

// ─── Slide 4 — Every format at once ──────────────────────────────────────
function Slide4({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(150deg, #FFF8F2 0%, ${E.bgLight} 50%, #FDECD6 100%)`,
    }}>
      <div style={{
        position: "absolute", top: canvasH * 0.1, left: -canvasW * 0.2,
        width: canvasW * 0.7, height: canvasW * 0.7, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.plum}0E 0%, transparent 70%)`,
      }} />
      <div style={{
        position: "absolute", bottom: canvasH * 0.15, right: -canvasW * 0.1,
        width: canvasW * 0.5, height: canvasW * 0.5, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.accent}12 0%, transparent 70%)`,
      }} />

      <Caption
        label="Smart Search"
        headline={<>Every format,<br />all at once.</>}
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      {/* Format pills */}
      <div style={{
        position: "absolute", top: canvasH * 0.37, right: pad,
        display: "flex", flexWrap: "wrap" as const, gap: canvasW * 0.022,
        maxWidth: canvasW * 0.52,
        justifyContent: "flex-end",
      }}>
        {["DD/MM/YYYY", "MM/DD/YYYY", "YYYYMMDD", "D/M/YYYY", "YY/MM/DD"].map((fmt) => (
          <div key={fmt} style={{
            background: E.surfLight,
            border: `1.5px solid ${E.border}`,
            borderRadius: canvasW * 0.025,
            padding: `${canvasW * 0.014}px ${canvasW * 0.026}px`,
            fontSize: canvasW * 0.026, fontWeight: 700,
            color: E.accent, letterSpacing: "0.04em",
          }}>
            {fmt}
          </div>
        ))}
      </div>

      <Phone
        src="/screenshots/canvas-frost.png"
        alt="Pi canvas with formats"
        style={{ width: canvasW * 0.80, left: -canvasW * 0.04, bottom: -canvasH * 0.01 }}
      />
    </div>
  );
}

// ─── Slide 5 — Free digit search ─────────────────────────────────────────
function Slide5({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(155deg, ${E.bgLight} 0%, #FFF8F2 45%, #FDEBD8 100%)`,
    }}>
      <div style={{
        position: "absolute", bottom: canvasH * 0.15, right: -canvasW * 0.15,
        width: canvasW * 0.65, height: canvasW * 0.65, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.rose}10 0%, transparent 70%)`,
      }} />

      <Caption
        label="Free Search"
        headline={<>Not just dates.<br />Any digits.</>}
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      {/* Result callout */}
      <div style={{
        position: "absolute", top: canvasH * 0.38, right: pad,
        background: E.surfLight, border: `2px solid ${E.border}`,
        borderRadius: canvasW * 0.04,
        padding: `${canvasW * 0.028}px ${canvasW * 0.04}px`,
        boxShadow: `0 ${canvasW * 0.018}px ${canvasW * 0.06}px rgba(45,24,15,0.10)`,
        maxWidth: canvasW * 0.48,
      }}>
        <div style={{
          fontSize: canvasW * 0.022, fontWeight: 700, color: E.mutedLight,
          marginBottom: canvasW * 0.01, letterSpacing: "0.04em",
        }}>
          Searching: 8008135
        </div>
        <div style={{ fontSize: canvasW * 0.026, fontWeight: 700, color: E.inkLight, marginBottom: canvasW * 0.005 }}>Found at digit</div>
        <div style={{ fontSize: canvasW * 0.062, fontWeight: 900, color: E.accent, lineHeight: 1.1 }}>
          23,749,231
        </div>
      </div>

      <Phone
        src="/screenshots/free-search.png"
        alt="Free digit search"
        style={{ width: canvasW * 0.80, left: -canvasW * 0.04, bottom: -canvasH * 0.01 }}
      />
    </div>
  );
}

// ─── Slide 6 — Themes (dark contrast) ────────────────────────────────────
function Slide6({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  const themes = [
    { name: "Frost",   color: "#2470C0", bg: "#EEF3FA" },
    { name: "Slate",   color: "#5AA0FF", bg: "#0D1221" },
    { name: "Ember",   color: "#D95C28", bg: "#FCF3E8" },
    { name: "Coppice", color: "#66C058", bg: "#172014" },
    { name: "Aurora",  color: "#59F2CC", bg: "#0A0F1C" },
    { name: "Custom",  color: "#A78BFA", bg: "#1A0F2E" },
  ];
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(170deg, #200E06 0%, ${E.bgDark} 50%, #1E0D06 100%)`,
    }}>
      <div style={{
        position: "absolute", top: -canvasW * 0.2, right: -canvasW * 0.15,
        width: canvasW * 0.8, height: canvasW * 0.8, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.accentDark}1E 0%, transparent 60%)`,
      }} />
      <div style={{
        position: "absolute", bottom: canvasH * 0.1, right: -canvasW * 0.1,
        width: canvasW * 0.55, height: canvasW * 0.55, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.rose}18 0%, transparent 70%)`,
      }} />

      <Caption
        label="Themes"
        headline={<>Your theme.<br />Your π.</>}
        dark
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      {/* Theme dots */}
      <div style={{
        position: "absolute", top: canvasH * 0.41, left: pad,
        display: "flex", gap: canvasW * 0.038, alignItems: "flex-start",
      }}>
        {themes.map(({ name, color, bg }) => (
          <div key={name} style={{ display: "flex", flexDirection: "column" as const, alignItems: "center", gap: canvasW * 0.014 }}>
            <div style={{
              width: canvasW * 0.088, height: canvasW * 0.088, borderRadius: "50%",
              background: bg,
              border: `${canvasW * 0.006}px solid ${color}`,
              boxShadow: `0 0 ${canvasW * 0.028}px ${color}55`,
            }} />
            <span style={{ fontSize: canvasW * 0.021, fontWeight: 700, color: "rgba(247,237,225,0.50)" }}>{name}</span>
          </div>
        ))}
      </div>

      <Phone
        src="/screenshots/prefs-themes.png"
        alt="Theme preferences"
        style={{
          width: canvasW * 0.82,
          left: "50%", bottom: -canvasH * 0.01,
          transform: "translateX(-50%)",
        }}
      />
    </div>
  );
}

// ─── Slide 7 — Share ─────────────────────────────────────────────────────
function Slide7({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(160deg, #FFF8F2 0%, ${E.bgLight} 55%, #FDEBD8 100%)`,
    }}>
      <div style={{
        position: "absolute", top: canvasH * 0.05, right: -canvasW * 0.1,
        width: canvasW * 0.75, height: canvasW * 0.75, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.accent}14 0%, transparent 65%)`,
      }} />
      <div style={{
        position: "absolute", bottom: canvasH * 0.2, left: -canvasW * 0.15,
        width: canvasW * 0.5, height: canvasW * 0.5, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.rose}0E 0%, transparent 70%)`,
      }} />

      <Caption
        label="Share"
        headline={<>Show your<br />place in π.</>}
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      <Phone
        src="/screenshots/share.png"
        alt="Share in iMessage"
        style={{
          width: canvasW * 0.84,
          left: "50%", bottom: -canvasH * 0.01,
          transform: "translateX(-50%)",
        }}
      />
    </div>
  );
}

// ─── Slide 8 — Typography ─────────────────────────────────────────────────
function Slide8({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(145deg, ${E.bgLight} 0%, #FFF8F0 60%, ${E.bgLight2} 100%)`,
    }}>
      <div style={{
        position: "absolute", top: -canvasW * 0.15, right: -canvasW * 0.1,
        width: canvasW * 0.6, height: canvasW * 0.6, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.plum}0E 0%, transparent 70%)`,
      }} />

      <Caption
        label="Typography"
        headline={<>Mono. Rounded.<br />Serif. Your call.</>}
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      {/* Font style cards */}
      <div style={{
        position: "absolute", top: canvasH * 0.37, right: pad,
        display: "flex", flexDirection: "column" as const, gap: canvasW * 0.024,
        maxWidth: canvasW * 0.44,
      }}>
        {[
          { name: "Rounded",   sample: "3.14159" },
          { name: "Monospace", sample: "3.14159" },
          { name: "Serif",     sample: "3.14159" },
          { name: "Menlo",     sample: "3.14159" },
        ].map(({ name, sample }) => (
          <div key={name} style={{
            background: E.surfLight,
            border: `1.5px solid ${E.border}`,
            borderRadius: canvasW * 0.03,
            padding: `${canvasW * 0.018}px ${canvasW * 0.032}px`,
            display: "flex", justifyContent: "space-between", alignItems: "center",
          }}>
            <span style={{ fontSize: canvasW * 0.027, fontWeight: 700, color: E.mutedLight }}>{name}</span>
            <span style={{ fontSize: canvasW * 0.034, fontWeight: 700, color: E.accent }}>{sample}</span>
          </div>
        ))}
      </div>

      <Phone
        src="/screenshots/prefs-typography.png"
        alt="Typography preferences"
        style={{ width: canvasW * 0.80, left: -canvasW * 0.04, bottom: -canvasH * 0.01 }}
      />
    </div>
  );
}

// ─── Slide 9 — Pi Day (dark contrast) ────────────────────────────────────
function Slide9({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(170deg, ${E.bgDark} 0%, #280B04 60%, ${E.bgDark2} 100%)`,
    }}>
      {/* Large π watermark */}
      <div style={{
        position: "absolute", bottom: canvasH * 0.12, right: -canvasW * 0.08,
        fontSize: canvasW * 0.72, fontWeight: 900, color: `${E.accentDark}09`,
        lineHeight: 1, userSelect: "none" as const,
      }}>π</div>
      <div style={{
        position: "absolute", top: -canvasW * 0.2, left: -canvasW * 0.1,
        width: canvasW * 0.8, height: canvasW * 0.8, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.accent}1E 0%, transparent 65%)`,
      }} />

      <Caption
        label="Pi Day"
        headline={<>March 14th<br />is Pi Day.<br />When's yours?</>}
        dark
        canvasW={canvasW}
        style={{ position: "absolute", top: canvasH * 0.078, left: pad, right: pad }}
      />

      {/* 3.14 callout */}
      <div style={{
        position: "absolute", top: canvasH * 0.53, left: pad,
        background: `rgba(242,115,58,0.10)`,
        border: `2px solid ${E.accentDark}38`,
        borderRadius: canvasW * 0.04,
        padding: `${canvasW * 0.022}px ${canvasW * 0.04}px`,
      }}>
        <div style={{ fontSize: canvasW * 0.076, fontWeight: 900, color: E.accentDark, lineHeight: 1.05 }}>
          3.14159...
        </div>
        <div style={{
          fontSize: canvasW * 0.026, fontWeight: 600,
          color: "rgba(247,237,225,0.50)", marginTop: canvasW * 0.01,
        }}>
          5 billion digits and counting.
        </div>
      </div>

      <Phone
        src="/screenshots/canvas-ember.png"
        alt="Pi canvas"
        style={{ width: canvasW * 0.80, right: -canvasW * 0.05, bottom: -canvasH * 0.01 }}
      />
    </div>
  );
}

// ─── Slide 10 — And so much more ─────────────────────────────────────────
function Slide10({ canvasW, canvasH }: { canvasW: number; canvasH: number }) {
  const pad = canvasW * 0.09;
  const features = [
    "Calendar heat map", "5 billion digits searched",
    "Multiple date formats", "Free digit search",
    "6 beautiful themes", "4 font styles", "5 digit sizes",
    "Lock screen widgets", "Home screen widgets",
    "Share your position", "Saved dates",
    "Annual Pi Day reminder", "Swipe navigation",
    "1-based & 0-based index",
  ];
  return (
    <div style={{
      width: canvasW, height: canvasH, position: "relative", overflow: "hidden",
      background: `linear-gradient(155deg, #FFF8F2 0%, ${E.bgLight} 55%, #FDEBD8 100%)`,
      display: "flex", flexDirection: "column" as const,
      alignItems: "center", justifyContent: "flex-start",
      paddingTop: canvasH * 0.10,
    }}>
      {/* Blobs */}
      <div style={{
        position: "absolute", top: -canvasW * 0.25, right: -canvasW * 0.2,
        width: canvasW * 0.8, height: canvasW * 0.8, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.accent}14 0%, transparent 65%)`,
      }} />
      <div style={{
        position: "absolute", bottom: -canvasW * 0.1, left: -canvasW * 0.15,
        width: canvasW * 0.7, height: canvasW * 0.7, borderRadius: "50%",
        background: `radial-gradient(circle, ${E.plum}0C 0%, transparent 70%)`,
      }} />

      {/* App icon */}
      <div style={{
        width: canvasW * 0.24, height: canvasW * 0.24,
        borderRadius: canvasW * 0.054, overflow: "hidden",
        boxShadow: `0 ${canvasW * 0.02}px ${canvasW * 0.07}px rgba(45,24,15,0.22)`,
        flexShrink: 0, marginBottom: canvasH * 0.042, zIndex: 1,
      }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/app-icon.png" alt="PiDay" style={{ width: "100%", height: "100%", display: "block" }} />
      </div>

      {/* Headline */}
      <div style={{
        fontSize: canvasW * 0.092, fontWeight: 900, color: E.inkLight,
        lineHeight: 1.05, textAlign: "center" as const,
        marginBottom: canvasH * 0.055, zIndex: 1,
      }}>
        And so<br />much more.
      </div>

      {/* Feature pills */}
      <div style={{
        display: "flex", flexWrap: "wrap" as const, gap: canvasW * 0.022,
        justifyContent: "center", maxWidth: canvasW * 0.88, zIndex: 1,
        paddingLeft: pad, paddingRight: pad,
      }}>
        {features.map((f) => (
          <div key={f} style={{
            background: E.surfLight,
            border: `1.5px solid ${E.border}`,
            borderRadius: canvasW * 0.055,
            padding: `${canvasW * 0.016}px ${canvasW * 0.036}px`,
            fontSize: canvasW * 0.028, fontWeight: 700, color: E.inkLight,
            whiteSpace: "nowrap" as const,
          }}>
            {f}
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Slide registry ───────────────────────────────────────────────────────
const SLIDES = [
  { id: "01-hero",       label: "Hero",       Component: Slide1 },
  { id: "02-position",   label: "Position",   Component: Slide2 },
  { id: "03-heatmap",    label: "Heat Map",   Component: Slide3 },
  { id: "04-formats",    label: "Formats",    Component: Slide4 },
  { id: "05-search",     label: "Free Search",Component: Slide5 },
  { id: "06-themes",     label: "Themes",     Component: Slide6 },
  { id: "07-share",      label: "Share",      Component: Slide7 },
  { id: "08-typography", label: "Typography", Component: Slide8 },
  { id: "09-piday",      label: "Pi Day",     Component: Slide9 },
  { id: "10-more",       label: "More",       Component: Slide10 },
];

// ─── ScreenshotPreview ────────────────────────────────────────────────────
// Each card scales the 1320×2868 canvas to fit a fixed-width preview box,
// then provides a hover export button.
function ScreenshotPreview({
  slide, index, exportSize, onExportSingle,
}: {
  slide: (typeof SLIDES)[number];
  index: number;
  exportSize: { w: number; h: number };
  onExportSingle: (index: number) => Promise<void>;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      setScale(el.clientWidth / CW);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const handleExport = useCallback(async () => {
    setExporting(true);
    try {
      await onExportSingle(index);
    } finally {
      setExporting(false);
    }
  }, [index, onExportSingle]);

  const { Component } = slide;

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      {/* Card */}
      <div
        ref={containerRef}
        style={{ width: "100%", position: "relative", borderRadius: 12, overflow: "hidden", cursor: "pointer", boxShadow: "0 2px 16px rgba(0,0,0,0.12)" }}
        onClick={handleExport}
        title="Click to export"
      >
        {/* Scaled preview — height is computed from aspect ratio */}
        <div style={{ width: "100%", height: Math.round((CW / CW) * CH * scale), position: "relative" }}>
          <div style={{ position: "absolute", top: 0, left: 0, transformOrigin: "top left", transform: `scale(${scale})`, width: CW, height: CH, fontFamily: "inherit" }}>
            <Component canvasW={CW} canvasH={CH} />
          </div>
        </div>
        {/* Hover overlay */}
        <div style={{
          position: "absolute", inset: 0,
          background: "rgba(0,0,0,0)",
          display: "flex", alignItems: "center", justifyContent: "center",
          opacity: 0, transition: "opacity 0.15s",
        }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLDivElement).style.opacity = "1"; (e.currentTarget as HTMLDivElement).style.background = "rgba(0,0,0,0.35)"; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLDivElement).style.opacity = "0"; (e.currentTarget as HTMLDivElement).style.background = "rgba(0,0,0,0)"; }}
        >
          <div style={{
            background: "rgba(255,255,255,0.92)", borderRadius: 8,
            padding: "6px 14px", fontSize: 12, fontWeight: 700,
            color: "#1a1a1a",
          }}>
            {exporting ? "Exporting…" : "Export PNG"}
          </div>
        </div>
      </div>
      {/* Label */}
      <div style={{ fontSize: 11, fontWeight: 600, color: "#888", textAlign: "center", letterSpacing: "0.04em" }}>
        {slide.id} · {slide.label}
      </div>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────
export default function ScreenshotsPage() {
  const [sizeLabel, setSizeLabel] = useState<SizeLabel>('6.9" (2868)');
  const [exportingAll, setExportingAll] = useState(false);
  const offscreenRefs = useRef<(HTMLDivElement | null)[]>([]);

  const activeSize = SIZES.find((s) => s.label === sizeLabel) ?? SIZES[0];

  // Export a single slide at the chosen resolution.
  // WHY double-call: the first toPng warms up lazy-loaded fonts & images;
  // the second produces a clean render. Without this, exports are blank.
  const exportSlide = useCallback(async (index: number) => {
    const el = offscreenRefs.current[index];
    if (!el) return;
    const slide = SLIDES[index];
    const { w, h } = activeSize;

    // Temporarily bring on-screen for capture (html-to-image needs layout)
    el.style.left = "0px";
    el.style.opacity = "1";
    el.style.zIndex = "-1";

    try {
      const opts = { width: w, height: h, pixelRatio: 1, cacheBust: true };
      await toPng(el, opts); // warm-up call
      const dataUrl = await toPng(el, opts); // real capture

      // Scale to target if different from design size
      let finalUrl = dataUrl;
      if (w !== CW || h !== CH) {
        const img = new Image();
        await new Promise<void>((res) => { img.onload = () => res(); img.src = dataUrl; });
        const canvas = document.createElement("canvas");
        canvas.width = w; canvas.height = h;
        const ctx = canvas.getContext("2d");
        if (ctx) { ctx.drawImage(img, 0, 0, w, h); }
        finalUrl = canvas.toDataURL("image/png");
      }

      const a = document.createElement("a");
      a.href = finalUrl;
      a.download = `${slide.id}-${slide.label.toLowerCase().replace(/\s+/g, "-")}-${w}x${h}.png`;
      a.click();
    } finally {
      el.style.left = "-9999px";
      el.style.opacity = "";
      el.style.zIndex = "";
    }
  }, [activeSize]);

  const exportAll = useCallback(async () => {
    setExportingAll(true);
    for (let i = 0; i < SLIDES.length; i++) {
      await exportSlide(i);
      await new Promise((r) => setTimeout(r, 300));
    }
    setExportingAll(false);
  }, [exportSlide]);

  return (
    <div style={{ minHeight: "100vh", background: "#F2F2F7", fontFamily: "inherit" }}>
      {/* Toolbar */}
      <div style={{
        position: "sticky", top: 0, zIndex: 100,
        background: "rgba(255,255,255,0.92)", backdropFilter: "blur(12px)",
        borderBottom: "1px solid rgba(0,0,0,0.08)",
        padding: "12px 24px",
        display: "flex", alignItems: "center", gap: 16, flexWrap: "wrap" as const,
      }}>
        <div style={{ fontWeight: 800, fontSize: 15, color: "#1a1a1a", letterSpacing: "-0.01em" }}>
          PiDay · App Store Screenshots
        </div>
        <div style={{ flex: 1 }} />

        {/* Size picker */}
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ fontSize: 12, fontWeight: 600, color: "#666" }}>Size</span>
          <select
            value={sizeLabel}
            onChange={(e) => setSizeLabel(e.target.value as SizeLabel)}
            style={{
              border: "1.5px solid #D1D1D6", borderRadius: 8,
              padding: "4px 8px", fontSize: 13, fontWeight: 600,
              background: "#fff", cursor: "pointer",
            }}
          >
            {SIZES.map((s) => (
              <option key={s.label} value={s.label}>{s.label} — {s.w}×{s.h}</option>
            ))}
          </select>
        </div>

        {/* Export all */}
        <button
          onClick={exportAll}
          disabled={exportingAll}
          style={{
            background: E.accent, color: "#fff",
            border: "none", borderRadius: 8,
            padding: "7px 16px", fontSize: 13, fontWeight: 700,
            cursor: exportingAll ? "not-allowed" : "pointer",
            opacity: exportingAll ? 0.6 : 1,
          }}
        >
          {exportingAll ? "Exporting all…" : "Export all (10)"}
        </button>
      </div>

      {/* Grid */}
      <div style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
        gap: 24, padding: "32px 24px",
        maxWidth: 1400, margin: "0 auto",
      }}>
        {SLIDES.map((slide, i) => (
          <ScreenshotPreview
            key={slide.id}
            slide={slide}
            index={i}
            exportSize={activeSize}
            onExportSingle={exportSlide}
          />
        ))}
      </div>

      {/* Offscreen render farm — positioned far left, actual resolution */}
      {SLIDES.map((slide, i) => {
        const { Component } = slide;
        return (
          <div
            key={slide.id}
            ref={(el) => { offscreenRefs.current[i] = el; }}
            style={{
              position: "absolute", left: "-9999px", top: 0,
              width: CW, height: CH,
              fontFamily: "Nunito, system-ui, sans-serif",
              overflow: "hidden",
            }}
          >
            <Component canvasW={CW} canvasH={CH} />
          </div>
        );
      })}
    </div>
  );
}
