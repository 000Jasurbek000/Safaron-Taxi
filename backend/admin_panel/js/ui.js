(function () {
  const COLORS = {
    blue: '#00c853',
    blueLight: '#e8f7ef',
    green: '#00c853',
    greenLight: '#e8f7ef',
    orange: '#ffc107',
    orangeLight: '#fff8e1',
    red: '#ef4444',
    redLight: '#fee2e2',
    violet: '#8b5cf6',
    violetLight: '#ede9fe',
    navy: '#0f2744',
    chart: ['#2563eb', '#10b981', '#f59e0b', '#8b5cf6', '#06b6d4', '#ef4444'],
  };

  let charts = [];

  function esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  function money(n) {
    return `${Number(n || 0).toLocaleString('uz-UZ')} so‘m`;
  }

  function dt(v) {
    if (!v) return '—';
    try { return new Date(v).toLocaleString('uz-UZ'); } catch { return String(v); }
  }

  function initials(name) {
    const p = String(name || '?').trim().split(/\s+/);
    return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || '?';
  }

  function avatar(name, url, size) {
    const cls = size === 'sm' ? 'u-avatar sm' : 'u-avatar';
    if (url) return `<img class="${cls}" src="${esc(url)}" alt="" onerror="this.replaceWith(Object.assign(document.createElement('span'),{className:'${cls} ph',textContent:'${esc(initials(name))}'}))" />`;
    return `<span class="${cls} ph">${esc(initials(name))}</span>`;
  }

  const STATUS = {
    ACTIVE: ['Faol', 'ok'], APPROVED: ['Tasdiqlangan', 'ok'], COMPLETED: ['Yakunlandi', 'ok'],
    VERIFIED: ['Tasdiqlandi', 'ok'], PAID: ['To‘langan', 'ok'], OPEN: ['Ochiq', 'blue'],
    PENDING: ['Kutilmoqda', 'warn'], SEARCHING: ['Qidiruv', 'warn'], DRIVER_ACCEPTED: ['Qabul', 'blue'],
    CONFIRMED: ['Tasdiqlandi', 'ok'], IN_PROGRESS: ['Jarayonda', 'blue'], FULL: ['To‘lgan', 'blue'],
    BLOCKED: ['Bloklangan', 'bad'], REJECTED: ['Rad etilgan', 'bad'], CANCELLED: ['Bekor', 'bad'],
    EXPIRED: ['Muddati o‘tgan', 'bad'], SUSPENDED: ['To‘xtatilgan', 'bad'], FRAUD_REVIEW: ['Shubhali', 'warn'],
  };

  function pill(status, custom) {
    const s = String(status || '—').toUpperCase();
    const [label, tone] = custom || STATUS[s] || [status || '—', ''];
    return `<span class="pill ${tone}">${esc(label)}</span>`;
  }

  function destroyCharts() {
    charts.forEach((c) => { try { c.destroy(); } catch (_) {} });
    charts = [];
  }

  function makeChart(canvas, config) {
    if (!canvas || typeof Chart === 'undefined') return null;
    const c = new Chart(canvas, config);
    charts.push(c);
    return c;
  }

  function statCard({ label, value, sub, tone = 'blue', icon = '◆' }) {
    return `<div class="stat-card ${tone}">
      <div class="stat-icon">${icon}</div>
      <div class="stat-body">
        <div class="stat-label">${esc(label)}</div>
        <div class="stat-value">${value}</div>
        ${sub ? `<div class="stat-sub">${esc(sub)}</div>` : ''}
      </div>
    </div>`;
  }

  function statRow(cards, cls = '') {
    return `<div class="stat-row ${cls}">${cards.join('')}</div>`;
  }

  function tabs(items, active) {
    return `<div class="tab-bar">${items.map((t) =>
      `<button type="button" class="tab ${t.key === active ? 'active' : ''}" data-tab="${esc(t.key)}">${esc(t.label)}${t.count != null ? ` <span class="tab-count">${t.count}</span>` : ''}</button>`
    ).join('')}</div>`;
  }

  function toolbar(inner) {
    return `<div class="page-toolbar">${inner}</div>`;
  }

  function searchInput(id, placeholder) {
    return `<div class="search-field"><span class="search-ico">⌕</span><input id="${id}" type="search" placeholder="${esc(placeholder)}" /></div>`;
  }

  function btn(label, cls = 'btn primary', attrs = '') {
    return `<button type="button" class="${cls}" ${attrs}>${label}</button>`;
  }

  function card(title, body, foot = '') {
    return `<div class="panel-card">
      ${title ? `<div class="panel-head"><h3>${title}</h3>${foot}</div>` : ''}
      <div class="panel-body">${body}</div>
    </div>`;
  }

  function table(columns, rows, emptyText) {
    if (!rows || !rows.length) {
      return `<div class="table-empty">${esc(emptyText || 'Ma’lumot yo‘q')}</div>`;
    }
    const head = columns.map((c) => `<th>${esc(c.label)}</th>`).join('');
    const body = rows.map((r) => `<tr>${columns.map((c) => `<td>${typeof c.render === 'function' ? c.render(r) : esc(r[c.key])}</td>`).join('')}</tr>`).join('');
    return `<div class="data-table"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
  }

  function userCell(name, sub) {
    return `<div class="user-cell">${avatar(name)}<div><div class="u-name">${esc(name)}</div>${sub ? `<div class="u-sub">${esc(sub)}</div>` : ''}</div></div>`;
  }

  function routeCell(from, to) {
    return `<div class="route-cell"><span class="route-from">${esc(from || '—')}</span><span class="route-arrow">→</span><span class="route-to">${esc(to || '—')}</span></div>`;
  }

  function pageLayout({ stats = '', tabsHtml = '', toolbarHtml = '', main = '', side = '', charts = '' }) {
    return `${stats}${tabsHtml}${toolbarHtml}
      ${charts}
      <div class="page-grid ${side ? 'has-side' : ''}">
        <div class="page-main">${main}</div>
        ${side ? `<aside class="page-side">${side}</aside>` : ''}
      </div>`;
  }

  function bindTabs(container, onChange) {
    container.querySelectorAll('[data-tab]').forEach((b) => {
      b.onclick = () => onChange(b.dataset.tab);
    });
  }

  window.SafaronUI = {
    COLORS, esc, money, dt, initials, avatar, pill, destroyCharts, makeChart,
    statCard, statRow, tabs, toolbar, searchInput, btn, card, table, userCell, routeCell, pageLayout, bindTabs,
  };
})();
