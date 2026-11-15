export const tokens = {
  color: {
    navy: "#07152c",
    navySoft: "#0b2245",
    blue: "#1657e8",
    blueDark: "#0b3fc0",
    blueSoft: "#eaf0ff",
    ink: "#10213b",
    muted: "#6b7a90",
    line: "#e3eaf4",
    bg: "#f5f7fb",
    success: "#0f9d70",
    successSoft: "#e5f8f1",
    warning: "#b45309",
    warningSoft: "#fff3e0",
    danger: "#d23b3b",
    white: "#ffffff",
  },
  radius: { sm: "8px", md: "12px", lg: "18px", xl: "26px", pill: "999px" },
  space: { 1: "4px", 2: "8px", 3: "12px", 4: "16px", 5: "20px", 6: "24px", 8: "32px" },
  font: {
    sans: "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
  },
  shadow: {
    soft: "0 10px 30px rgba(12, 31, 64, 0.08)",
    lifted: "0 22px 60px rgba(7, 21, 44, 0.22)",
  },
} as const;

export type ShareeTokens = typeof tokens;
