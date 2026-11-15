"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { Badge, Button, Card, Field } from "@sharee/ui";
import { useAuth } from "@/components/AuthProvider";

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const { api, signIn } = useAuth();
  const [phone, setPhone] = useState("+84912345678");
  const [code, setCode] = useState("");
  const [sent, setSent] = useState(false);
  const [devCode, setDevCode] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const nextParam = params.get("next") ?? "/account/";
  const next = nextParam.startsWith("/") ? nextParam : "/account/";

  const requestOtp = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const result = await api.requestOtp(phone.trim());
      setSent(true);
      setDevCode(result.devCode ?? null);
      if (result.devCode) setCode(result.devCode);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Không gửi được OTP");
    } finally {
      setBusy(false);
    }
  };

  const verify = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const auth = await api.verifyOtp(phone.trim(), code.trim());
      signIn(auth);
      router.push(next);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Mã xác thực không đúng");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="page-section">
      <div className="auth-layout">
        <div className="auth-copy">
          <Badge tone="blue">SHAREE ACCOUNT</Badge>
          <h1>Đăng nhập để đặt chuyến và nhận ưu đãi.</h1>
          <p>
            Một tài khoản dùng cho web, Android và iOS. Xác thực bằng số điện thoại, không cần mật khẩu.
          </p>
          <ul>
            <li>Thanh toán an toàn</li>
            <li>Hoàn tiền linh hoạt</li>
            <li>Hỗ trợ 24/7</li>
          </ul>
        </div>
        <Card className="auth-card">
          {!sent ? (
            <form onSubmit={requestOtp}>
              <h2>Đăng nhập</h2>
              <p className="muted">Nhập số điện thoại để nhận mã xác thực.</p>
              <Field
                label="Số điện thoại"
                value={phone}
                onChange={(event) => setPhone(event.target.value)}
                placeholder="+84912345678"
                autoComplete="tel"
              />
              {error ? <p className="form-error">{error}</p> : null}
              <Button type="submit" size="lg" disabled={busy}>
                {busy ? "Đang gửi..." : "Gửi mã OTP"}
              </Button>
              <p className="fine-print">
                Bằng cách tiếp tục, bạn đồng ý với Điều khoản và Chính sách bảo mật.
              </p>
            </form>
          ) : (
            <form onSubmit={verify}>
              <h2>Nhập mã xác thực</h2>
              <p className="muted">
                Mã 6 số đã gửi đến <strong>{phone}</strong>
              </p>
              <Field
                label="Mã OTP"
                value={code}
                onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
                inputMode="numeric"
                placeholder="______"
              />
              {devCode ? <div className="dev-code">Mã demo: {devCode} (đã tự điền)</div> : null}
              {error ? <p className="form-error">{error}</p> : null}
              <Button type="submit" size="lg" disabled={busy || code.length !== 6}>
                {busy ? "Đang xác thực..." : "Xác thực và tiếp tục"}
              </Button>
              <button type="button" className="link-button" onClick={() => setSent(false)}>
                Đổi số điện thoại
              </button>
            </form>
          )}
          <div className="login-links">
            <Link href="/">← Về trang chủ</Link>
            <Link href="/account/">Chuyến của tôi</Link>
          </div>
        </Card>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="page-section">Đang tải...</div>}>
      <LoginForm />
    </Suspense>
  );
}
