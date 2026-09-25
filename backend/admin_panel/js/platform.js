(function () {
  const UI = () => window.SafaronUI;

  async function render(page, content, api) {
    const u = UI();
    u.destroyCharts();

    if (page === 'bonuses') return renderBonuses(content, api, u);
    if (page === 'referrals') return renderReferrals(content, api, u);
    if (page === 'withdrawals') return renderWithdrawals(content, api, u);
    if (page === 'fraud') return renderFraud(content, api, u);
    if (page === 'flags') return renderFlags(content, api, u);
  }

  async function renderBonuses(content, api, u) {
    const [stats, pending, approved, dash] = await Promise.all([
      api('/admin/platform/stats'),
      api('/admin/platform/bonuses?status=PENDING'),
      api('/admin/platform/bonuses?status=APPROVED'),
      api('/admin/dashboard'),
    ]);
    let tab = 'PENDING';
    const draw = async () => {
      const d = await api(`/admin/platform/bonuses?status=${tab}`);
      content.innerHTML = u.pageLayout({
        stats: u.statRow([
          u.statCard({ label: 'Jami berilgan bonus', value: u.money(stats.bonus_paid), sub: 'Tasdiqlangan', tone: 'green', icon: '★' }),
          u.statCard({ label: 'Kutilayotgan', value: stats.pending_bonus, sub: 'Tasdiqlash kerak', tone: 'orange', icon: '⏳' }),
          u.statCard({ label: 'Tasdiqlangan tranzaksiya', value: approved.total, sub: 'Jami yozuv', tone: 'blue', icon: '✓' }),
          u.statCard({ label: 'Referallar', value: stats.referrals, sub: 'Jami taklif', tone: 'violet', icon: '⚭' }),
        ]),
        charts: `<div class="charts-grid cols-2">
          ${u.card('Oxirgi 7 kun — bonus operatsiyalari', '<div class="chart-box"><canvas id="chartBonusLine"></canvas></div>')}
          ${u.card('Bonus holati', '<div class="chart-box"><canvas id="chartBonusPie"></canvas></div>')}
        </div>`,
        tabsHtml: u.tabs([
          { key: 'PENDING', label: 'Kutilmoqda', count: pending.total },
          { key: 'APPROVED', label: 'Tasdiqlangan', count: approved.total },
          { key: 'REJECTED', label: 'Rad etilgan' },
        ], tab),
        main: u.card('', u.table([
          { label: 'ID', key: 'id' },
          { label: 'Foydalanuvchi', key: 'user_id', render: (r) => `#${r.user_id}` },
          { label: 'Summa', key: 'amount', render: (r) => u.money(r.amount) },
          { label: 'Manba', key: 'source' },
          { label: 'Tavsif', key: 'description', render: (r) => u.esc(r.description || '—') },
          { label: 'Vaqt', key: 'created_at', render: (r) => u.dt(r.created_at) },
          { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
          { label: '', key: 'x', render: (r) => tab === 'PENDING'
            ? `<div class="row-actions"><button class="btn sm success" data-ok="${r.id}">Tasdiq</button><button class="btn sm danger" data-no="${r.id}">Rad</button></div>`
            : '' },
        ], d.items, 'Bonus yozuvi yo‘q')),
      });
      u.bindTabs(content, (k) => { tab = k; draw(); });
      content.querySelectorAll('[data-ok]').forEach((b) => b.onclick = async () => {
        if (!confirm('Bonusni tasdiqlaysizmi?')) return;
        await api('/admin/platform/bonuses/' + b.dataset.ok + '/approve', { method: 'POST' });
        draw();
      });
      content.querySelectorAll('[data-no]').forEach((b) => b.onclick = async () => {
        const note = prompt('Rad sababi') || '';
        await api('/admin/platform/bonuses/' + b.dataset.no + '/reject', { method: 'POST', body: JSON.stringify({ note }) });
        draw();
      });
      const days = dash.chart_days || [];
      u.makeChart(document.getElementById('chartBonusLine'), {
        type: 'line',
        data: {
          labels: days.map((x) => x.label),
          datasets: [{ label: 'So‘rovlar', data: days.map((x) => x.requests), borderColor: u.COLORS.blue, backgroundColor: 'rgba(37,99,235,.12)', fill: true, tension: .35 }],
        },
        options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } },
      });
      u.makeChart(document.getElementById('chartBonusPie'), {
        type: 'doughnut',
        data: {
          labels: ['Kutilmoqda', 'Tasdiqlangan'],
          datasets: [{ data: [pending.total, approved.total], backgroundColor: [u.COLORS.orange, u.COLORS.green] }],
        },
        options: { cutout: '65%', plugins: { legend: { position: 'bottom' } } },
      });
    };
    await draw();
  }

  async function renderReferrals(content, api, u) {
    const [stats, dash, refData] = await Promise.all([
      api('/admin/platform/stats'),
      api('/admin/dashboard'),
      api('/admin/platform/referrals'),
    ]);
    const top = dash.top_referrers || [];
    content.innerHTML = u.pageLayout({
      stats: u.statRow([
        u.statCard({ label: 'Jami referallar', value: stats.referrals, sub: 'Ro‘yxatdan o‘tgan', tone: 'blue', icon: '⚭' }),
        u.statCard({ label: 'Bugun yangi user', value: stats.new_users_today, sub: 'Ro‘yxat', tone: 'green', icon: '＋' }),
        u.statCard({ label: 'Tasdiqlangan safar', value: stats.verified_trips, sub: 'Bonus sharti', tone: 'violet', icon: '→' }),
        u.statCard({ label: 'Bonus to‘langan', value: u.money(stats.bonus_paid), sub: 'Jami', tone: 'orange', icon: '★' }),
      ]),
      charts: `<div class="charts-grid cols-2">
        ${u.card('Referal o‘sishi (7 kun — yangi foydalanuvchilar)', '<div class="chart-box"><canvas id="chartRefLine"></canvas></div>')}
        ${u.card('Top referrers', `<div class="data-table"><table><thead><tr><th>Foydalanuvchi</th><th>Kod</th><th>Soni</th></tr></thead><tbody>
          ${top.map((r) => `<tr><td>${u.userCell(r.name)}</td><td><code>${u.esc(r.code)}</code></td><td><b>${r.count}</b></td></tr>`).join('') || '<tr><td colspan="3" class="muted">Hali yo‘q</td></tr>'}
        </tbody></table></div>`)}
      </div>`,
      main: u.card('Referal jurnali', u.table([
        { label: 'ID', key: 'id' },
        { label: 'Taklif qilgan', key: 'referrer_id', render: (r) => `#${r.referrer_id}` },
        { label: 'Taklif qilingan', key: 'referred_id', render: (r) => `#${r.referred_id}` },
        { label: 'Kod', key: 'code', render: (r) => `<code>${u.esc(r.code)}</code>` },
        { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
      ], refData.items, 'Referal yozuvi yo‘q')),
    });
    const days = dash.chart_days || [];
    u.makeChart(document.getElementById('chartRefLine'), {
      type: 'line',
      data: {
        labels: days.map((x) => x.label),
        datasets: [{ label: 'Yangi user', data: days.map((x) => x.users), borderColor: u.COLORS.green, backgroundColor: 'rgba(16,185,129,.15)', fill: true, tension: .35 }],
      },
      options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } } },
    });
  }

  async function renderWithdrawals(content, api, u) {
    let tab = 'PENDING';
    const draw = async () => {
      const q = tab === 'ALL' ? '?status=ALL' : `?status=${tab}`;
      const d = await api('/admin/platform/withdrawals' + q);
      const stats = await api('/admin/platform/stats');
      content.innerHTML = u.pageLayout({
        stats: u.statRow([
          u.statCard({ label: 'Kutilayotgan yechim', value: stats.pending_withdrawal, sub: 'Tasdiqlash kerak', tone: 'orange', icon: '⏳' }),
          u.statCard({ label: 'Jami bonus berilgan', value: u.money(stats.bonus_paid), sub: 'Tizim bo‘yicha', tone: 'green', icon: '★' }),
          u.statCard({ label: 'Ko‘rsatilmoqda', value: d.total, sub: 'Tanlangan holat', tone: 'blue', icon: '₸' }),
          u.statCard({ label: 'Foydalanuvchilar', value: stats.users, sub: 'Faol hisoblar', tone: 'violet', icon: '☺' }),
        ]),
        tabsHtml: u.tabs([
          { key: 'PENDING', label: 'Kutilmoqda' },
          { key: 'APPROVED', label: 'Tasdiqlangan' },
          { key: 'PAID', label: 'To‘langan' },
          { key: 'REJECTED', label: 'Rad etilgan' },
          { key: 'ALL', label: 'Barchasi' },
        ], tab),
        toolbarHtml: u.toolbar(`<a class="btn ghost sm" href="/api/admin/platform/export/withdrawals.csv" target="_blank">CSV eksport</a>`),
        main: u.card('Bonus yechim so‘rovlari', u.table([
          { label: 'ID', key: 'id' },
          { label: 'Foydalanuvchi', key: 'user_id', render: (r) => `#${r.user_id}` },
          { label: 'Summa', key: 'amount', render: (r) => u.money(r.amount) },
          { label: 'Telegram', key: 'telegram_username', render: (r) => u.esc(r.telegram_username || '—') },
          { label: 'Vaqt', key: 'created_at', render: (r) => u.dt(r.created_at) },
          { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
          { label: '', key: 'a', render: (r) => r.status === 'PENDING'
            ? `<div class="row-actions">
                <button class="btn sm success" data-a="approve" data-id="${r.id}">Tasdiq</button>
                <button class="btn sm primary" data-a="paid" data-id="${r.id}">To‘landi</button>
                <button class="btn sm danger" data-a="reject" data-id="${r.id}">Rad</button>
              </div>` : '' },
        ], d.items, 'So‘rov yo‘q')),
      });
      u.bindTabs(content, (k) => { tab = k; draw(); });
      content.querySelectorAll('[data-a]').forEach((b) => b.onclick = async () => {
        if (!confirm('Amalni tasdiqlaysizmi?')) return;
        const note = b.dataset.a === 'reject' ? (prompt('Sabab') || 'Rad etildi') : null;
        await api('/admin/platform/withdrawals/' + b.dataset.id + '/' + b.dataset.a, { method: 'POST', body: JSON.stringify({ note }) });
        draw();
      });
    };
    await draw();
  }

  async function renderFraud(content, api, u) {
    const [rows, stats] = await Promise.all([
      api('/admin/platform/fraud'),
      api('/admin/platform/stats'),
    ]);
    const open = rows.filter((r) => r.status === 'OPEN');
    content.innerHTML = u.pageLayout({
      stats: u.statRow([
        u.statCard({ label: 'Ochiq shubhalar', value: stats.fraud_open, sub: 'Ko‘rib chiqish kerak', tone: 'red', icon: '⚠' }),
        u.statCard({ label: 'Jami hodisa', value: rows.length, sub: 'Oxirgi 50 ta', tone: 'orange', icon: '≡' }),
        u.statCard({ label: 'Tasdiqlangan safar', value: stats.verified_trips, sub: 'Bonus uchun', tone: 'green', icon: '✓' }),
        u.statCard({ label: 'Foydalanuvchilar', value: stats.users, sub: 'Jami', tone: 'blue', icon: '☺' }),
      ]),
      main: u.card('Shubhali safarlar va fraud', u.table([
        { label: 'ID', key: 'id' },
        { label: 'User', key: 'user_id', render: (r) => `#${r.user_id}` },
        { label: 'Kod', key: 'code' },
        { label: 'Daraja', key: 'severity', render: (r) => u.pill(r.severity, [r.severity, r.severity === 'HIGH' ? 'bad' : 'warn']) },
        { label: 'Holat', key: 'status', render: (r) => u.pill(r.status) },
        { label: 'Tafsilot', key: 'details', render: (r) => u.esc((r.details || '—').slice(0, 80)) },
        { label: '', key: 'x', render: (r) => r.status === 'OPEN' ? `<button class="btn sm primary" data-id="${r.id}">Yopish</button>` : '' },
      ], rows, 'Hodisa yo‘q')),
      side: u.card('Ochiq ishlar', open.length
        ? open.map((r) => `<div style="padding:8px 0;border-bottom:1px solid var(--border)"><b>#${r.id}</b> · User #${r.user_id}<br><span class="muted">${u.esc(r.code)}</span></div>`).join('')
        : '<p class="muted">Ochiq shubha yo‘q</p>'),
    });
    content.querySelectorAll('button[data-id]').forEach((b) => b.onclick = async () => {
      await api('/admin/platform/fraud/' + b.dataset.id + '/close', { method: 'POST' });
      render('fraud', content, api);
    });
  }

  async function renderFlags(content, api, u) {
    const [flags, rules, fr, settings] = await Promise.all([
      api('/admin/platform/flags'),
      api('/admin/platform/bonus-rules'),
      api('/admin/platform/fraud-rules'),
      api('/admin/settings'),
    ]);
    content.innerHTML = u.pageLayout({
      main: `<div class="settings-grid">
        ${u.card('Ilova funksiyalari', flags.map((f) => `
          <div class="flag-row">
            <div><b>${u.esc(f.key)}</b><div class="muted" style="font-size:12px">${u.esc(f.description || '')}</div></div>
            <button type="button" class="toggle ${f.enabled ? 'on' : ''}" data-flag="${u.esc(f.key)}" aria-label="${u.esc(f.key)}"></button>
          </div>`).join(''))}
        ${u.card('Bonus qoidalari', rules.map((r) => `
          <div class="rule-row">
            <div><b>${u.esc(r.title)}</b><div class="muted" style="font-size:12px">${u.esc(r.key)}</div></div>
            <input data-amt="${u.esc(r.key)}" value="${r.amount}" /> so‘m
            <input data-trips="${u.esc(r.key)}" value="${r.required_trips}" /> safar
            <button class="btn sm primary" data-save="${u.esc(r.key)}">Saqlash</button>
          </div>`).join(''))}
      </div>`,
      side: `${u.card('Fraud chegaralari', `<pre style="margin:0;font-size:12px;white-space:pre-wrap">${u.esc(JSON.stringify(fr, null, 2))}</pre>`)}
        ${u.card('Versiya', `<div class="form-grid">
          <label>App versiya</label><input value="${u.esc(settings.app_version || settings.version || '1.1.0')}" disabled />
          <label>Min versiya</label><input value="${u.esc(settings.min_app_version || '1.0.0')}" disabled />
          <p class="muted" style="margin:0;font-size:12px">Versiyani Tizim sozlamalaridan o‘zgartiring.</p>
        </div>`)}`,
    });
    content.querySelectorAll('[data-flag]').forEach((el) => {
      el.onclick = async () => {
        const on = !el.classList.contains('on');
        await api('/admin/platform/flags/' + el.dataset.flag, { method: 'PATCH', body: JSON.stringify({ enabled: on }) });
        el.classList.toggle('on', on);
      };
    });
    content.querySelectorAll('[data-save]').forEach((b) => b.onclick = async () => {
      const key = b.dataset.save;
      const amount = Number(content.querySelector(`[data-amt="${key}"]`).value);
      const required_trips = Number(content.querySelector(`[data-trips="${key}"]`).value);
      await api('/admin/platform/bonus-rules/' + key, { method: 'PATCH', body: JSON.stringify({ amount, required_trips }) });
      alert('Saqlandi');
    });
  }

  window.SafaronPlatform = { render };
})();
