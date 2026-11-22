"use client";

import Link from "next/link";
import { useAuth } from "./AuthProvider";
import { Logo, Button } from "@sharee/ui";

const APP_URL = "https://github.com/xuanvuong1702/sharee/releases/latest";

export function SiteHeader() {
  const { user, ready, signOut } = useAuth();
  return (
    <header className="site-header">
      <div className="sh-container-wide header-inner">
        <Link href="/" aria-label="Sharee trang chủ" className="logo-link">
          <Logo />
        </Link>
        <nav className="main-nav" aria-label="Điều hướng chính">
          <Link href="/#tim-chuyen">Tìm chuyến</Link>
          <Link href="/nearby/">Gần bạn</Link>
          <Link href="/publish/">Đăng chuyến</Link>
          <Link href="/account/">Chuyến của tôi</Link>
          <a href={APP_URL} target="_blank" rel="noreferrer">
            Tải app
          </a>
        </nav>
        <div className="header-actions">
          {!ready ? null : user ? (
            <>
              <Link href="/account/" className="user-chip">
                <span className="avatar">{user.fullName.slice(0, 1).toUpperCase()}</span>
                <span>{user.fullName.split(" ")[0]}</span>
              </Link>
              <Button variant="ghost" size="sm" onClick={signOut}>
                Đăng xuất
              </Button>
            </>
          ) : (
            <Link href="/login/">
              <Button variant="primary" size="sm">
                Đăng nhập
              </Button>
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
