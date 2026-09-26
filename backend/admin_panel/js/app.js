(function () {
  const api = () => {
    if (!window.SafaronAdminApi?.api) throw new Error('Admin JS yuklanmadi. Ctrl+F5 qiling.');
    return window.SafaronAdminApi.api;
  };

  const loginView = document.getElementById('loginView');
  const appView = document.getElementById('appView');
  const content = document.getElementById('content');
  const pageTitle = document.getElementById('pageTitle');
  const pageSub = document.getElementById('pageSub');
  const adminName = document.getElementById('adminName');
  const modalRoot = document.getElementById('modalRoot');
  const lightboxRoot = document.getElementById('lightboxRoot');
  const loginBtn = document.getElementById('loginBtn');

  const UI = () => window.SafaronUI;

  function money(n) {
    return `${Number(n || 0).toLocaleString('uz-UZ')} so‘m`;
  }
  function dt(v) {
    if (!v) return '—';
    try { return new Date(v).toLocaleString('uz-UZ'); } catch { return String(v); }
  }
  function badge(status) {
    const s = (status || '—').toUpperCase();
    let cls = 'badge';
    if (['PENDING', 'SEARCHING', 'DRIVER_ACCEPTED'].includes(s)) cls += ' warn';
    if (['REJECTED', 'CANCELLED', 'BLOCKED', 'SUSPENDED', 'EXPIRED'].includes(s)) cls += ' bad';
    if (['DRIVER_ON_WAY', 'IN_PROGRESS', 'CONFIRMED'].includes(s)) cls += ' blue';
    return `<span class="${cls}">${s}</span>`;
  }
  function esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  function docKey(x) {
    const raw = String(x.url || x.photo_url || '').split('?')[0].replace(/\/+$/, '');
    const base = raw.split('/').pop() || '';
    return { raw, base, type: x.type || x.label || '' };
  }

  function uniqueDocs(list) {
    const seen = new Set();
    const out = [];
    (list || []).forEach((x) => {
      const { raw, base, type } = docKey(x);
      const keys = [raw, base && `${type}:${base}`, base].filter(Boolean);
      if (keys.some((k) => seen.has(k))) return;
      keys.forEach((k) => seen.add(k));
      out.push(x);
    });
    return out;
  }

  function collectDriverDocs(d, { skipSelfie = false } = {}) {
    const fromDocs = (d.documents || []).filter((x) => x.type === 'selfie' || x.type === 'vehicle_photo');
    const mapped = fromDocs.length
      ? fromDocs.map((x) => ({
          label: x.label || (x.type === 'selfie' ? 'Profil rasmi' : 'Mashina rasmi'),
          url: x.url,
          type: x.type,
        }))
      : [
          ...(d.photo_url ? [{ label: 'Profil rasmi', url: d.photo_url, type: 'selfie' }] : []),
          ...(d.vehicle?.photo_url ? [{ label: 'Mashina rasmi', url: d.vehicle.photo_url, type: 'vehicle_photo' }] : []),
        ];
    return uniqueDocs(mapped).filter((x) => !(skipSelfie && x.type === 'selfie' && d.photo_url));
  }

  function exportButtons(prefix) {
    return `<div class="row-actions">
      <button type="button" class="btn ghost sm" data-export="${prefix}" data-fmt="csv">CSV eksport</button>
      <button type="button" class="btn ghost sm" data-export="${prefix}" data-fmt="xls">Excel eksport</button>
    </div>`;
  }

  function bindExports(root) {
    root.querySelectorAll('[data-export]').forEach((b) => {
      b.onclick = async () => {
        const kind = b.dataset.export;
        const fmt = b.dataset.fmt || 'csv';
        const names = {
          overview: `safaron_statistika.${fmt === 'xls' ? 'xls' : 'csv'}`,
          trips: `safaron_safarlar.${fmt === 'xls' ? 'xls' : 'csv'}`,
          users: `safaron_foydalanuvchilar.${fmt === 'xls' ? 'xls' : 'csv'}`,
          drivers: `safaron_haydovchilar.${fmt === 'xls' ? 'xls' : 'csv'}`,
        };
        try {
          await window.SafaronAdminApi.download(`/admin/export/${kind}?fmt=${fmt}`, names[kind] || `safaron.${fmt}`);
        } catch (ex) {
          alert(ex.message || 'Eksport xato');
        }
      };
    });
  }

  function showApp() {
    loginView.classList.add('hidden');
    appView.classList.remove('hidden');
    const admin = JSON.parse(localStorage.getItem('safaron_admin') || '{}');
    applyAdminChip(admin);
    navigate('dashboard');
  }
  function showLogin() {
    appView.classList.add('hidden');
    loginView.classList.remove('hidden');
  }

  async function doLogin(e) {
    if (e) e.preventDefault();
    const err = document.getElementById('loginErr');
    err.textContent = '';
    loginBtn.disabled = true;
    loginBtn.textContent = 'Kirilmoqda...';
    try {
      const data = await api()('/admin/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          phone: document.getElementById('loginPhone').value.trim(),
          password: document.getElementById('loginPass').value,
        }),
      });
      localStorage.setItem('safaron_admin_token', data.access_token);
      localStorage.setItem('safaron_admin', JSON.stringify(data.admin));
      showApp();
    } catch (ex) {
      err.textContent = ex.message || 'Kirish amalga oshmadi';
    } finally {
      loginBtn.disabled = false;
      loginBtn.textContent = 'Kirish';
    }
  }

  function applyAdminChip(admin) {
    adminName.textContent = admin.full_name || 'Admin';
    const av = document.getElementById('adminAvatar');
    if (av) av.textContent = UI().initials(admin.full_name || 'Admin');
  }

  document.getElementById('loginForm').addEventListener('submit', doLogin);
  const adminChip = document.getElementById('adminChip');
  if (adminChip) adminChip.addEventListener('click', () => navigate('profile'));
  document.getElementById('logoutBtn').addEventListener('click', () => {
    localStorage.removeItem('safaron_admin_token');
    localStorage.removeItem('safaron_admin');
    showLogin();
  });
  document.querySelectorAll('#nav button').forEach((btn) => {
    btn.addEventListener('click', () => navigate(btn.dataset.page));
  });

  function closeModal() { modalRoot.innerHTML = ''; }
  function openLightbox(src) {
    lightboxRoot.innerHTML = `<div class="lightbox"><img src="${esc(src)}" alt="doc" /></div>`;
    lightboxRoot.querySelector('.lightbox').addEventListener('click', () => { lightboxRoot.innerHTML = ''; });
  }

  function openModal({ title, sub, bodyHtml, actionsHtml }) {
    modalRoot.innerHTML = `
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head">
            <div>
              <h3>${title}</h3>
              ${sub ? `<div class="muted" style="font-size:12px;margin-top:4px">${sub}</div>` : ''}
            </div>
            <button type="button" class="btn ghost sm" id="modalClose">Yopish</button>
          </div>
          <div class="modal-body">${bodyHtml}</div>
          ${actionsHtml ? `<div class="modal-actions">${actionsHtml}</div>` : ''}
        </div>
      </div>`;
    modalRoot.querySelector('#modalClose').onclick = closeModal;
    modalRoot.querySelector('.modal-backdrop').addEventListener('click', (e) => {
      if (e.target.classList.contains('modal-backdrop')) closeModal();
    });
    modalRoot.querySelectorAll('[data-img]').forEach((el) => {
      el.addEventListener('click', () => openLightbox(el.getAttribute('data-img')));
    });
  }

  function docsHtml(docs) {
    if (!docs || !docs.length) {
      return `<div class="muted">Hujjatlar yuklanmagan.</div>`;
    }
    return `<div class="docs-grid">${docs.map((d) => {
      const url = d.url || d.photo_url;
      const label = d.label || d.type || 'Hujjat';
      return `<div class="doc-card">
        ${url
          ? `<img src="${esc(url)}" alt="${esc(label)}" data-img="${esc(url)}" style="cursor:zoom-in" onerror="this.outerHTML='<div class=ph>Rasm yo‘q</div>'" />`
          : `<div class="ph">Fayl yo‘q</div>`}
        <div class="cap">${esc(label)}${url ? ` · <a href="${esc(url)}" target="_blank" rel="noopener">Ochish</a>` : ''}</div>
      </div>`;
    }).join('')}</div>`;
  }

  async function navigate(page) {
    document.querySelectorAll('#nav button').forEach((b) => b.classList.toggle('active', b.dataset.page === page));
    const meta = {
      dashboard: ['Bosh sahifa', 'Haqiqiy ko‘rsatkichlar'],
      users: ['Foydalanuvchilar', 'Batafsil profil · bloklash'],
      drivers: ['Haydovchilar', 'Profil · hujjatlar · status'],
      applications: ['Haydovchi arizalari', 'Avval batafsil ko‘ring, keyin tasdiqlang / rad eting'],
      documents: ['Hujjatlar', 'Barcha haydovchi hujjatlari galereyasi'],
      trips: ['Safarlar', 'Tayyor e’lonlar va bandlar'],
      requests: ['Buyurtmalar', 'Yo‘lovchi so‘rovlari'],
      locations: ['Joylar', 'Canonical locations + alias'],
      pendingLocations: ['Joylar', 'Barcha joylar'],
      notifications: ['Xabarnomalar', 'Foydalanuvchilarga xabar'],
      settings: ['Tizim sozlamalari', 'Tizim parametrlari'],
      logs: ['Loglar', 'Admin harakatlari'],
      bonuses: ['Bonus tizimi', 'Kutilayotgan va tasdiqlangan bonuslar'],
      referrals: ['Referal tizimi', 'Taklif qilingan foydalanuvchilar'],
      withdrawals: ['To‘lovlar va yechimlar', 'Bonus yechish so‘rovlari'],
      fraud: ['Tasdiqlash', 'Shubhali safarlar'],
      flags: ['Ilova sozlamalari', 'Funksiyalarni yoqish va o‘chirish'],
      profile: ['Profil', 'Shaxsiy ma’lumotlar va parol'],
    };
    pageTitle.textContent = meta[page]?.[0] || page;
    pageSub.textContent = meta[page]?.[1] || '';
    content.innerHTML = '<p class="muted">Yuklanmoqda...</p>';
    UI()?.destroyCharts?.();
    try {
      if (page === 'dashboard') await renderDashboard();
      else if (page === 'users') await renderUsers();
      else if (page === 'drivers') await renderDrivers();
      else if (page === 'applications') await renderDrivers('PENDING');
      else if (page === 'documents') await renderDocuments();
      else if (page === 'trips') await renderTrips();
      else if (page === 'requests') await renderRequests();
      else if (page === 'locations' || page === 'pendingLocations') await renderLocations();
      else if (page === 'notifications') renderNotify();
      else if (page === 'settings') await renderSettings();
      else if (page === 'logs') await renderLogs();
      else if (page === 'profile') await renderProfile();
      else if (window.SafaronPlatform) await window.SafaronPlatform.render(page, content, api());
    } catch (ex) {
      const msg = String(ex.message || '');
      if (msg.includes('401') || msg.toLowerCase().includes('avtoriz') || msg.toLowerCase().includes('admin')) {
        localStorage.removeItem('safaron_admin_token');
        showLogin();
        document.getElementById('loginErr').textContent = 'Sessiya tugagan. Qayta kiring.';
        return;
      }
      content.innerHTML = `<p class="error">${esc(ex.message)}</p>`;
    }
  }

  async function renderDashboard() {
    const u = UI();
    const d = await api()('/admin/dashboard');
    const users = d.users_total || 0;
    const drivers = d.drivers_total || 0;
    const passengers = d.passengers_total || 0;
    const reqRows = d.recent_requests || [];
    const userRows = d.recent_users || [];
    const tripRows = d.recent_trips || [];
    const refs = d.top_referrers || [];
    const wds = d.withdrawals || [];
    content.innerHTML = u.pageLayout({
      toolbarHtml: u.toolbar(`${exportButtons('overview')} ${exportButtons('trips')} ${exportButtons('users')}`),
      stats: u.statRow([
        u.statCard({ label: 'Jami foydalanuvchilar', value: users, sub: `Faol ${d.users_active || 0}`, tone: 'blue', icon: '☺' }),
        u.statCard({ label: 'Haydovchilar', value: drivers, sub: `Onlayn ${d.drivers_online || 0}`, tone: 'green', icon: '▣' }),
        u.statCard({ label: 'Yo‘lovchilar', value: passengers, sub: 'Ro‘yxatdan o‘tgan', tone: 'violet', icon: '◎' }),
        u.statCard({ label: 'Buyurtmalar bugun', value: d.requests_today || 0, sub: `Faol safar ${d.trips_active || 0}`, tone: 'orange', icon: '☰' }),
      ]) + u.statRow([
        u.statCard({ label: 'Jami tushum', value: u.money(d.revenue_total), sub: 'Haydovchi daromadi', tone: 'green', icon: '₸' }),
        u.statCard({ label: 'Bonus berilgan', value: u.money(d.bonus_paid), sub: 'Tasdiqlangan', tone: 'blue', icon: '★' }),
        u.statCard({ label: 'Kutilayotgan tasdiqlar', value: (d.driver_pending || 0) + (d.pending_bonus || 0), sub: `Ariza ${d.driver_pending || 0} · bonus ${d.pending_bonus || 0}`, tone: 'orange', icon: '⏳' }),
        u.statCard({ label: 'Shubhali safar', value: d.fraud_open || 0, sub: `Yechim kutilmoqda ${d.pending_withdrawal || 0}`, tone: 'red', icon: '⚠' }),
      ]),
      charts: `<div class="charts-grid">
        ${u.card('Oxirgi 7 kunlik statistika', '<div class="chart-box"><canvas id="chartLine"></canvas></div>')}
        ${u.card('Foydalanuvchilar ulushi', `<div class="chart-box"><canvas id="chartDonut"></canvas><div class="donut-center">${users}<small>Jami</small></div></div>`)}
        ${u.card('Buyurtma holati', '<div class="chart-box"><canvas id="chartStatus"></canvas></div>')}
      </div>`,
      main: u.card('So‘nggi buyurtmalar', u.table([
        { label: '#', key: 'id', render: (r) => `#${r.id}` },
        { label: 'Yo‘lovchi', key: 'passenger', render: (r) => u.userCell(r.passenger) },
        { label: 'Marshrut', key: 'route', render: (r) => u.esc(r.route) },
        { label: 'Narx', key: 'price', render: (r) => u.money(r.price) },
        { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
        { label: 'Vaqt', key: 'time' },
      ], reqRows), '<button type="button" class="linkish" data-go="requests">Barchasi →</button>'),
      side: u.card('Kutilayotgan ishlar', `
        <div style="display:grid;gap:10px">
          <div><span class="muted">Haydovchi arizasi</span><div style="font-size:22px;font-weight:800">${d.driver_pending || 0}</div></div>
          <div><span class="muted">Bonus tasdiqi</span><div style="font-size:22px;font-weight:800">${d.pending_bonus || 0}</div></div>
          <div><span class="muted">Joylar (kutilmoqda)</span><div style="font-size:22px;font-weight:800">${d.locations_pending || 0}</div></div>
          <button class="btn primary sm" data-go="applications">Arizalarni ko‘rish</button>
          <button class="btn ghost sm" data-go="locations">Joylar</button>
        </div>`) + u.card('Top referrers', u.table([
        { label: 'Foydalanuvchi', key: 'name', render: (r) => u.userCell(r.name) },
        { label: 'Kod', key: 'code', render: (r) => `<code>${u.esc(r.code)}</code>` },
        { label: 'Soni', key: 'count' },
      ], refs, 'Hali yo‘q')),
    }) + `<div class="page-grid" style="grid-template-columns:1fr 1fr 1fr;margin-top:14px">
      ${u.card('Bonus yechim so‘rovlari', u.table([
        { label: 'Summa', key: 'amount', render: (r) => u.money(r.amount) },
        { label: 'Telegram', key: 'telegram', render: (r) => u.esc(r.telegram || '—') },
        { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
      ], wds), '<button class="linkish" data-go="withdrawals">→</button>')}
      ${u.card('Oxirgi ro‘yxatdan o‘tganlar', u.table([
        { label: 'Foydalanuvchi', key: 'name', render: (r) => u.userCell(r.name, r.phone) },
        { label: 'Rol', key: 'role', render: (r) => u.pill(r.role === 'driver' ? 'DRIVER' : 'ACTIVE', [r.role === 'driver' ? 'Haydovchi' : 'Yo‘lovchi', r.role === 'driver' ? 'blue' : 'ok']) },
        { label: 'Vaqt', key: 'time' },
      ], userRows), '<button class="linkish" data-go="users">→</button>')}
      ${u.card('Oxirgi haydovchi e’lonlari', u.table([
        { label: 'Marshrut', key: 'route', render: (r) => u.esc(r.route) },
        { label: 'Narx', key: 'price', render: (r) => u.money(r.price) },
        { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
      ], tripRows), '<button class="linkish" data-go="trips">→</button>')}
    </div>` + `<div class="page-grid" style="grid-template-columns:1fr;margin-top:14px">
      ${u.card('Tezkor havolalar', `<div style="display:flex;flex-wrap:wrap;gap:8px">
        <button class="btn ghost" data-go="bonuses">★ Bonus tizimi</button>
        <button class="btn ghost" data-go="referrals">⚭ Referal tizimi</button>
        <button class="btn ghost" data-go="fraud">✓ Tasdiqlash</button>
        <button class="btn ghost" data-go="flags">⚙ Ilova sozlamalari</button>
      </div>`)}
    </div>`;
    content.querySelectorAll('[data-go]').forEach((b) => { b.onclick = () => navigate(b.dataset.go); });
    bindExports(content);
    const labels = (d.chart_days || []).map((x) => x.label);
    u.makeChart(document.getElementById('chartLine'), {
      type: 'line',
      data: {
        labels,
        datasets: [
          { label: 'So‘rovlar', data: d.chart_days.map((x) => x.requests), borderColor: u.COLORS.blue, backgroundColor: 'rgba(37,99,235,.12)', tension: .35, fill: true },
          { label: 'Safarlar', data: d.chart_days.map((x) => x.trips), borderColor: u.COLORS.green, backgroundColor: 'rgba(16,185,129,.12)', tension: .35, fill: true },
          { label: 'Yangi user', data: d.chart_days.map((x) => x.users), borderColor: u.COLORS.orange, tension: .35 },
        ],
      },
      options: { responsive: true, plugins: { legend: { position: 'bottom' } }, scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } } },
    });
    u.makeChart(document.getElementById('chartDonut'), {
      type: 'doughnut',
      data: { labels: ['Yo‘lovchilar', 'Haydovchilar'], datasets: [{ data: [passengers, drivers], backgroundColor: [u.COLORS.green, u.COLORS.blue] }] },
      options: { cutout: '68%', plugins: { legend: { position: 'bottom' } } },
    });
    const br = d.request_status_breakdown || {};
    u.makeChart(document.getElementById('chartStatus'), {
      type: 'bar',
      data: {
        labels: Object.keys(br).map((k) => ({ SEARCHING: 'Qidiruv', DRIVER_ACCEPTED: 'Qabul', CONFIRMED: 'Tasdiq', IN_PROGRESS: 'Jarayon', COMPLETED: 'Yakun', CANCELLED: 'Bekor', EXPIRED: 'Muddati' }[k] || k)),
        datasets: [{ data: Object.values(br), backgroundColor: u.COLORS.blue, borderRadius: 8 }],
      },
      options: { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } } },
    });
  }

  async function openDriverDetail(id, { forReview = false } = {}) {
    const d = await api()(`/admin/drivers/${id}`);
    const uniqDocs = collectDriverDocs(d, { skipSelfie: Boolean(d.photo_url) });

    openModal({
      title: `${esc(d.full_name)} · #${d.id}`,
      sub: `${esc(d.phone)} · ${badge(d.status)} · ${d.is_online ? '🟢 Online' : '🔴 Offline'}`,
      bodyHtml: `
        <div style="display:flex;gap:12px;align-items:center">
          ${d.photo_url ? `<img class="avatar" src="${esc(d.photo_url)}" data-img="${esc(d.photo_url)}" style="cursor:zoom-in" />` : `<div class="avatar" style="display:grid;place-items:center">🚕</div>`}
          <div>
            <div style="font-weight:800;font-size:16px">${esc(d.full_name)}</div>
            <div class="muted">${esc(d.phone)} · tajriba ${d.experience_years} yil · reyting ${d.rating_avg} (${d.rating_count})</div>
          </div>
        </div>
        <div class="section-title">Asosiy ma’lumot</div>
        <div class="kv">
          <div class="item"><div class="k">Status</div><div class="v">${badge(d.status)}</div></div>
          <div class="item"><div class="k">Safarlar</div><div class="v">${d.trips_count}</div></div>
          <div class="item"><div class="k">Daromad</div><div class="v">${money(d.total_earnings)}</div></div>
          <div class="item"><div class="k">Yaratilgan</div><div class="v">${dt(d.created_at)}</div></div>
          <div class="item"><div class="k">Tasdiqlangan</div><div class="v">${dt(d.approved_at)}</div></div>
          <div class="item"><div class="k">Last seen</div><div class="v">${dt(d.last_seen_at)}</div></div>
          ${d.rejection_reason ? `<div class="item"><div class="k">Rad sababi</div><div class="v">${esc(d.rejection_reason)}</div></div>` : ''}
          ${d.suspend_reason ? `<div class="item"><div class="k">Suspend sababi</div><div class="v">${esc(d.suspend_reason)}</div></div>` : ''}
        </div>
        <div class="section-title">Avtomobil</div>
        <div class="kv">
          <div class="item"><div class="k">Model</div><div class="v">${esc(d.vehicle?.model || '—')}</div></div>
          <div class="item"><div class="k">Davlat raqami</div><div class="v">${esc(d.vehicle?.plate || '—')}</div></div>
          <div class="item"><div class="k">Sig‘im</div><div class="v">${d.vehicle?.seats ?? '—'}</div></div>
          <div class="item"><div class="k">Rang</div><div class="v">${esc(d.vehicle?.color || '—')}</div></div>
        </div>
        <div class="section-title">📄 Hujjatlar (${uniqDocs.length})</div>
        ${docsHtml(uniqDocs)}
        <div class="section-title">So‘nggi e’lonlar</div>
        <div class="table-wrap"><table><thead><tr><th>ID</th><th>Yo‘nalish</th><th>Narx</th><th>Status</th></tr></thead>
        <tbody>${(d.recent_trips || []).map((t) => `<tr><td>${t.id}</td><td>${esc(t.from_text)} → ${esc(t.to_text)}</td><td>${money(t.price)}</td><td>${badge(t.status)}</td></tr>`).join('') || '<tr><td colspan="4" class="muted">Yo‘q</td></tr>'}</tbody></table></div>
        <div class="section-title">Tanlangan so‘rovlar</div>
        <div class="table-wrap"><table><thead><tr><th>ID</th><th>Yo‘nalish</th><th>Narx</th><th>Status</th></tr></thead>
        <tbody>${(d.recent_requests || []).map((r) => `<tr><td>${r.id}</td><td>${esc(r.from_text)} → ${esc(r.to_text)}</td><td>${money(r.agreed_price || r.offered_price)}</td><td>${badge(r.status)}</td></tr>`).join('') || '<tr><td colspan="4" class="muted">Yo‘q</td></tr>'}</tbody></table></div>
      `,
      actionsHtml: forReview || d.status === 'PENDING'
        ? `<button class="btn" id="actApprove">✅ Tasdiqlash</button>
           <button class="btn danger" id="actReject">⛔ Rad etish</button>`
        : (d.status === 'APPROVED'
          ? `<button class="btn danger" id="actSuspend">⏸ Suspend</button>`
          : ''),
    });

    const approve = modalRoot.querySelector('#actApprove');
    const reject = modalRoot.querySelector('#actReject');
    const suspend = modalRoot.querySelector('#actSuspend');
    if (approve) approve.onclick = async () => {
      if (!confirm('Hujjatlarni ko‘rib chiqdingizmi? Tasdiqlaysizmi?')) return;
      await api()(`/admin/drivers/${id}/approve`, { method: 'POST' });
      closeModal();
      navigate('applications');
    };
    if (reject) reject.onclick = async () => {
      const reason = prompt('Rad etish sababi (majburiy), masalan: Guvohnoma aniq emas:');
      if (!reason || reason.trim().length < 3) return alert('Sabab majburiy.');
      await api()(`/admin/drivers/${id}/reject`, { method: 'POST', body: JSON.stringify({ status: 'REJECTED', reason }) });
      closeModal();
      navigate('applications');
    };
    if (suspend) suspend.onclick = async () => {
      const reason = prompt('Suspend sababi:') || 'Qoida buzilishi';
      await api()(`/admin/drivers/${id}/suspend`, { method: 'POST', body: JSON.stringify({ status: 'SUSPENDED', reason }) });
      closeModal();
      navigate('drivers');
    };
  }

  async function openUserDetail(id) {
    const u = await api()(`/admin/users/${id}`);
    openModal({
      title: `${esc(u.full_name)} · #${u.id}`,
      sub: `${esc(u.phone)} · ${esc(u.role_label || (u.has_driver ? 'Yo‘lovchi / Haydovchi' : 'Yo‘lovchi'))}`,
      bodyHtml: `
        <div style="display:flex;align-items:center;gap:12px;margin-bottom:14px">
          ${u.avatar_url
            ? `<img src="${esc(u.avatar_url)}" alt="" data-img="${esc(u.avatar_url)}" style="width:88px;height:88px;border-radius:50%;object-fit:cover;border:2px solid var(--border);cursor:zoom-in" onerror="this.outerHTML='<div class=avatar style=display:grid;place-items:center>☺</div>'" />`
            : `<div class="avatar" style="display:grid;place-items:center">☺</div>`}
          <div>
            <div style="font-weight:800">${esc(u.full_name)}</div>
            <div class="muted">${esc(u.phone)}</div>
            <div style="margin-top:6px">${u.has_driver ? badge('Yo‘lovchi / Haydovchi') : badge('Yo‘lovchi')}</div>
          </div>
        </div>
        <div class="kv">
          <div class="item"><div class="k">Telefon</div><div class="v">${esc(u.phone)}</div></div>
          <div class="item"><div class="k">Rol</div><div class="v">${esc(u.role_label || (u.has_driver ? 'Yo‘lovchi / Haydovchi' : 'Yo‘lovchi'))}</div></div>
          <div class="item"><div class="k">Til</div><div class="v">${esc(u.language)}</div></div>
          <div class="item"><div class="k">Blok</div><div class="v">${u.is_blocked ? badge('BLOCKED') : badge('ACTIVE')}</div></div>
          <div class="item"><div class="k">Reyting</div><div class="v">${u.rating_avg} (${u.rating_count})</div></div>
          <div class="item"><div class="k">Haydovchi</div><div class="v">${u.driver_status ? badge(u.driver_status) : '—'}</div></div>
          <div class="item"><div class="k">Ro‘yxat</div><div class="v">${dt(u.created_at)}</div></div>
          <div class="item"><div class="k">Oxirgi faollik</div><div class="v">${dt(u.last_seen_at)}</div></div>
        </div>
        <div class="section-title">So‘rovlar tarixi</div>
        <div class="table-wrap"><table><thead><tr><th>ID</th><th>Yo‘nalish</th><th>Narx</th><th>Status</th><th>Vaqt</th></tr></thead>
        <tbody>${(u.requests || []).map((r) => `<tr><td>${r.id}</td><td>${esc(r.from_text)} → ${esc(r.to_text)}</td><td>${money(r.agreed_price || r.offered_price)}</td><td>${badge(r.status)}</td><td>${dt(r.created_at)}</td></tr>`).join('') || '<tr><td colspan="5" class="muted">Yo‘q</td></tr>'}</tbody></table></div>
        <div class="section-title">Haydovchi e’lonlari</div>
        <div class="table-wrap"><table><thead><tr><th>ID</th><th>Yo‘nalish</th><th>Narx</th><th>Joy</th><th>Status</th></tr></thead>
        <tbody>${(u.trips || []).map((t) => `<tr><td>${t.id}</td><td>${esc(t.from_text)} → ${esc(t.to_text)}</td><td>${money(t.price)}</td><td>${t.seats_available}/${t.seats_total}</td><td>${badge(t.status)}</td></tr>`).join('') || '<tr><td colspan="5" class="muted">Yo‘q</td></tr>'}</tbody></table></div>
      `,
      actionsHtml: `
        <button class="btn ${u.is_blocked ? '' : 'danger'}" id="actBlock">${u.is_blocked ? '✅ Faollashtirish' : '⛔ Bloklash'}</button>
        ${u.driver_id ? `<button class="btn blue" id="actOpenDriver">🚕 Haydovchi profili</button>` : ''}
      `,
    });
    modalRoot.querySelector('#actBlock').onclick = async () => {
      const reason = u.is_blocked ? 'unblock' : (prompt('Bloklash sababi:') || 'Admin');
      await api()(`/admin/users/${id}/block`, { method: 'POST', body: JSON.stringify({ status: u.is_blocked ? 'UNBLOCK' : 'BLOCK', reason }) });
      closeModal();
      navigate('users');
    };
    const od = modalRoot.querySelector('#actOpenDriver');
    if (od) od.onclick = () => openDriverDetail(u.driver_id);
  }

  async function openRequestDetail(id) {
    const r = await api()(`/admin/requests/${id}`);
    openModal({
      title: `So‘rov #${r.id}`,
      sub: `${badge(r.status)} · ${esc(r.passenger_name)} · ${esc(r.passenger_phone)}`,
      bodyHtml: `
        <div class="kv">
          <div class="item"><div class="k">Qayerdan</div><div class="v">${esc(r.from_text)}</div></div>
          <div class="item"><div class="k">Qayerga</div><div class="v">${esc(r.to_text)}</div></div>
          <div class="item"><div class="k">Aniq joy</div><div class="v">${esc(r.exact_place || '—')}</div></div>
          <div class="item"><div class="k">Sana/vaqt</div><div class="v">${dt(r.scheduled_at)}</div></div>
          <div class="item"><div class="k">Yo‘lovchilar</div><div class="v">${r.passengers_count}</div></div>
          <div class="item"><div class="k">Bagaj</div><div class="v">${r.has_luggage ? 'Bor' : 'Yo‘q'}</div></div>
          <div class="item"><div class="k">Taklif narx</div><div class="v">${money(r.offered_price)}</div></div>
          <div class="item"><div class="k">Kelishilgan</div><div class="v">${r.agreed_price != null ? money(r.agreed_price) : '—'}</div></div>
          <div class="item"><div class="k">Izoh</div><div class="v">${esc(r.note || '—')}</div></div>
          <div class="item"><div class="k">Bekor</div><div class="v">${esc(r.cancelled_by || '—')} ${esc(r.cancel_reason || '')}</div></div>
        </div>
        <div class="section-title">Haydovchi javoblari</div>
        <div class="table-wrap"><table><thead><tr><th>Haydovchi</th><th>Telefon</th><th>Mashina</th><th>Narx</th><th>Status</th></tr></thead>
        <tbody>${(r.responses || []).map((x) => `<tr>
          <td>${esc(x.driver_name)} (#${x.driver_id})</td>
          <td>${esc(x.driver_phone)}</td>
          <td>${esc(x.car)} ${esc(x.plate)}</td>
          <td>${x.offered_price != null ? money(x.offered_price) : '—'}</td>
          <td>${badge(x.status)}</td>
        </tr>`).join('') || '<tr><td colspan="5" class="muted">Javob yo‘q</td></tr>'}</tbody></table></div>
      `,
    });
  }

  async function openTripDetail(id) {
    const t = await api()(`/admin/trips/${id}`);
    openModal({
      title: `Safar #${t.id}`,
      sub: `${badge(t.status)} · ${esc(t.driver_name)} · ${esc(t.plate)}`,
      bodyHtml: `
        <div class="kv">
          <div class="item"><div class="k">Yo‘nalish</div><div class="v">${esc(t.from_text)} → ${esc(t.to_text)}</div></div>
          <div class="item"><div class="k">Vaqt</div><div class="v">${dt(t.scheduled_at)}</div></div>
          <div class="item"><div class="k">Joylar</div><div class="v">${t.seats_available}/${t.seats_total}</div></div>
          <div class="item"><div class="k">Narx</div><div class="v">${money(t.price)}</div></div>
          <div class="item"><div class="k">Haydovchi</div><div class="v">${esc(t.driver_name)} · ${esc(t.driver_phone)}</div></div>
          <div class="item"><div class="k">Mashina</div><div class="v">${esc(t.car)} · ${esc(t.plate)}</div></div>
          <div class="item"><div class="k">Izoh</div><div class="v">${esc(t.note || '—')}</div></div>
        </div>
        <div class="section-title">Bandlar</div>
        <div class="table-wrap"><table><thead><tr><th>Yo‘lovchi</th><th>Telefon</th><th>Joy</th><th>Status</th></tr></thead>
        <tbody>${(t.bookings || []).map((b) => `<tr>
          <td>${esc(b.passenger_name)}</td><td>${esc(b.passenger_phone)}</td><td>${b.seats}</td><td>${badge(b.status)}</td>
        </tr>`).join('') || '<tr><td colspan="4" class="muted">Band yo‘q</td></tr>'}</tbody></table></div>
      `,
    });
  }

  async function renderUsers() {
    const u = UI();
    let tab = 'all';
    let q = '';
    const draw = async () => {
      const role = tab === 'drivers' ? 'driver' : tab === 'users' ? 'passenger' : '';
      const status = tab === 'blocked' ? 'blocked' : '';
      const data = await api()(`/admin/users?limit=100${role ? '&role=' + role : ''}${status ? '&status=' + status : ''}${q ? '&q=' + encodeURIComponent(q) : ''}`);
      content.innerHTML = u.pageLayout({
        stats: u.statRow([
          u.statCard({ label: 'Jami', value: data.total, sub: 'Ko‘rsatilmoqda', tone: 'blue', icon: '☺' }),
          u.statCard({ label: 'Faol', value: data.items.filter((x) => !x.is_blocked).length, sub: 'Joriy sahifa', tone: 'green', icon: '✓' }),
          u.statCard({ label: 'Haydovchi', value: data.items.filter((x) => x.has_driver).length, sub: 'Joriy sahifa', tone: 'violet', icon: '▣' }),
          u.statCard({ label: 'Bloklangan', value: data.items.filter((x) => x.is_blocked).length, sub: 'Joriy sahifa', tone: 'red', icon: '⛔' }),
        ]),
        tabsHtml: u.tabs([
          { key: 'all', label: 'Barchasi', count: data.total },
          { key: 'users', label: 'Foydalanuvchilar' },
          { key: 'drivers', label: 'Haydovchilar' },
          { key: 'blocked', label: 'Bloklangan' },
        ], tab),
        toolbarHtml: u.toolbar(`${u.searchInput('userSearch', 'Ism, telefon bo‘yicha qidirish...')} ${exportButtons('users')}`),
        main: u.card('Foydalanuvchilar ro‘yxati', u.table([
          { label: 'ID', key: 'id', render: (r) => `#${r.id}` },
          { label: 'Foydalanuvchi', key: 'full_name', render: (r) => u.userCell(r.full_name, r.phone, r.avatar_url) },
          { label: 'Telefon', key: 'phone' },
          { label: 'Rol', key: 'role_label', render: (r) => r.has_driver
            ? u.pill('DRIVER', ['Yo‘lovchi / Haydovchi', 'blue'])
            : u.pill('ACTIVE', ['Yo‘lovchi', 'ok']) },
          { label: 'Referal kod', key: 'referral_code', render: (r) => r.referral_code ? `<code>${u.esc(r.referral_code)}</code>` : '—' },
          { label: 'Ro‘yxat', key: 'created_at', render: (r) => u.dt(r.created_at) },
          { label: 'Holat', key: 'is_blocked', render: (r) => u.pill(r.is_blocked ? 'BLOCKED' : 'ACTIVE') },
          { label: '', key: 'x', render: (r) => `<button class="btn sm primary" data-user="${r.id}">Batafsil</button>` },
        ], data.items)),
      });
      u.bindTabs(content, (k) => { tab = k; draw(); });
      const si = document.getElementById('userSearch');
      if (si) {
        si.value = q;
        let t;
        si.oninput = () => { clearTimeout(t); t = setTimeout(() => { q = si.value.trim(); draw(); }, 350); };
      }
      content.querySelectorAll('[data-user]').forEach((b) => b.onclick = () => openUserDetail(b.dataset.user));
      bindExports(content);
    };
    await draw();
  }

  async function renderDrivers(status) {
    const u = UI();
    const q = status ? `?status=${status}` : '';
    const rows = await api()(`/admin/drivers${q}`);
    const forReview = status === 'PENDING';
    const online = rows.filter((d) => d.is_online).length;
    content.innerHTML = u.pageLayout({
      toolbarHtml: forReview ? '' : u.toolbar(exportButtons('drivers')),
      stats: u.statRow([
        u.statCard({ label: forReview ? 'Kutilayotgan arizalar' : 'Jami haydovchilar', value: rows.length, sub: forReview ? 'Ko‘rib chiqish kerak' : 'Ro‘yxat', tone: forReview ? 'orange' : 'blue', icon: '▣' }),
        u.statCard({ label: 'Onlayn', value: online, sub: 'Hozir faol', tone: 'green', icon: '🟢' }),
        u.statCard({ label: 'Tasdiqlangan', value: rows.filter((d) => d.status === 'APPROVED').length, sub: 'Status', tone: 'violet', icon: '✓' }),
        u.statCard({ label: 'Suspend / rad', value: rows.filter((d) => ['SUSPENDED', 'REJECTED'].includes(d.status)).length, sub: 'Muammoli', tone: 'red', icon: '⚠' }),
      ]),
      main: (forReview ? `<div class="info-banner">Tasdiqlashdan oldin <b>Batafsil</b> orqali profil va mashina rasmlarini ko‘rib chiqing.</div>` : '') +
        u.card(forReview ? 'Haydovchi arizalari' : 'Haydovchilar', u.table([
          { label: 'ID', key: 'id', render: (r) => `#${r.id}` },
          { label: 'Haydovchi', key: 'full_name', render: (r) => u.userCell(r.full_name, r.phone) },
          { label: 'Mashina', key: 'vehicle', render: (r) => r.vehicle ? `${u.esc(r.vehicle.model)}<br><span class="muted">${u.esc(r.vehicle.plate)}</span>` : '—' },
          { label: 'Hujjat', key: 'docs_count', render: (r) => `${r.docs_count ?? (r.documents || []).length} ta` },
          { label: 'Reyting', key: 'rating_avg', render: (r) => `★ ${r.rating_avg} · ${r.trips_count} safar` },
          { label: 'Online', key: 'is_online', render: (r) => u.pill(r.is_online ? 'ACTIVE' : 'EXPIRED', [r.is_online ? 'Onlayn' : 'Offline', r.is_online ? 'ok' : '']) },
          { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
          { label: '', key: 'x', render: (r) => `<button class="btn sm primary" data-drv="${r.id}">Batafsil</button>` },
        ], rows)),
    });
    content.querySelectorAll('[data-drv]').forEach((b) => b.onclick = () => openDriverDetail(b.dataset.drv, { forReview }));
    bindExports(content);
  }

  async function renderDocuments() {
    const u = UI();
    const rows = await api()('/admin/drivers');
    const cards = [];
    rows.forEach((d) => {
      const docs = collectDriverDocs(d);
      docs.forEach((doc) => {
        if (!doc.url) return;
        cards.push({ driverId: d.id, name: d.full_name, phone: d.phone, status: d.status, ...doc });
      });
    });
    content.innerHTML = u.pageLayout({
      stats: u.statRow([
        u.statCard({ label: 'Jami hujjatlar', value: cards.length, sub: 'Profil + mashina', tone: 'blue', icon: '▢' }),
        u.statCard({ label: 'Haydovchilar', value: rows.length, sub: 'Ro‘yxat', tone: 'green', icon: '▣' }),
        u.statCard({ label: 'Kutilmoqda', value: rows.filter((d) => d.status === 'PENDING').length, sub: 'Ariza', tone: 'orange', icon: '⏳' }),
        u.statCard({ label: 'Tasdiqlangan', value: rows.filter((d) => d.status === 'APPROVED').length, sub: 'Status', tone: 'violet', icon: '✓' }),
      ]),
      main: u.card('Hujjatlar galereyasi', cards.length ? `<div class="docs-grid">${cards.map((c) => `
        <div class="doc-card">
          <img src="${u.esc(c.url)}" alt="${u.esc(c.label)}" data-open="${u.esc(c.url)}" style="cursor:zoom-in" onerror="this.outerHTML='<div class=ph>Yuklanmadi</div>'" />
          <div class="cap">
            <div>${u.esc(c.label)} · ${u.pill(c.status)}</div>
            <div class="muted">${u.esc(c.name)} · #${c.driverId}</div>
            <button class="btn sm primary" style="margin-top:6px" data-drv="${c.driverId}">Batafsil</button>
          </div>
        </div>`).join('')}</div>` : u.table([], [], 'Hujjatlar yo‘q')),
    });
    content.querySelectorAll('[data-open]').forEach((img) => img.onclick = () => openLightbox(img.dataset.open));
    content.querySelectorAll('[data-drv]').forEach((b) => b.onclick = () => openDriverDetail(b.dataset.drv, { forReview: true }));
  }

  async function renderTrips() {
    const u = UI();
    const rows = await api()('/admin/trips');
    const active = rows.filter((t) => ['OPEN', 'FULL', 'IN_PROGRESS', 'CONFIRMED', 'SEARCHING', 'DRIVER_ACCEPTED'].includes(t.status));
    content.innerHTML = u.pageLayout({
      toolbarHtml: u.toolbar(exportButtons('trips')),
      stats: u.statRow([
        u.statCard({ label: 'Jami safarlar', value: rows.length, sub: 'E’lon va so‘rovlar', tone: 'blue', icon: '→' }),
        u.statCard({ label: 'Faol', value: active.length, sub: 'Ochiq / jarayonda', tone: 'green', icon: '◎' }),
        u.statCard({ label: 'Yakunlangan', value: rows.filter((t) => t.status === 'COMPLETED').length, sub: 'Status', tone: 'violet', icon: '✓' }),
        u.statCard({ label: 'Bekor', value: rows.filter((t) => ['CANCELLED', 'EXPIRED'].includes(t.status)).length, sub: 'Status', tone: 'red', icon: '✕' }),
      ]),
      main: u.card('Safarlar ro‘yxati', u.table([
        { label: 'ID', key: 'id', render: (r) => `#${r.id}` },
        { label: 'Turi', key: 'kind', render: (r) => u.pill(r.kind === 'request' ? 'SO‘ROV' : 'E’LON') },
        { label: 'Marshrut', key: 'from_text', render: (r) => u.routeCell(r.from_text, r.to_text) },
        { label: 'Haydovchi', key: 'driver_name', render: (r) => u.esc(r.driver_name || '—') },
        { label: 'Yo‘lovchi', key: 'passenger_name', render: (r) => u.esc(r.passenger_name || '—') },
        { label: 'Vaqt', key: 'scheduled_at', render: (r) => u.dt(r.scheduled_at) },
        { label: 'Narx', key: 'price', render: (r) => u.money(r.price) },
        { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
        { label: '', key: 'x', render: (r) => `<button class="btn sm primary" data-kind="${r.kind || 'trip'}" data-id="${r.id}">Batafsil</button>` },
      ], rows)),
      side: u.card('Faol safarlar', active.length ? active.slice(0, 8).map((t) =>
        `<div style="padding:8px 0;border-bottom:1px solid var(--border)"><b>#${t.id}</b> ${u.esc(t.from_text)} → ${u.esc(t.to_text)}<br>${u.pill(t.status)}</div>`
      ).join('') : '<p class="muted">Faol safar yo‘q</p>'),
    });
    content.querySelectorAll('[data-id]').forEach((b) => {
      b.onclick = () => {
        if (b.dataset.kind === 'request') openRequestDetail(b.dataset.id);
        else openTripDetail(b.dataset.id);
      };
    });
    bindExports(content);
  }

  async function renderRequests() {
    const u = UI();
    let tab = 'all';
    const all = await api()('/admin/requests');
    const draw = () => {
      const rows = tab === 'all' ? all : all.filter((r) => {
        if (tab === 'active') return ['SEARCHING', 'DRIVER_ACCEPTED', 'CONFIRMED', 'IN_PROGRESS'].includes(r.status);
        if (tab === 'completed') return r.status === 'COMPLETED';
        if (tab === 'cancelled') return ['CANCELLED', 'EXPIRED'].includes(r.status);
        return true;
      });
      content.innerHTML = u.pageLayout({
        stats: u.statRow([
          u.statCard({ label: 'Jami buyurtmalar', value: all.length, sub: 'So‘rovlar', tone: 'blue', icon: '☰' }),
          u.statCard({ label: 'Faol', value: all.filter((r) => ['SEARCHING', 'DRIVER_ACCEPTED', 'CONFIRMED', 'IN_PROGRESS'].includes(r.status)).length, sub: 'Jarayonda', tone: 'green', icon: '◎' }),
          u.statCard({ label: 'Yakunlangan', value: all.filter((r) => r.status === 'COMPLETED').length, sub: 'Status', tone: 'violet', icon: '✓' }),
          u.statCard({ label: 'Bekor', value: all.filter((r) => ['CANCELLED', 'EXPIRED'].includes(r.status)).length, sub: 'Status', tone: 'red', icon: '✕' }),
        ]),
        tabsHtml: u.tabs([
          { key: 'all', label: 'Barchasi', count: all.length },
          { key: 'active', label: 'Faol' },
          { key: 'completed', label: 'Yakunlangan' },
          { key: 'cancelled', label: 'Bekor qilingan' },
        ], tab),
        main: u.card('Buyurtmalar', u.table([
          { label: 'ID', key: 'id', render: (r) => `#${r.id}` },
          { label: 'Yo‘lovchi', key: 'passenger_name', render: (r) => u.userCell(r.passenger_name, r.passenger_phone) },
          { label: 'Marshrut', key: 'from_text', render: (r) => u.routeCell(r.from_text, r.to_text) },
          { label: 'Narx', key: 'offered_price', render: (r) => u.money(r.agreed_price || r.offered_price) },
          { label: 'Haydovchi', key: 'selected_driver_id', render: (r) => r.selected_driver_id ? `#${r.selected_driver_id}` : '—' },
          { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
          { label: 'Vaqt', key: 'created_at', render: (r) => u.dt(r.created_at) },
          { label: '', key: 'x', render: (r) => `<button class="btn sm primary" data-req="${r.id}">Batafsil</button>` },
        ], rows)),
      });
      u.bindTabs(content, (k) => { tab = k; draw(); });
      content.querySelectorAll('[data-req]').forEach((b) => b.onclick = () => openRequestDetail(b.dataset.req));
    };
    draw();
  }

  async function renderLocations() {
    const u = UI();
    const rows = await api()('/admin/locations');
    content.innerHTML = u.pageLayout({
      stats: u.statRow([
        u.statCard({ label: 'Jami joylar', value: rows.length, sub: 'Ro‘yxat', tone: 'blue', icon: '⌖' }),
        u.statCard({ label: 'Tasdiqlangan', value: rows.filter((l) => l.is_approved).length, sub: 'Joriy ro‘yxat', tone: 'green', icon: '✓' }),
        u.statCard({ label: 'Koordinatali', value: rows.filter((l) => l.latitude != null).length, sub: 'GPS bor', tone: 'violet', icon: '◎' }),
        u.statCard({ label: 'Aliasli', value: rows.filter((l) => (l.aliases || []).length).length, sub: 'Qidiruv', tone: 'orange', icon: '≡' }),
      ]),
      main: (u.card('Yangi joy qo‘shish', `<div class="page-toolbar" style="margin:0">
        <input id="locName" placeholder="Nomi" style="flex:1" />
        <select id="locType"><option>village</option><option>mahalla</option><option>city</option><option>district</option><option>OFY</option><option>landmark</option><option>other</option></select>
        <input id="locLat" placeholder="Lat" style="width:100px" />
        <input id="locLng" placeholder="Lng" style="width:100px" />
        <input id="locAliases" placeholder="Aliaslar (vergul bilan)" style="flex:1;min-width:180px" />
        <button class="btn primary" id="createLocBtn">Saqlash</button>
      </div>`)) + u.card('Joylar ro‘yxati', u.table([
        { label: 'ID', key: 'id', render: (r) => `#${r.id}` },
        { label: 'Nomi', key: 'name' },
        { label: 'Turi', key: 'type' },
        { label: 'Koordinata', key: 'latitude', render: (r) => r.latitude != null ? `${r.latitude}, ${r.longitude}` : '—' },
        { label: 'Alias', key: 'aliases', render: (r) => u.esc((r.aliases || []).join(', ') || '—') },
        { label: 'Holat', key: 'is_approved', render: (r) => u.pill(r.is_approved ? 'APPROVED' : 'PENDING') },
        { label: '', key: 'x', render: (r) => `<span data-loc="${r.id}" data-ok="${r.is_approved}"></span>` },
      ], rows)),
    });
    const createBtn = document.getElementById('createLocBtn');
    if (createBtn) {
      createBtn.onclick = async () => {
        const name = document.getElementById('locName').value.trim();
        const type = document.getElementById('locType').value;
        const aliases = document.getElementById('locAliases').value.split(',').map((s) => s.trim()).filter(Boolean);
        const latRaw = document.getElementById('locLat').value.trim();
        const lngRaw = document.getElementById('locLng').value.trim();
        const body = { name, type, aliases };
        if (latRaw) body.latitude = parseFloat(latRaw);
        if (lngRaw) body.longitude = parseFloat(lngRaw);
        await api()('/admin/locations', { method: 'POST', body: JSON.stringify(body) });
        navigate('locations');
      };
    }
    content.querySelectorAll('[data-loc]').forEach((cell) => {
      if (cell.getAttribute('data-ok') === 'true') {
        cell.innerHTML = '<span class="muted">—</span>';
        return;
      }
      const id = cell.getAttribute('data-loc');
      cell.innerHTML = `<button class="btn sm" data-act="ok">✅ Tasdiqlash</button><button class="btn sm danger" data-act="no">⛔ Rad</button>`;
      cell.querySelectorAll('button').forEach((b) => {
        b.onclick = async () => {
          await api()(`/admin/locations/${id}/${b.dataset.act === 'ok' ? 'approve' : 'reject'}`, { method: 'POST' });
          navigate('locations');
        };
      });
    });
  }

  function renderNotify() {
    const u = UI();
    content.innerHTML = u.pageLayout({
      stats: u.statRow([
        u.statCard({ label: 'Xabarnoma', value: 'Push', sub: 'Broadcast', tone: 'blue', icon: '🔔' }),
        u.statCard({ label: 'Auditoriya', value: '3', sub: 'Barcha / haydovchi / yo‘lovchi', tone: 'green', icon: '☺' }),
      ], 'cols-2'),
      main: u.card('Xabarnoma yuborish', `<div class="form-grid" style="max-width:640px">
        <div><label>Sarlavha</label><input id="nTitle" placeholder="Masalan: Yangilanish" /></div>
        <div><label>Xabar matni</label><textarea id="nBody" rows="5" placeholder="Foydalanuvchilarga xabar..."></textarea></div>
        <div><label>Kimga</label>
          <select id="nAud"><option value="all">Barcha foydalanuvchilar</option><option value="drivers">Faqat haydovchilar</option><option value="passengers">Faqat yo‘lovchilar</option></select>
        </div>
        <button class="btn primary" id="sendN">🔔 Yuborish</button>
        <p id="nMsg" class="muted"></p>
      </div>`),
    });
    document.getElementById('sendN').onclick = async () => {
      const res = await api()('/admin/notifications/broadcast', {
        method: 'POST',
        body: JSON.stringify({
          title: document.getElementById('nTitle').value.trim(),
          body: document.getElementById('nBody').value.trim(),
          audience: document.getElementById('nAud').value,
        }),
      });
      document.getElementById('nMsg').textContent = res.message || 'OK';
    };
  }

  async function renderSettings() {
    const u = UI();
    const s = await api()('/admin/settings');
    content.innerHTML = u.pageLayout({
      main: u.card('Tizim sozlamalari', `<div class="form-grid">${Object.entries(s).map(([k, v]) =>
        `<div><label>${u.esc(k)}</label><input data-k="${u.esc(k)}" value="${u.esc(v)}" /></div>`
      ).join('')}<button class="btn primary" id="saveSet">💾 Saqlash</button></div>`),
      side: u.card('Ma’lumot', `<p class="muted" style="margin:0;line-height:1.6">Versiya, maintenance va boshqa tizim parametrlari shu yerda saqlanadi. O‘zgarishlar ilova va API ga ta’sir qiladi.</p>`),
    });
    document.getElementById('saveSet').onclick = async () => {
      const payload = {};
      content.querySelectorAll('input[data-k]').forEach((el) => { payload[el.dataset.k] = el.value; });
      await api()('/admin/settings', { method: 'POST', body: JSON.stringify(payload) });
      alert('Saqlandi');
    };
  }

  async function renderProfile() {
    const u = UI();
    const me = await api()('/admin/auth/me');
    localStorage.setItem('safaron_admin', JSON.stringify(me));
    applyAdminChip(me);
    content.innerHTML = u.pageLayout({
      stats: u.statRow([
        u.statCard({ label: 'Rol', value: me.role === 'SUPER_ADMIN' ? 'Super' : 'Admin', sub: me.role, tone: 'blue', icon: '☺' }),
        u.statCard({ label: 'Holat', value: me.is_active ? 'Faol' : 'O‘chirilgan', sub: `ID #${me.id}`, tone: me.is_active ? 'green' : 'red', icon: '✓' }),
      ], 'cols-2'),
      main: u.card('Shaxsiy ma’lumotlar', `<div class="form-grid" style="max-width:520px">
        <div><label>To‘liq ism</label><input id="pfName" value="${u.esc(me.full_name || '')}" /></div>
        <div><label>Telefon</label><input id="pfPhone" value="${u.esc(me.phone || '')}" /></div>
        <div><label>Email</label><input id="pfEmail" type="email" value="${u.esc(me.email || '')}" placeholder="ixtiyoriy" /></div>
        <p class="muted" style="margin:0">Rol va ID o‘zgarmaydi. Boshqa admin profiliga kira olmaysiz.</p>
        <button class="btn primary" id="saveProfile">💾 Saqlash</button>
        <p id="pfMsg" class="muted"></p>
      </div>`),
      side: u.card('Parolni o‘zgartirish', `<div class="form-grid">
        <div><label>Joriy parol</label><input id="pwCur" type="password" autocomplete="current-password" /></div>
        <div><label>Yangi parol</label><input id="pwNew" type="password" autocomplete="new-password" /></div>
        <div><label>Yangi parolni tasdiqlang</label><input id="pwConfirm" type="password" autocomplete="new-password" /></div>
        <p class="muted" style="margin:0">Kamida 8 belgi, harf va raqam. Parol hech qachon ochiq saqlanmaydi.</p>
        <button class="btn primary" id="savePass">🔒 Parolni yangilash</button>
        <p id="pwMsg" class="muted"></p>
      </div>`),
    });
    document.getElementById('saveProfile').onclick = async () => {
      const msg = document.getElementById('pfMsg');
      msg.textContent = '';
      try {
        const updated = await api()('/admin/auth/me', {
          method: 'PATCH',
          body: JSON.stringify({
            full_name: document.getElementById('pfName').value.trim(),
            phone: document.getElementById('pfPhone').value.trim(),
            email: document.getElementById('pfEmail').value.trim(),
          }),
        });
        localStorage.setItem('safaron_admin', JSON.stringify(updated));
        applyAdminChip(updated);
        msg.textContent = 'Profil saqlandi.';
      } catch (ex) {
        msg.textContent = ex.message || 'Saqlanmadi.';
      }
    };
    document.getElementById('savePass').onclick = async () => {
      const msg = document.getElementById('pwMsg');
      msg.textContent = '';
      try {
        const res = await api()('/admin/auth/password', {
          method: 'POST',
          body: JSON.stringify({
            current_password: document.getElementById('pwCur').value,
            new_password: document.getElementById('pwNew').value,
            confirm_password: document.getElementById('pwConfirm').value,
          }),
        });
        document.getElementById('pwCur').value = '';
        document.getElementById('pwNew').value = '';
        document.getElementById('pwConfirm').value = '';
        msg.textContent = res.message || 'Parol yangilandi.';
      } catch (ex) {
        msg.textContent = ex.message || 'Parol yangilanmadi.';
      }
    };
  }

  async function renderLogs() {
    const u = UI();
    const rows = await api()('/admin/logs');
    content.innerHTML = u.pageLayout({
      stats: u.statRow([
        u.statCard({ label: 'Jami loglar', value: rows.length, sub: 'Admin harakatlari', tone: 'blue', icon: '≡' }),
        u.statCard({ label: 'Bugun', value: rows.filter((l) => l.created_at && new Date(l.created_at).toDateString() === new Date().toDateString()).length, sub: 'Joriy kun', tone: 'green', icon: '📅' }),
      ], 'cols-2'),
      main: u.card('Audit jurnali', u.table([
        { label: 'ID', key: 'id', render: (r) => `#${r.id}` },
        { label: 'Admin', key: 'admin_id', render: (r) => `#${r.admin_id}` },
        { label: 'Amal', key: 'action', render: (r) => `<code>${u.esc(r.action)}</code>` },
        { label: 'Ob’ekt', key: 'object_type', render: (r) => `${u.esc(r.object_type || '—')}${r.object_id ? ' #' + r.object_id : ''}` },
        { label: 'IP', key: 'ip', render: (r) => u.esc(r.ip || '—') },
        { label: 'Vaqt', key: 'created_at', render: (r) => u.dt(r.created_at) },
      ], rows)),
    });
  }

  const existing = localStorage.getItem('safaron_admin_token');
  if (existing) {
    api()('/admin/dashboard').then(() => showApp()).catch(() => {
      localStorage.removeItem('safaron_admin_token');
      localStorage.removeItem('safaron_admin');
      showLogin();
    });
  } else {
    showLogin();
  }
})();
