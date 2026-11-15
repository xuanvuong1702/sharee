import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  transpilePackages: ["@sharee/ui", "@sharee/api-client", "@sharee/design-tokens"],
};

export default nextConfig;
