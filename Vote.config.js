import { defineConfig } from "vite";

export default defineConfig({
  server: {i
    host: true,
    port: 5173
  },

  build: {
    target: "esnext",
    outDir: "dist"
  },

  define: {
    global: "globalThis"
  }
});
