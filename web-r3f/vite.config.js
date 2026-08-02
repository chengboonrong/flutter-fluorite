import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// `base: './'` keeps the built bundle relative, so `dist/` can be opened from
// any path (GitHub Pages, a sub-directory, or a plain static server) exactly
// like the dependency-free build in ../web.
export default defineConfig({
  base: './',
  plugins: [react()],
  build: { outDir: 'dist', chunkSizeWarningLimit: 1500 },
});
