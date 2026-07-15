/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  turbopack: {},
  // Fully static site (no SSR/API) -> export plain HTML into `out/`.
  // Deploys to any static host (Netlify, etc.) with no server runtime.
  output: "export",
  images: { unoptimized: true },
};

export default nextConfig;
