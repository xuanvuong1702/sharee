import Link from "next/link";
import { Badge, Card, SectionTitle } from "@sharee/ui";
import { SearchBox } from "@/components/SearchBox";
import { money } from "@/lib/sharee";

const trips = [
  ["Hà Nội → Hải Phòng", "Bến xe Mỹ Đình · Lạch Tray", 180000, "/images/vietnam-road.jpg", "Phổ biến", "/search/?route=hanoi-haiphong&fromLat=21.0285&fromLng=105.7749&toLat=20.8449&toLng=106.6881&fromLabel=B%E1%BA%BFn%20xe%20M%E1%BB%B9%20%C4%90%C3%ACnh%2C%20H%C3%A0%20N%E1%BB%99i&toLabel=L%E1%BA%A1ch%20Tray%2C%20H%E1%BA%A3i%20Ph%C3%B2ng&seats=1"],
  ["Hà Nội → Nội Bài", "Sân bay Nội Bài · Đón tận nơi", 90000, "/images/hanoi.jpg", "Sân bay", "/nearby/"],
  ["Hà Nội → Hạ Long", "Vincom Bà Triệu · Bãi Cháy", 220000, "/images/vietnam-city.jpg", "Cuối tuần", "/nearby/"],
  ["Hà Nội → Ninh Bình", "Giáp Bát · Tam Cốc", 150000, "/images/vietnam-road.jpg", "Trải nghiệm", "/nearby/"],
  ["Hà Nội → Sa Pa", "Mỹ Đình · Sa Pa", 350000, "/images/vietnam-city.jpg", "Núi rừng", "/nearby/"],
  ["Hà Nội → Cát Bà", "Lương Yên · Cát Bà", 280000, "/images/hanoi.jpg", "Biển đảo", "/nearby/"],
  ["Hà Nội → Đà Nẵng", "Nội Bài · Đà Nẵng", 890000, "/images/vietnam-road.jpg", "Đường dài", "/nearby/"],
];

const experiences = [
  { icon: "🌊", label: "Biển đảo" },
  { icon: "🏔️", label: "Núi rừng" },
  { icon: "🍜", label: "Ẩm thực" },
  { icon: "🏛️", label: "Di sản" },
  { icon: "🌾", label: "Miền Tây" },
  { icon: "🌃", label: "Thành phố" },
  { icon: "🏕️", label: "Cắm trại" },
  { icon: "🚴", label: "Đạp xe" },
];

export default function HomePage() {
  return (
    <div className="air-home">
      <div className="sh-container-wide air-search-shell">
        <div className="air-search-center"><SearchBox /></div>
      </div>

      <div className="sh-container-wide air-home-body">
        <section>
          <div className="air-row-head">
            <h2>Chuyến đi nổi bật tại Hà Nội</h2>
            <Link href="/nearby/">Xem tất cả →</Link>
          </div>
          <div className="air-horizontal-row">
            {trips.map(([title, detail, price, image, tag, href]) => (
              <Link key={String(title)} href={String(href)} className="air-listing air-listing-horizontal">
                <div className="air-listing-media">
                  <div className="air-listing-img" style={{ backgroundImage: `url(${image})` }} />
                  <span className="air-listing-badge">{tag}</span>
                  <button type="button" className="air-heart" aria-label="Lưu chuyến">♡</button>
                </div>
                <div className="air-listing-body">
                  <div className="air-listing-top">
                    <strong>{title}</strong>
                    <span className="air-rating">★ 4.9</span>
                  </div>
                  <p>{detail}</p>
                  <small>Khởi hành linh hoạt · Tài xế KYC</small>
                  <div className="air-listing-price">
                    <strong>{money(Number(price))}</strong>
                    <span>/ ghế · từ</span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </section>

        <section className="air-experience-section">
          <div className="air-row-head">
            <h2>Khám phá trải nghiệm gần đây</h2>
            <Link href="/#diem-den">Xem tất cả →</Link>
          </div>
          <div className="air-experience-row">
            {experiences.map((item) => (
              <Link key={item.label} href="/nearby/" className="air-experience">
                <span>{item.icon}</span>
                <strong>{item.label}</strong>
              </Link>
            ))}
          </div>
        </section>

        <SectionTitle
          eyebrow="Điểm đến"
          title="Đi đâu hôm nay?"
          action={<span className="muted-small">Tuyến nội địa Việt Nam</span>}
        />
        <div className="air-destinations" id="diem-den">
          {[
            ["Hà Nội", "Phố cổ, Hồ Tây", "/images/hanoi.jpg"],
            ["Hải Phòng", "Biển Đồ Sơn", "/images/vietnam-city.jpg"],
            ["Nội Bài", "Sân bay quốc tế", "/images/vietnam-road.jpg"],
          ].map(([name, sub, image]) => (
            <Link key={name} href="/nearby/" className="air-destination">
              <div className="air-destination-img" style={{ backgroundImage: `url(${image})` }} />
              <div><strong>{name}</strong><small>{sub}</small></div>
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
          <Link href="/publish/" className="sh-btn sh-btn-secondary sh-btn-lg">Đăng chuyến ngay</Link>
        </section>
      </div>
    </div>
  );
}
