import path from 'path';
import { fileURLToPath } from 'url';
import { defineConfig } from 'vite';

const root = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  root: path.join(root, 'web'),
  envDir: root,
  build: {
    outDir: path.join(root, 'dist'),
    emptyOutDir: true,
    target: 'safari16',
    // WKWebView treats <link rel="modulepreload"> as supported but never
    // finishes it, so the dynamic flavor import in showCamera never resolves.
    modulePreload: false,
    rollupOptions: {
      output: {
        inlineDynamicImports: true,
      },
    },
  },
});
