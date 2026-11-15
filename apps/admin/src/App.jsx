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
  const [phone, setPhone] = useState('');
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
        <div className="brand"><span>S</span> Sharee Admin</div>
        <h1>Đăng nhập vận hành</h1>
        <p className="muted">Đăng nhập bằng tài khoản vận hành.</p>
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
  ['appeals', 'Khiếu nại', '⚖'],
  ['reports', 'Báo cáo', '⚑'],
  ['refunds', 'Hoàn tiền', '↩'],
  ['users', 'Người dùng', '☺'],
  ['trips', 'Chuyến', '⇄'],
  ['daily', 'Daily', '▤'],
];

function App() {
  const [token, setToken] = useState(localStorage.getItem('sharee_admin_token'));
  const [tab, setTab] = useState('dashboard');
  const [paletteOpen, setPaletteOpen] = useState(false);

  useEffect(() => {
    const onKey = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        setPaletteOpen((value) => !value);
      }
      if (event.key === 'Escape') setPaletteOpen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  if (!token) return <Login onLogin={setToken} />;

  return (
    <div className="layout">
      <aside>
        <div className="brand"><span>S</span> Sharee</div>
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
          <div className="header-tools">
            <button className="command-trigger" onClick={() => setPaletteOpen(true)}>
              <span>⌘ K</span> Tìm nhanh
            </button>
            <div className="pill">Admin</div>
          </div>
        </header>
        {tab === 'dashboard' && <Dashboard token={token} onNavigate={setTab} />}
        {tab === 'verifications' && <Verifications token={token} />}
        {tab === 'appeals' && <Appeals token={token} />}
        {tab === 'reports' && <Reports token={token} />}
        {tab === 'refunds' && <Refunds token={token} />}
        {tab === 'users' && <Users token={token} />}
        {tab === 'trips' && <Trips token={token} />}
        {tab === 'daily' && <DailyAdmin token={token} />}
      </main>
      {paletteOpen && (
        <CommandPalette
          onClose={() => setPaletteOpen(false)}
          onRun={(key) => { setTab(key); setPaletteOpen(false); }}
        />
      )}
    </div>
  );
}

function CommandPalette({ onClose, onRun }) {
  const [query, setQuery] = useState('');
  const items = NAV.filter(([, label]) => label.toLowerCase().includes(query.toLowerCase()));
  return (
    <div className="command-overlay" onClick={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <div className="command-panel" role="dialog" aria-label="Tìm nhanh">
        <div className="command-search">
          <span>⌘</span>
          <input
            autoFocus
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Đi tới màn hình..."
            onKeyDown={(event) => {
              if (event.key === 'Enter' && items[0]) onRun(items[0][0]);
              if (event.key === 'Escape') onClose();
            }}
          />
          <kbd>ESC</kbd>
        </div>
        <div className="command-list">
          {items.map(([key, label, icon]) => (
            <button key={key} onClick={() => onRun(key)}>
              <span className="command-icon">→</span>
              <span>{label}</span>
              <span className="command-enter">↵</span>
            </button>
          ))}
          {items.length === 0 && <div className="empty">Không tìm thấy màn hình.</div>}
        </div>
        <div className="command-foot">Nhấn <b>Enter</b> để mở · <b>Esc</b> để đóng</div>
      </div>
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

function Dashboard({ token, onNavigate }) {
  const { data, loading, error } = useLoad(() => api('/api/admin/dashboard', { token }));
  const audit = useLoad(() => api('/api/admin/audit', { token }));
  return (
    <State loading={loading} error={error}>
      <div className="kpis">
        <Kpi label="Người dùng" value={data?.users} />
        <Kpi label="GMV" value={money(data?.gmv)} />
        <Kpi label="Escrow đang giữ" value={money(data?.escrowHeld)} tone="accent" />
        <Kpi label="Khiếu nại mở" value={data?.openAppeals} tone="warn" />
        <Kpi label="Chờ duyệt KYC" value={data?.pendingVerifications} tone="warn" />
        <Kpi label="Báo cáo mở" value={data?.openReports} tone="warn" />
        <Kpi label="Tài xế đã KYC" value={data?.verifiedDrivers} tone="good" />
        <Kpi label="Chuyến đang mở" value={data?.activeTrips} />
      </div>

      <div className="dashboard-grid">
        <div className="card">
          <div className="card-head">
            <div>
              <h3>Việc cần xử lý</h3>
              <p className="muted small">Ưu tiên hồ sơ và tranh chấp ảnh hưởng đến giao dịch.</p>
            </div>
            <span className="pill">{Number(data?.pendingVerifications || 0) + Number(data?.openAppeals || 0)} việc</span>
          </div>
          <div className="queue-list">
            <button className="queue-item" onClick={() => onNavigate('verifications')}>
              <span className="queue-icon">✓</span>
              <span><b>{data?.pendingVerifications ?? 0} hồ sơ KYC</b><small>Kiểm tra CCCD, GPLX và giấy tờ xe</small></span>
              <span className="queue-arrow">→</span>
            </button>
            <button className="queue-item" onClick={() => onNavigate('appeals')}>
              <span className="queue-icon warn">⚖</span>
              <span><b>{data?.openAppeals ?? 0} khiếu nại mở</b><small>Tiền escrow đang bị khóa chờ xử lý</small></span>
              <span className="queue-arrow">→</span>
            </button>
            <button className="queue-item" onClick={() => onNavigate('reports')}>
              <span className="queue-icon">⚑</span>
              <span><b>{data?.openReports ?? 0} báo cáo sự cố</b><small>Phản hồi từ hành khách và tài xế</small></span>
              <span className="queue-arrow">→</span>
            </button>
          </div>
        </div>

        <div className="card">
          <h3>Sức khỏe vận hành</h3>
          <div className="health-list">
            <div><span className="health-dot ok" /><b>API</b><small>Đang hoạt động</small></div>
            <div><span className="health-dot ok" /><b>Thanh toán</b><small>Mock · cho phép thử nghiệm</small></div>
            <div><span className="health-dot ok" /><b>Escrow</b><small>{money(data?.escrowHeld)} đang được bảo vệ</small></div>
            <div><span className="health-dot" /><b>Đối soát</b><small>Chạy tự động 02:00 hằng ngày</small></div>
          </div>
          <div className="dashboard-note">
            <BadgeText>{data?.bookings ?? 0} booking · {data?.trips ?? 0} chuyến · {data?.dailyTickets ?? 0} vé Daily 24h</BadgeText>
          </div>
        </div>
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        <div className="card-head">
          <div>
            <h3>Hoạt động gần đây</h3>
            <p className="muted small">Audit log của duyệt hồ sơ, khiếu nại và thanh toán.</p>
          </div>
          <span className="pill">{audit.data?.length || 0} bản ghi</span>
        </div>
        <div className="activity-list">
          {(audit.data || []).slice(0, 7).map((row) => (
            <div className="activity-row" key={row.id}>
              <span className="activity-dot" />
              <b>{actionLabel(row.action)}</b>
              <span className="muted small">{row.actorName || 'Hệ thống'}</span>
              <span className="activity-time">{dt(row.createdAt)}</span>
            </div>
          ))}
          {(!audit.data || audit.data.length === 0) && <div className="empty">Chưa có hoạt động.</div>}
        </div>
      </div>
    </State>
  );
}

function BadgeText({ children }) {
  return <span className="muted">{children}</span>;
}

function actionLabel(action) {
  const labels = {
    'verification.approve': 'Duyệt hồ sơ KYC',
    'verification.reject': 'Từ chối hồ sơ KYC',
    'verification.suspend': 'Tạm dừng tài xế',
    'appeal.resolve': 'Xử lý khiếu nại',
    'report.resolve': 'Xử lý báo cáo',
    'refund.manual': 'Hoàn tiền thủ công',
  };
  return labels[action] || action;
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
  const [selected, setSelected] = useState(null);
  const [detail, setDetail] = useState(null);
  const [detailError, setDetailError] = useState('');
  const [busy, setBusy] = useState(false);
  const [reason, setReason] = useState('');

  async function open(userId) {
    setSelected(userId); setDetail(null); setDetailError(''); setReason('');
    try { setDetail(await api(`/api/admin/verifications/${userId}`, { token })); }
    catch (e) { setDetailError(e.message); }
  }

  async function approve() {
    if (!detail) return;
    setBusy(true);
    try {
      await api(`/api/admin/verifications/${selected}/approve`, { token, method: 'POST', body: { expiresAt: null } });
      await reload();
      setSelected(null); setDetail(null);
    } catch (e) { setDetailError(e.message); } finally { setBusy(false); }
  }

  async function reject() {
    if (!detail) return;
    if (reason.trim().length < 5) { setDetailError('Nhập lý do từ chối (ít nhất 5 ký tự)'); return; }
    setBusy(true);
    try {
      await api(`/api/admin/verifications/${selected}/reject`, { token, method: 'POST', body: { reason } });
      await reload();
      setSelected(null); setDetail(null);
    } catch (e) { setDetailError(e.message); } finally { setBusy(false); }
  }

  async function suspend() {
    if (!detail || reason.trim().length < 5) { setDetailError('Nhập lý do tạm dừng'); return; }
    setBusy(true);
    try {
      await api(`/api/admin/verifications/${selected}/suspend`, { token, method: 'POST', body: { reason } });
      await reload();
      setSelected(null); setDetail(null);
    } catch (e) { setDetailError(e.message); } finally { setBusy(false); }
  }

  async function viewDocument(docId) {
    try {
      const res = await fetch(`${API}/api/admin/verifications/${selected}/documents/${docId}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error('Không mở được tài liệu');
      const blob = await res.blob();
      window.open(URL.createObjectURL(blob), '_blank', 'noopener');
    } catch (e) { setDetailError(e.message); }
  }

  return (
    <State loading={loading} error={error}>
      <div className="card">
        <div className="card-head">
          <div>
            <h3>Hồ sơ xác thực tài xế</h3>
            <p className="muted small">Kiểm tra CCCD, GPLX, giấy tờ xe và selfie trước khi duyệt.</p>
          </div>
          <span className="pill">{data?.length || 0} hồ sơ</span>
        </div>
        <table>
          <thead><tr><th>Tài xế</th><th>Hồ sơ</th><th>Giấy tờ</th><th>Trạng thái</th><th>Gửi lúc</th><th /></tr></thead>
          <tbody>
            {(data || []).map((v) => (
              <tr key={v.userId}>
                <td><b>{v.fullName}</b><div className="muted small">{v.phone}</div></td>
                <td>
                  <div className="small">{v.legalName || '—'}</div>
                  <div className="muted small mono">CCCD {v.idNumber || '—'} · GPLX {v.licenseNumber || '—'}</div>
                </td>
                <td>{v.documentCount}/7</td>
                <td><Status value={v.status} /></td>
                <td className="muted small">{dt(v.submittedAt)}</td>
                <td><button onClick={() => open(v.userId)}>Xem hồ sơ</button></td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!data || data.length === 0) && <div className="empty">Chưa có hồ sơ xác thực.</div>}
      </div>

      {selected && (
        <div className="review-overlay" onClick={(e) => { if (e.target === e.currentTarget) { setSelected(null); setDetail(null); } }}>
          <div className="review-panel">
            <div className="review-head">
              <div>
                <div className="caption">HỒ SƠ XÁC THỰC</div>
                <h2>{detail?.legalName || 'Đang tải…'}</h2>
              </div>
              <button className="ghost" onClick={() => { setSelected(null); setDetail(null); }}>Đóng</button>
            </div>
            {detailError && <div className="error">{detailError}</div>}
            {!detail ? <div className="muted">Đang tải hồ sơ…</div> : (
              <>
                <div className="review-grid">
                  <Info label="Họ tên pháp lý" value={detail.legalName} />
                  <Info label="Ngày sinh" value={detail.dateOfBirth} />
                  <Info label="Số CCCD" value={detail.idNumber} />
                  <Info label="Ngày cấp / hết hạn" value={`${detail.idIssuedAt || '—'} → ${detail.idExpiry || '—'}`} />
                  <Info label="Số GPLX" value={detail.licenseNumber} />
                  <Info label="Hạng GPLX" value={detail.licenseClass} />
                  <Info label="GPLX hết hạn" value={detail.licenseExpiry} />
                  <Info label="Đăng ký xe" value={detail.vehicleRegistration} />
                  <Info label="Bảo hiểm hết hạn" value={detail.insuranceExpiry} />
                  <Info label="Trạng thái" value={detail.status} />
                  <Info label="Xác thực đến" value={detail.expiresAt ? dt(detail.expiresAt) : '—'} />
                  <Info label="Gửi lúc" value={detail.submittedAt ? dt(detail.submittedAt) : '—'} />
                </div>

                <h3>Giấy tờ ({detail.documents?.length || 0}/7)</h3>
                <div className="doc-grid">
                  {(detail.documents || []).map((doc) => (
                    <button key={doc.id} className="doc-card" onClick={() => viewDocument(doc.id)}>
                      <span className="doc-icon">{doc.mimeType === 'application/pdf' ? 'PDF' : 'IMG'}</span>
                      <b>{DOC_LABELS[doc.type] || doc.type}</b>
                      <small>{doc.originalName}</small>
                      <small className="muted">{Math.round(doc.sizeBytes / 1024)} KB</small>
                    </button>
                  ))}
                </div>
                {detail.status === 'pending' && (
                  <>
                    <label>Lý do từ chối / tạm dừng</label>
                    <textarea value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Ví dụ: Ảnh CCCD bị mờ, không đọc được số..." />
                    <div className="review-actions">
                      <button className="primary" onClick={approve} disabled={busy}>{busy ? 'Đang xử lý…' : 'Duyệt hồ sơ'}</button>
                      <button className="danger" onClick={reject} disabled={busy}>Từ chối</button>
                      <button className="ghost" onClick={suspend} disabled={busy}>Tạm dừng</button>
                    </div>
                  </>
                )}
                {detail.status !== 'pending' && detail.status !== 'approved' && (
                  <div className="error">Hồ sơ không ở trạng thái chờ duyệt.</div>
                )}
              </>
            )}
          </div>
        </div>
      )}
    </State>
  );
}

const DOC_LABELS = {
  id_front: 'CCCD mặt trước',
  id_back: 'CCCD mặt sau',
  license_front: 'GPLX mặt trước',
  license_back: 'GPLX mặt sau',
  vehicle_registration: 'Đăng ký xe',
  insurance: 'Bảo hiểm xe',
  selfie: 'Ảnh selfie',
};

function Info({ label, value }) {
  return (
    <div className="info">
      <span>{label}</span>
      <b>{value || '—'}</b>
    </div>
  );
}

function Appeals({ token }) {
  const { data, loading, error, reload } = useLoad(() => api('/api/admin/appeals', { token }));
  const [selected, setSelected] = useState(null);
  const [detail, setDetail] = useState(null);
  const [note, setNote] = useState('');
  const [detailError, setDetailError] = useState('');
  const [busy, setBusy] = useState(false);

  async function open(id) {
    setSelected(id); setDetail(null); setDetailError(''); setNote('');
    try { setDetail(await api(`/api/admin/appeals/${id}`, { token })); }
    catch (e) { setDetailError(e.message); }
  }

  async function resolve(outcome) {
    if (note.trim().length < 5) { setDetailError('Nhập ghi chú xử lý (ít nhất 5 ký tự)'); return; }
    setBusy(true);
    try {
      await api(`/api/admin/appeals/${selected}/resolve`, {
        token, method: 'POST', body: { outcome, note },
      });
      await reload();
      setSelected(null); setDetail(null);
    } catch (e) { setDetailError(e.message); } finally { setBusy(false); }
  }

  async function viewEvidence(evidenceId) {
    try {
      const res = await fetch(`${API}/api/admin/appeals/${selected}/evidence/${evidenceId}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error('Không mở được bằng chứng');
      window.open(URL.createObjectURL(await res.blob()), '_blank', 'noopener');
    } catch (e) { setDetailError(e.message); }
  }

  return (
    <State loading={loading} error={error}>
      <div className="card">
        <div className="card-head">
          <div>
            <h3>Khiếu nại & tranh chấp</h3>
            <p className="muted small">Tiền trong escrow bị khóa cho đến khi admin xử lý.</p>
          </div>
          <span className="pill">{data?.length || 0} khiếu nại</span>
        </div>
        <table>
          <thead><tr><th>Booking</th><th>Bên mở</th><th>Bên bị khiếu nại</th><th>Lý do</th><th>Trạng thái</th><th /></tr></thead>
          <tbody>
            {(data || []).map((a) => (
              <tr key={a.id}>
                <td className="mono small">{a.bookingId.slice(0, 8)}</td>
                <td><b>{a.openedByName}</b></td>
                <td>{a.againstName}</td>
                <td><b>{a.reason}</b><div className="muted small">{a.description}</div></td>
                <td><Status value={a.status} /></td>
                <td><button onClick={() => open(a.id)}>Xem</button></td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!data || data.length === 0) && <div className="empty">Chưa có khiếu nại.</div>}
      </div>

      {selected && (
        <div className="review-overlay" onClick={(e) => { if (e.target === e.currentTarget) { setSelected(null); setDetail(null); } }}>
          <div className="review-panel">
            <div className="review-head">
              <div>
                <div className="caption">HỒ SƠ KHIẾU NẠI</div>
                <h2>{detail?.reason || 'Đang tải…'}</h2>
              </div>
              <button className="ghost" onClick={() => { setSelected(null); setDetail(null); }}>Đóng</button>
            </div>
            {detailError && <div className="error">{detailError}</div>}
            {!detail ? <div className="muted">Đang tải…</div> : (
              <>
                <div className="review-grid">
                  <Info label="Người mở" value={detail.openedByName} />
                  <Info label="Bên bị khiếu nại" value={detail.againstName} />
                  <Info label="Booking" value={detail.bookingId.slice(0, 8)} />
                  <Info label="Trạng thái" value={detail.status} />
                  <Info label="Ngày mở" value={dt(detail.createdAt)} />
                  <Info label="Kết quả" value={detail.resolution || '—'} />
                </div>
                <h3>Mô tả</h3>
                <p className="muted small">{detail.description}</p>
                <h3>Bằng chứng ({detail.evidence?.length || 0})</h3>
                <div className="doc-grid">
                  {(detail.evidence || []).map((ev) => (
                    <button key={ev.id} className="doc-card" onClick={() => viewEvidence(ev.id)}>
                      <span className="doc-icon">{ev.mimeType === 'application/pdf' ? 'PDF' : 'IMG'}</span>
                      <b>{ev.originalName}</b>
                      <small>{ev.uploaderName} · {Math.max(1, Math.round(ev.sizeBytes / 1024))} KB</small>
                    </button>
                  ))}
                </div>
                {(detail.status === 'open' || detail.status === 'investigating') && (
                  <>
                    <label>Ghi chú xử lý</label>
                    <textarea value={note} onChange={(e) => setNote(e.target.value)} placeholder="Căn cứ quyết định, bằng chứng đã kiểm tra..." />
                    <div className="review-actions">
                      <button className="primary" onClick={() => resolve('release')} disabled={busy}>Giải ngân cho tài xế</button>
                      <button className="danger" onClick={() => resolve('refund')} disabled={busy}>Hoàn tiền cho khách</button>
                    </div>
                  </>
                )}
              </>
            )}
          </div>
        </div>
      )}
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
