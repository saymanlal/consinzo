export const DESIGN_TOKENS = {
  brand: {
    name: "CONSINZO",
    positioning: "The Engineering Platform",
    statement: "Build. Test. Break. Master.",
  },
  palette: {
    light: {
      canvas: "#FAFAFA",
      surface: "#FFFFFF",
      surfaceMuted: "#F4F4F5",
      border: "#E4E4E7",
      borderStrong: "#D4D4D8",
      ink: "#09090B",
      inkMuted: "#52525B",
      inkSubtle: "#71717A",
      accent: "#0F172A",
      accentText: "#FFFFFF",
      brandBlue: "#1D4ED8",
      success: "#15803D",
      warning: "#B45309",
      danger: "#B91C1C",
    },
    ide: {
      canvas: "#0C0E12",
      surface: "#12151C",
      border: "#232834",
      ink: "#E5E7EB",
      inkMuted: "#9CA3AF",
    },
  },
  typography: {
    sans: "Inter, ui-sans-serif, system-ui, sans-serif",
    mono: "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace",
  },
} as const;
