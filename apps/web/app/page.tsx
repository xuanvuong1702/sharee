import Link from "next/link";
import { Badge, Button, Card, SectionTitle } from "@sharee/ui";
import { SearchBox } from "@/components/SearchBox";
import { money, routePresets } from "@/lib/sharee";

const features = [
  { icon: "✓", title: "Tài xế xác thực", text: "Hồ sơ, GPLX và phương tiện được kiểm duyệt." },
  { icon: "₫", title: "Giá minh bạch", text: "Biết trước chi phí, không phụ phí ẩn." },
  { icon: "⌖", title: "Theo dõi trực tiếp", text: "Xem vị trí và ETA trên bản đồ." },
  { icon: "♥", title: "Tip tài xế", text: "Ủng hộ tài xế bằng VietQR hoặc tiền mặt." },
];

export default function HomePage() {
  return (
    <>
      <section className="home-hero" id="tim-chuyen">
        <div className="sh-container-wide hero-grid">
          <div className="hero-copy">
            <Badge tone="blue">CARPOOLING &amp; DAILY SHUTTLE</Badge>
            <h1>
              Đi chung một chuyến,
              <br />
              chia sẻ một hành trình.
            </h1>
            <p>
              Đặt ghế nhanh, tài xế xác thực, theo dõi trực tiếp và tip tài xế ngay trên một nền tảng.
            </p>
            <div className="hero-stats">
              <div>
                <strong>10K+</strong>
                <span>Hành khách</span>
              </div>
              <div>
                <strong>4.9</strong>
                <span>Đánh giá</span>
              </div>
              <div>
                <strong>24/7</strong>
                <span>Hỗ trợ</span>
              </div>
            </div>
            <div className="hero-actions">
              <a
                className="sh-btn sh-btn-secondary sh-btn-lg"
                href="https://github.com/xuanvuong1702/sharee/releases/latest"
                target="_blank"
                rel="noreferrer"
              >
                Tải app Android
              </a>
              <Link href="/login/" className="hero-link">
                Đăng nhập web →
              </Link>
            </div>
          </div>
          <SearchBox />
        </div>
      </section>

      <div className="sh-container-wide">
        <SectionTitle
          eyebrow="Tuyến phổ biến"
          title="Đi đâu hôm nay?"
          action={<span className="muted-small">Giá từ 90.000đ</span>}
        />
        <div className="routes-grid">
          {routePresets.map((route, index) => (
            <Link
              key={route.id}
              href={`/search/?route=${route.id}&fromLat=${route.fromLat}&fromLng=${route.fromLng}&toLat=${route.toLat}&toLng=${route.toLng}&fromLabel=${encodeURIComponent(route.fromLabel)}&toLabel=${encodeURIComponent(route.toLabel)}&seats=1`}
            >
              <Card className="route-card">
                <div className="route-icon">{index === 0 ? "🚗" : "✈"}</div>
                <Badge tone={index === 0 ? "blue" : "green"}>
                  {index === 0 ? "Phổ biến" : "Sân bay"}
                </Badge>
                <h3>{route.name}</h3>
                <p>{route.fromLabel.split(",")[0]} → {route.toLabel.split(",")[0]}</p>
                <strong>Từ {money(index === 0 ? 180000 : 90000)}</strong>
              </Card>
            </Link>
          ))}
          <Link href="/account/">
            <Card className="route-card">
              <div className="route-icon">↺</div>
              <Badge tone="amber">Daily</Badge>
              <h3>Daily shuttle</h3>
              <p>Tuyến cố định hằng ngày</p>
              <strong>Từ 15.000đ</strong>
            </Card>
          </Link>
          <a
            href="https://github.com/xuanvuong1702/sharee/releases/latest"
            target="_blank"
            rel="noreferrer"
          >
            <Card className="route-card">
              <div className="route-icon">↓</div>
              <Badge tone="gray">Mobile app</Badge>
              <h3>Tải Sharee APK</h3>
              <p>Android · bản mới nhất</p>
              <strong>Tải miễn phí</strong>
            </Card>
          </a>
        </div>

        <SectionTitle eyebrow="Vì sao chọn Sharee?" title="An toàn, minh bạch, tiện lợi" />
        <div className="features-grid">
          {features.map((feature) => (
            <Card key={feature.title} className="feature-card">
              <span className="feature-icon">{feature.icon}</span>
              <h3>{feature.title}</h3>
              <p>{feature.text}</p>
            </Card>
          ))}
        </div>

        <section className="tip-banner">
          <div>
            <Badge tone="green">Tính năng mới</Badge>
            <h2>Tip tài xế bằng VietQR</h2>
            <p>
              Tài xế cấu hình tài khoản một lần, khách quét QR chuyển tip trực tiếp. Có thông báo,
              xác nhận và thống kê thu nhập.
            </p>
          </div>
          <Button variant="secondary" size="lg" disabled>
            Có trên app
          </Button>
        </section>

        <section className="cta-banner">
          <div>
            <h2>Có chuyến đi trống?</h2>
            <p>Đăng chuyến miễn phí, chia sẻ chi phí và kết nối với hành khách.</p>
          </div>
          <a className="sh-btn sh-btn-ghost sh-btn-lg" href="https://github.com/xuanvuong1702/sharee/releases/latest" target="_blank" rel="noreferrer">
            Tải app để đăng chuyến
          </a>
        </section>
      </div>
    </>
  );
}
