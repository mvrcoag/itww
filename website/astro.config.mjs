import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://mvrcoag.github.io",
  base: process.env.ASTRO_BASE || "/",
  devToolbar: { enabled: false },
});
