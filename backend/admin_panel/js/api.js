(function () {
  const API_BASE = `${location.origin}/api`;

  function token() {
    return localStorage.getItem('safaron_admin_token') || '';
  }

  function formatDetail(detail) {
    if (!detail) return 'Xatolik';
    if (typeof detail === 'string') return detail;
    if (Array.isArray(detail)) {
      return detail.map((d) => d.msg || JSON.stringify(d)).join('; ');
    }
    return JSON.stringify(detail);
  }

  async function api(path, opts = {}) {
    const headers = { ...(opts.headers || {}) };
    if (!(opts.body instanceof FormData)) headers['Content-Type'] = 'application/json';
    if (token()) headers.Authorization = `Bearer ${token()}`;

    let res;
    try {
      res = await fetch(`${API_BASE}${path}`, { ...opts, headers });
    } catch (e) {
      throw new Error('Serverga ulanib bo‘lmadi. API ishlayotganini tekshiring: ' + API_BASE);
    }

    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(formatDetail(data.detail) || ('Xatolik ' + res.status));
    }
    return data;
  }

  async function download(path, filename) {
    const headers = {};
    if (token()) headers.Authorization = `Bearer ${token()}`;
    let res;
    try {
      res = await fetch(`${API_BASE}${path}`, { headers });
    } catch (e) {
      throw new Error('Serverga ulanib bo‘lmadi.');
    }
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(formatDetail(data.detail) || ('Eksport xato ' + res.status));
    }
    const blob = await res.blob();
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1500);
  }

  window.SafaronAdminApi = { api, token, API_BASE, download };
})();
