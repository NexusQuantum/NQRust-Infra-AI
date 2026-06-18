/** NQRust brand overlay (NexusQuantum) — applied over upstream claw-ui by
 * scripts/apply-theme.sh. NQRust is the DEFAULT brand; the matching CSS lives in
 * globals.css under :root[data-brand="nqrust"] (appended by the same script).
 *
 * This file is owned by the NQRust-Infra-AI repo (web-ui-theme/) so the brand
 * survives upstream removing its own brand. Switch back to the upstream look at
 * runtime with NEXT_PUBLIC_BRAND=rantaiclaw. */

export type BrandId = "rantaiclaw" | "nqrust";

export interface Brand {
  id: BrandId;
  /** Short brand name. */
  name: string;
  /** Product name shown in titles / login. */
  productName: string;
  /** Wordmark split into [base, accent] — the accent half is brand-colored. */
  wordmark: [string, string];
  /** Small sub-label under the wordmark. */
  sub: string;
  tagline: string;
  /** Square mark used in the rail + login. */
  logo: string;
  favicon: string;
  /** Default color scheme for this brand. */
  theme: "dark" | "light";
}

const BRANDS: Record<BrandId, Brand> = {
  rantaiclaw: {
    id: "rantaiclaw",
    name: "RantaiClaw",
    productName: "RantaiClaw Console",
    wordmark: ["Rantai", "Claw"],
    sub: "Console",
    tagline: "Chat with your agent. Watch it work.",
    logo: "/rantaiclaw-mark.png",
    favicon: "/favicon-32x32.png",
    theme: "dark",
  },
  nqrust: {
    id: "nqrust",
    name: "NQRust",
    productName: "NQRust Console",
    wordmark: ["NQ", "Rust"],
    sub: "Console",
    tagline: "Your infrastructure agent console.",
    logo: "/nqrust-mark.svg",
    favicon: "/nqrust-mark.svg",
    theme: "light",
  },
};

// NQRust is the default. Set NEXT_PUBLIC_BRAND=rantaiclaw to use the upstream look.
const SELECTED: BrandId = process.env.NEXT_PUBLIC_BRAND === "rantaiclaw" ? "rantaiclaw" : "nqrust";

export const brand: Brand = BRANDS[SELECTED];
