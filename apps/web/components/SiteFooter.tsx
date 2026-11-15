import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="sh-container-wide footer-inner">
        <div>
          <strong>Sharee</strong>
          <p>Đi chung để hành trình nhẹ nhàng hơn.</p>
        </div>
        <div className="footer-links">
          <Link href="/#tim-chuyen">Tìm chuyến</Link>
          <Link href="/account/">Chuyến của tôi</Link>
          <Link href="/login/">Đăng nhập</Link>
          <a href="https://github.com/xuanvuong1702/sharee/releases/latest" target="_blank" rel="noreferrer">
            Tải APK
          </a>
        </div>
        <span className="footer-copy">© {new Date().getFullYear()} Sharee · Demo</span>
      </div>
    </footer>
  );
}
