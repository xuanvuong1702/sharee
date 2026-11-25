"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { Logo } from "@sharee/ui";
import { useAuth } from "./AuthProvider";

const tabs = [
  { href: "/", icon: "🏠", label: "Tất cả" },
  { href: "/#chuyen-noi-bat", icon: "🚗", label: "Đi chung" },
  { href: "/ride/", icon: "🛵", label: "Đặt xe" },
  { href: "/daily/", icon: "🚌", label: "Daily" },
  { href: "/nearby/", icon: "✈️", label: "Sân bay" },
];

export function SiteHeader() {
  const pathname = usePathname();
  const { user, ready, signOut } = useAuth();
  const [menu, setMenu] = useState(false);

  return (
    <header className="site-header">
      <div className="header-inner">
        <Link href="/" className="header-logo" aria-label="Sharee trang chủ">
          <Logo />
        </Link>

        <nav className="main-nav" aria-label="Điều hướng chính">
          {tabs.map((tab) => (
            <Link key={tab.label} href={tab.href}
              className={pathname === tab.href ? "active" : ""}>
              <span className="nav-icon">{tab.icon}</span>
              {tab.label}
            </Link>
          ))}
        </nav>

        <div className="header-actions">
          <Link href="/publish/" className="host-link">Đăng chuyến</Link>
          <button type="button" className="header-icon" aria-label="Ngôn ngữ">🌐</button>
          <div className="header-user">
            <button type="button" className="user-menu-button" onClick={() => setMenu(!menu)}
              aria-label="Tài khoản">
              <span className="hamburger">☰</span>
              <span className="avatar user-avatar">
                {ready && user ? user.fullName.slice(0, 1).toUpperCase() : "◯"}
              </span>
            </button>
            {menu && (
              <div className="user-dropdown">
                {ready && user ? (
                  <>
                    <Link href="/account/" onClick={() => setMenu(false)}>Chuyến của tôi</Link>
                    <Link href="/publish/" onClick={() => setMenu(false)}>Đăng chuyến</Link>
                    <button type="button" onClick={() => { setMenu(false); signOut(); }}>Đăng xuất</button>
                  </>
                ) : (
                  <>
                    <Link href="/login/" className="dropdown-login" onClick={() => setMenu(false)}>Đăng nhập</Link>
                    <Link href="/publish/" onClick={() => setMenu(false)}>Đăng chuyến</Link>
                    <Link href="/account/" onClick={() => setMenu(false)}>Chuyến của tôi</Link>
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
