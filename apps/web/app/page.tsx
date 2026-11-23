import Link from "next/link";
import { Badge, Card, SectionTitle } from "@sharee/ui";
import { SearchBox } from "@/components/SearchBox";
import { money } from "@/lib/sharee";

const categories = [
  { icon: "↗", label: "Đi chung", href: "/#chuyen-noi-bat" },
  { icon: "◉", label: "Đặt xe", href: "/ride/" },
  { icon: "✈", label: "Sân bay", href: "/nearby/" },
  { icon: "▤", label: "Daily", href: "/daily/" },
  { icon: "⌂", label: "Đi tỉnh", href: "/#diem-den" },
  { icon: "♧", label: "Đưa đón", href: "/nearby/" },
];

const featured = [
  {
    title: "Hà Nội → Hải Phòng",
    detail: "Bến xe Mỹ Đình · Lạch Tray",
    meta: "2 giờ 30 · Khởi hành linh hoạt",
    price: 180000,
    image: "/images/vietnam-road.jpg",
    tag: "Phổ biến",
    href: "/search/?route=hanoi-haiphong&fromLat=21.0285&fromLng=105.7749&toLat=20.8449&toLng=106.6881&fromLabel=B%E1%BA%BFn%20xe%20M%E1%BB%B9%20%C4%90%C3%ACnh%2C%20H%C3%A0%20N%E1%BB%99i&toLabel=L%E1%BA%A1ch%20Tray%2C%20H%E1%BA%A3i%20Ph%C3%B2ng&seats=1",
  },
  {
    title: "Hà Nội → Nội Bài",
    detail: "Sân bay Nội Bài · Đón tận nơi",
    meta: "45 phút · Xe 4 chỗ",
    price: 90000,
    image: "/images/hanoi.jpg",
    tag: "Sân bay",
    href: "/search/?route=hanoi-noibai&fromLat=21.0285&fromLng=105.7749&toLat=21.2187&toLng=105.7999&fromLabel=B%E1%BA%BFn%20xe%20M%E1%BB%B9%20%C4%90%C3%ACnh%2C%20H%C3%A0%20N%E1%BB%99i&toLabel=S%C3%A2n%20bay%20N%E1%BB%99i%20B%C3%A0i&seats=1",
  },
  {
    title: "Hà Nội → Hạ Long",
    detail: "Vincom Bà Triệu · Bãi Cháy",
    meta: "3 giờ · Xe 7 chỗ",
    price: 220000,
    image: "/images/vietnam-city.jpg",
    tag: "Cuối tuần",
    href: "/nearby/",
  },
];

const destinations = [
  { name: "Hà Nội", sub: "Phố cổ, Hồ Tây", image: "/images/hanoi.jpg" },
  { name: "Hải Phòng", sub: "Biển Đồ Sơn", image: "/images/vietnam-city.jpg" },
  { name: "Nội Bài", sub: "Sân bay quốc tế", image: "/images/vietnam-road.jpg" },
];

export default function HomePage() {
  return (
    <>
      <section className="air-hero">
        <div className="air-hero-bg" />
        <div className="sh-container-wide air-hero-inner">
          <Badge tone="blue">NỀN TẢNG ĐI CHUNG AN TOÀN</Badge>
          <h1>
            Đi chung một chuyến,
            <br />
            <span>an tâm mỗi chuyến đi.</span>
          </h1>
          <p>
            Đặt chuyến như đặt phòng: chọn điểm đón, điểm đến, ngày đi và số ghế.
            Tài xế KYC, tiền được giữ trong escrow và theo dõi trực tiếp.
          </p>
          <div className="air-hero-search"><SearchBox /></div>
          <div className="air-hero-trust">
            <span>✓ Tài xế xác thực CCCD &amp; GPLX</span>
            <span>✓ Giữ tiền đến khi hoàn tất</span>
            <span>✓ Hỗ trợ khiếu nại 24/7</span>
          </div>
        </div>
      </section>

      <div className="sh-container-wide">
        <nav className="air-categories" aria-label="Danh mục">
          {categories.map((category) => (
            <Link key={category.label} href={category.href} className="air-category">
              <span className="air-category-icon">{category.icon}</span>
              <span>{category.label}</span>
            </Link>
          ))}
        </nav>

        <SectionTitle
          eyebrow="Chuyến nổi bật"
          title="Đi đâu cũng có chuyến phù hợp"
          action={<Link href="/nearby/" className="air-link">Xem tất cả →</Link>}
        />
        <div className="air-listing-grid" id="chuyen-noi-bat">
          {featured.map((item) => (
            <Link key={item.title} href={item.href} className="air-listing">
              <div className="air-listing-media">
                <div className="air-listing-img" style={{ backgroundImage: `url(${item.image})` }} />
                <span className="air-listing-badge">{item.tag}</span>
                <button type="button" className="air-heart" aria-label="Lưu chuyến">♡</button>
              </div>
              <div className="air-listing-body">
                <div className="air-listing-top">
                  <strong>{item.title}</strong>
                  <span className="air-rating">★ 4.9</span>
                </div>
                <p>{item.detail}</p>
                <small>{item.meta}</small>
                <div className="air-listing-price">
                  <strong>{money(item.price)}</strong>
                  <span>/ ghế · từ</span>
                </div>
              </div>
            </Link>
          ))}
        </div>

        <SectionTitle eyebrow="Điểm đến" title="Đi đâu hôm nay?" action={<span className="muted-small">Tuyến nội địa Việt Nam</span>} />
        <div className="air-destinations" id="diem-den">
          {destinations.map((item) => (
            <Link key={item.name} href="/nearby/" className="air-destination">
              <div className="air-destination-img" style={{ backgroundImage: `url(${item.image})` }} />
              <div>
                <strong>{item.name}</strong>
                <small>{item.sub}</small>
              </div>
              <span>↗</span>
            </Link>
          ))}
        </div>

        <section className="air-how">
          <div>
            <span className="sh-eyebrow">Cách hoạt động</span>
            <h2>Đặt chuyến trong ba bước</h2>
          </div>
          <div className="air-steps">
            {[
              ["01", "Chọn điểm đón và điểm đến", "Tìm địa chỉ hoặc chạm bản đồ. Điểm đón có thể lấy từ vị trí hiện tại."],
              ["02", "Chọn ngày và số ghế", "Xem tuyến, giờ khởi hành, tài xế và giá trước khi xác nhận."],
              ["03", "Thanh toán và lên đường", "Tiền được giữ an toàn cho đến khi chuyến hoàn tất."],
            ].map(([step, title, text]) => (
              <Card key={step} className="air-step">
                <span>{step}</span>
                <h3>{title}</h3>
                <p>{text}</p>
              </Card>
            ))}
          </div>
        </section>

        <section className="air-host-cta">
          <div>
            <Badge tone="green">Dành cho tài xế</Badge>
            <h2>Có chuyến đi trống?</h2>
            <p>Đăng chuyến miễn phí, chia sẻ chi phí và đón khách trên toàn quốc.</p>
          </div>
          <Link href="/publish/" className="sh-btn sh-btn-secondary sh-btn-lg">
            Đăng chuyến ngay
          </Link>
        </section>
      </div>
    </>
  );
}
