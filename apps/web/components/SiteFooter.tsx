import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="sh-container-wide">
        <div className="footer-grid">
          <div>
            <strong>Hỗ trợ</strong>
            <Link href="/account/">Trung tâm trợ giúp</Link>
            <Link href="/account/">Chuyến của tôi</Link>
            <Link href="/nearby/">Tìm chuyến</Link>
          </div>
          <div>
            <strong>Đón khách</strong>
            <Link href="/publish/">Đăng chuyến</Link>
            <Link href="/ride/">Đặt xe</Link>
            <Link href="/daily/">Daily shuttle</Link>
          </div>
          <div>
            <strong>Sharee</strong>
            <Link href="/">Về chúng tôi</Link>
            <a href="https://github.com/xuanvuong1702/sharee/releases/latest"
              target="_blank" rel="noreferrer">Tải ứng dụng</a>
            <Link href="/login/">Đăng nhập</Link>
          </div>
        </div>
        <div className="footer-bottom">
          <span>© {new Date().getFullYear()} Sharee · Đi chung, đi xa hơn</span>
          <span>Tiếng Việt · VND</span>
        </div>
      </div>
    </footer>
  );
}
