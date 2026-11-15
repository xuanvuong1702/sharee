import { useEffect, useState } from 'react';

const API = import.meta.env.VITE_API_BASE || 'http://localhost:8080';

async function api(path, { token, method = 'GET', body } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error(data?.error || `Lỗi ${res.status}`);
  return data;
}

const money = (v) => `${Number(v || 0).toLocaleString('vi-VN')}đ`;
const dt = (v) => (v ? new Date(v).toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' }) : '—');

function Login({ onLogin }) {
  const [phone, setPhone] = useState('+84900000001');
  const [code, setCode] = useState('');
  const [devCode, setDevCode] = useState('');
  const [step, setStep] = useState(0);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function request() {
    setBusy(true); setError('');
    try {
      const data = await api('/api/auth/otp/request', { method: 'POST', body: { phone } });
      setDevCode(data.devCode || '');
      if (data.devCode) setCode(data.devCode);
      setStep(1);
    } catch (e) { setError(e.message); } finally { setBusy(false); }
  }

  async function verify() {
    setBusy(true); setError('');
    try {
      const data = await api('/api/auth/otp/verify', { method: 'POST', body: { phone, code } });
      if (data.user.role !== 'admin') throw new Error('Tài khoản này không phải admin');
      localStorage.setItem('sharee_admin_token', data.accessToken);
      onLogin(data.accessToken);
    } catch (e) { setError(e.message); } finally { setBusy(false); }
  }

  return (
    <div className="login-wrap">
      <div className="login-card">
        <div className="brand"><span>R</span> Sharee Admin</div>
        <h1>Đăng nhập vận hành</h1>
        <p className="muted">Dùng số admin demo <b>+84900000001</b></p>
        {step === 0 ? (
          <>
            <label>Số điện thoại</label>
            <input value={phone} onChange={(e) => setPhone(e.target.value)} />
            <button className="primary" onClick={request} disabled={busy}>{busy ? 'Đang gửi…' : 'Gửi OTP'}</button>
          </>
        ) : (
          <>
            <label>Mã OTP</label>
            <input value={code} onChange={(e) => setCode(e.target.value)} maxLength={6} />
            {devCode && <div className="hint">Mã demo: {devCode}</div>}
            <button className="primary" onClick={verify} disabled={busy}>{busy ? 'Đang xác thực…' : 'Vào dashboard'}</button>
            <button className="link" onClick={() => setStep(0)}>Đổi số</button>
          </>
        )}
        {error && <div className="error">{error}</div>}
      </div>
    </div>
  );
}

const NAV = [
  ['dashboard', 'Tổng quan', '▦'],
  ['verifications', 'Duyệt hồ sơ', '✓'],
  ['reports', 'Báo cáo', '⚑'],
  ['refunds', 'Hoàn tiền', '↩'],
  ['users', 'Người dùng', '☺'],
  ['trips', 'Chuyến', '⇄'],
  ['daily', 'Daily', '▤'],
];

function App() {
  const [token, setToken] = useState(localStorage.getItem('sharee_admin_token'));
  const [tab, setTab] = useState('dashboard');

  if (!token) return <Login onLogin={setToken} />;

  return (
    <div className="layout">
      <aside>
        <div className="brand"><span>R</span> Sharee</div>
        <div className="caption">VẬN HÀNH</div>
        {NAV.map(([key, label, icon]) => (
          <button key={key} className={`nav ${tab === key ? 'on' : ''}`} onClick={() => setTab(key)}>
            <i>{icon}</i> {label}
          </button>
        ))}
        <div className="sidebar-foot">
          <div className="muted small">API</div>
          <div className="small mono">{API}</div>
          <button className="link" onClick={() => { localStorage.removeItem('sharee_admin_token'); setToken(null); }}>
            Đăng xuất
          </button>
        </div>
      </aside>
      <main>
        <header>
          <div>
            <div className="caption">SHAREE / {NAV.find(([k]) => k === tab)?.[1]}</div>
            <h1>{NAV.find(([k]) => k === tab)?.[1]}</h1>
          </div>
          <div className="pill">Admin</div>
        </header>
        {tab === 'dashboard' && <Dashboard token={token} />}
        {tab === 'verifications' && <Verifications token={token} />}
        {tab === 'reports' && <Reports token={token} />}
        {tab === 'refunds' && <Refunds token={token} />}
        {tab === 'users' && <Users token={token} />}
        {tab === 'trips' && <Trips token={token} />}
        {tab === 'daily' && <DailyAdmin token={token} />}
      </main>
    </div>
  );
}

function useLoad(fn, deps = []) {
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const reload = async () => {
    setLoading(true); setError('');
    try { setData(await fn()); } catch (e) { setError(e.message); } finally { setLoading(false); }
  };
  useEffect(() => { reload(); }, deps);
  return { data, error, loading, reload };
}

function State({ loading, error, children }) {
  if (loading) return <div className="card muted">Đang tải…</div>;
  if (error) return <div className="card error">{error}</div>;
  return children;
}

function Dashboard({ token }) {
  const { data, loading, error } = useLoad(() => api('/api/admin/dashboard', { token }));
  return (
    <State loading={loading} error={error}>
      <div className="kpis">
        <Kpi label="Người dùng" value={data?.users} />
        <Kpi label="Chuyến" value={data?.trips} />
        <Kpi label="Booking" value={data?.bookings} />
        <Kpi label="GMV" value={money(data?.gmv)} />
        <Kpi label="Báo cáo mở" value={data?.openReports} tone="warn" />
        <Kpi label="Chờ duyệt" value={data?.pendingVerifications} tone="warn" />
        <Kpi label="Chuyến đang mở" value={data?.activeTrips} />
        <Kpi label="Vé Daily 24h" value={data?.dailyTickets} />
      </div>
      <div className="card">
        <h3>Việc cần xử lý hôm nay</h3>
        <ul className="todo">
          <li><b>{data?.pendingVerifications ?? 0}</b> hồ sơ chờ duyệt</li>
          <li><b>{data?.openReports ?? 0}</b> báo cáo sự cố</li>
          <li>Đối soát thanh toán chạy tự động 02:00</li>
        </ul>
      </div>
    </State>
  );
}

function Kpi({ label, value, tone }) {
  return (
    <div className={`kpi ${tone || ''}`}>
      <span>{label}</span>
      <b>{value ?? '—'}</b>
    </div>
  );
}

function Verifications({ token }) {
  const { data, loading, error, reload } = useLoad(() => api('/api/admin/verifications', { token }));
  async function act(id, action) {
    await api(`/api/admin/verifications/${id}/${action}`, { token, method: 'POST', body: {} });
    reload();
  }
  return (
    <State loading={loading} error={error}>
      <div className="card">
        <table>
          <thead><tr><th>Người dùng</th><th>Loại</th><th>Trạng thái</th><th>Gửi lúc</th><th /></tr></thead>
          <tbody>
            {(data || []).map((v) => (
              <tr key={v.id}>
                <td><b>{v.userName}</b><div className="muted small">{v.phone}</div></td>
                <td>{v.type.toUpperCase()}</td>
                <td><Status value={v.status} /></td>
                <td className="muted">{dt(v.createdAt)}</td>
                <td className="actions">
                  {v.status === 'pending' && <>
                    <button onClick={() => act(v.id, 'approve')}>Duyệt</button>
                    <button className="danger" onClick={() => act(v.id, 'reject')}>Từ chối</button>
                  </>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </State>
  );
}

function Reports({ token }) {
  const { data, loading, error, reload } = useLoad(() => api('/api/admin/reports', { token }));
  async function resolve(id, status) {
    await api(`/api/admin/reports/${id}?status=${status}`, { token, method: 'PATCH' });
    reload();
  }
  return (
    <State loading={loading} error={error}>
      <div className="card">
        <table>
          <thead><tr><th>Người báo</th><th>Lý do</th><th>Đối tượng</th><th>Trạng thái</th><th /></tr></thead>
          <tbody>
            {(data || []).map((r) => (
              <tr key={r.id}>
                <td><b>{r.reporterName}</b><div className="muted small">{dt(r.createdAt)}</div></td>
                <td><b>{r.reason}</b><div className="muted small">{r.description}</div></td>
                <td className="mono small">{r.targetType} · {r.targetId.slice(0, 8)}</td>
                <td><Status value={r.status} /></td>
                <td className="actions">
                  {r.status === 'open' && <>
                    <button onClick={() => resolve(r.id, 'resolved')}>Xử lý</button>
                    <button className="ghost" onClick={() => resolve(r.id, 'dismissed')}>Bỏ qua</button>
                  </>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </State>
  );
}

function Refunds({ token }) {
  const { data, loading, error, reload } = useLoad(() => api('/api/admin/refunds', { token }));
  async function refund(id) {
    await api(`/api/admin/refunds/${id}`, { token, method: 'POST', body: {} });
    reload();
  }
  return (
    <State loading={loading} error={error}>
      <div className="card">
        <table>
          <thead><tr><th>Booking</th><th>Khách</th><th>Số tiền</th><th>Trạng thái</th><th /></tr></thead>
          <tbody>
            {(data || []).map((r) => (
              <tr key={r.booking_id}>
                <td><b>{r.origin_label} → {r.destination_label}</b><div className="muted small mono">{r.booking_id.slice(0, 8)}</div></td>
                <td>{r.passenger_name}</td>
                <td>{money(r.amount)}</td>
                <td><Status value={r.payment_status} /></td>
                <td className="actions"><button onClick={() => refund(r.booking_id)}>Hoàn tiền</button></td>
              </tr>
            ))}
            {(!data || data.length === 0) && <tr><td colSpan="5" className="muted">Không có khoản cần hoàn</td></tr>}
          </tbody>
        </table>
      </div>
    </State>
  );
}

function Users({ token }) {
  const [query, setQuery] = useState('');
  const { data, loading, error, reload } = useLoad(() => api(`/api/admin/users?q=${encodeURIComponent(query)}`, { token }), [query]);
  return (
    <State loading={loading} error={error}>
      <div className="card">
        <div className="toolbar">
          <input placeholder="Tìm tên hoặc số điện thoại…" value={query} onChange={(e) => setQuery(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && reload()} />
          <button onClick={reload}>Tìm</button>
        </div>
        <table>
          <thead><tr><th>Họ tên</th><th>SĐT</th><th>Vai trò</th><th>Xác thực</th><th>Đánh giá</th></tr></thead>
          <tbody>
            {(data || []).map((u) => (
              <tr key={u.id}>
                <td><b>{u.fullName}</b></td>
                <td className="mono">{u.phone}</td>
                <td>{u.role}</td>
                <td>{u.verifiedLevel}/3</td>
                <td>★ {u.ratingAvg} ({u.ratingCount})</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </State>
  );
}

function Trips({ token }) {
  const { data, loading, error } = useLoad(() => api('/api/admin/trips', { token }));
  return (
    <State loading={loading} error={error}>
      <div className="card">
        <table>
          <thead><tr><th>Tuyến</th><th>Tài xế</th><th>Khởi hành</th><th>Ghế</th><th>Giá</th><th>Trạng thái</th></tr></thead>
          <tbody>
            {(data || []).map((t) => (
              <tr key={t.id}>
                <td><b>{t.originLabel} → {t.destinationLabel}</b></td>
                <td>{t.driverName}<div className="muted small">{t.vehicle} · {t.vehiclePlate}</div></td>
                <td>{dt(t.departureTime)}</td>
                <td>{t.seatsAvailable}/{t.seatsTotal}</td>
                <td>{money(t.pricePerSeat)}</td>
                <td><Status value={t.status} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </State>
  );
}

function DailyAdmin({ token }) {
  const { data, loading, error } = useLoad(() => api('/api/daily/partner/summary', { token }));
  const euro = (cents) => `${(Number(cents || 0) / 100).toFixed(2)} €`;
  return (
    <State loading={loading} error={error}>
      <div className="kpis">
        <Kpi label="Vé hôm nay" value={data?.ticketsToday} />
        <Kpi label="Lượt xác nhận" value={data?.validationsToday} />
        <Kpi label="Tổng trợ giá" value={euro(data?.amountMinor)} />
        <Kpi label="Cost/trip" value={euro(data?.costPerTripMinor)} />
        <Kpi label="Tuyến hoạt động" value={data?.activeLines} />
      </div>
      <div className="card">
        <h3>Daily mode</h3>
        <p className="muted" style={{ fontSize: 13, lineHeight: 1.6 }}>
          Vé điện tử tạo tại trạm, tài xế nhận và xác nhận bằng mã 4 số.
          Chi phí mỗi chuyến được tính từ trợ giá theo km và trần tháng của đối tác.
        </p>
      </div>
    </State>
  );
}

function Status({ value }) {
  const label = {
    pending: 'Chờ duyệt', approved: 'Đã duyệt', rejected: 'Từ chối',
    open: 'Mở', resolved: 'Đã xử lý', dismissed: 'Bỏ qua',
    succeeded: 'Thành công', refunded: 'Đã hoàn', failed: 'Thất bại',
    confirmed: 'Xác nhận', completed: 'Hoàn thành', cancelled: 'Đã huỷ',
    full: 'Đầy', ongoing: 'Đang chạy',
  }[value] || value;
  return <span className={`status ${value}`}>{label}</span>;
}

export default App;
