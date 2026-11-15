import Link from "next/link";
import { Badge, Button, Card, SectionTitle } from "@sharee/ui";
import { SearchBox } from "@/components/SearchBox";
import { money, routePresets } from "@/lib/sharee";

const features = [
  { icon: "✓", title: "Tài xế KYC", text: "CCCD, GPLX, giấy tờ xe và selfie được duyệt thủ công." },
  { icon: "⌂", title: "Escrow an toàn", text: "Tiền chỉ được chuyển cho tài xế sau khi chuyến hoàn tất." },
  { icon: "⚖", title: "Khiếu nại minh bạch", text: "Khóa tiền, xem bằng chứng hai bên và xử lý bởi admin." },
  { icon: "★", title: "Uy tín thật", text: "Điểm tín nhiệm từ đánh giá, tỷ lệ hoàn thành và số chuyến." },
];

export default function HomePage() {
  return (
    <>
      <section className="home-hero" id="tim-chuyen">
        <div className="sh-container-wide hero-grid">
          <div className="hero-copy">
            <Badge tone="blue">NỀN TẢNG ĐI CHUNG AN TOÀN</Badge>
            <h1>
              Đi chung một chuyến,
              <br />
              <span>an tâm trọn hành trình.</span>
            </h1>
            <p>
              Đặt ghế nhanh, tài xế KYC, tiền được giữ trong escrow và theo dõi trực tiếp
              trên một nền tảng minh bạch.
            </p>
            <div className="hero-stats">
              <div>
                <strong>100%</strong>
                <span>Tài xế KYC</span>
              </div>
              <div>
                <strong>Escrow</strong>
                <span>Bảo vệ thanh toán</span>
              </div>
              <div>
                <strong>4.9</strong>
                <span>Đánh giá thật</span>
              </div>
            </div>
            <div className="hero-trust">
              <span>✓ Xác thực CCCD &amp; GPLX</span>
              <span>✓ Tiền giữ đến khi hoàn tất</span>
              <span>✓ Hỗ trợ tranh chấp</span>
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
