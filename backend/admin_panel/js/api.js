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

  window.SafaronAdminApi = { api, token, API_BASE };
})();
