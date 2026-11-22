import type { Metadata } from "next";
import "@sharee/design-tokens/tokens.css";
import "leaflet/dist/leaflet.css";
import "./globals.css";
import { AuthProvider } from "@/components/AuthProvider";
import { SiteHeader } from "@/components/SiteHeader";
import { SiteFooter } from "@/components/SiteFooter";

export const metadata: Metadata = {
  title: "Sharee — Đi chung, đi xa hơn",
  description:
    "Đặt chuyến carpooling và daily shuttle tại Việt Nam. Giá minh bạch, tài xế xác thực, theo dõi trực tiếp, tip tài xế bằng VietQR.",
  keywords: ["sharee", "carpooling", "đi chung", "daily shuttle", "xe ghép", "Hà Nội", "Hải Phòng"],
  openGraph: {
    title: "Sharee — Đi chung, đi xa hơn",
    description: "Carpooling và daily shuttle minh bạch, an toàn, tiện lợi.",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body>
        <AuthProvider>
          <SiteHeader />
          <main>{children}</main>
          <SiteFooter />
        </AuthProvider>
      </body>
    </html>
  );
}
