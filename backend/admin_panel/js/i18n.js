(function () {
  const STR = {
    uz: {
      login_title: 'SAFARON Admin',
      login_sub: 'Bir yo‘lda birga — boshqaruv paneli',
      phone: 'Telefon',
      password: 'Parol',
      login_btn: 'Kirish',
      logout: 'Chiqish',
      dashboard: 'Dashboard',
      users: 'Foydalanuvchilar',
      drivers: 'Haydovchilar',
      applications: 'Arizalar',
      documents: 'Hujjatlar',
      trips: 'Safarlar',
      requests: 'So‘rovlar',
      locations: 'Joylar',
      pending_locations: 'Yangi joylar',
      notifications: 'Bildirishnomalar',
      settings: 'Sozlamalar',
      logs: 'Loglar',
      overview: 'Umumiy ko‘rinish',
      save: 'Saqlash',
      approve: 'Tasdiqlash',
      reject: 'Rad etish',
      new_place: 'Yangi joy',
      name: 'Nomi',
      aliases: 'Aliaslar (vergul bilan)',
      latitude: 'Kenglik (lat)',
      longitude: 'Uzunlik (lng)',
    },
    ru: {
      login_title: 'SAFARON Admin',
      login_sub: 'Вместе в пути — панель управления',
      phone: 'Телефон',
      password: 'Пароль',
      login_btn: 'Войти',
      logout: 'Выход',
      dashboard: 'Панель',
      users: 'Пользователи',
      drivers: 'Водители',
      applications: 'Заявки',
      documents: 'Документы',
      trips: 'Поездки',
      requests: 'Запросы',
      locations: 'Места',
      pending_locations: 'Новые места',
      notifications: 'Уведомления',
      settings: 'Настройки',
      logs: 'Логи',
      overview: 'Обзор',
      save: 'Сохранить',
      approve: 'Одобрить',
      reject: 'Отклонить',
      new_place: 'Новое место',
      name: 'Название',
      aliases: 'Алиасы (через запятую)',
      latitude: 'Широта (lat)',
      longitude: 'Долгота (lng)',
    },
    kk: {
      login_title: 'SAFARON Admin',
      login_sub: 'Bir jolda birge — basqaru paneli',
      phone: 'Telefon',
      password: 'Parol',
      login_btn: 'Kiru',
      logout: 'Shygu',
      dashboard: 'Dashboard',
      users: 'Paydalanushilar',
      drivers: 'Haydovchilar',
      applications: 'Arizalar',
      documents: 'Hujjattar',
      trips: 'Safarlar',
      requests: 'Sorovlar',
      locations: 'Orınlar',
      pending_locations: 'Jańa orınlar',
      notifications: 'Xabarlar',
      settings: 'Sozlamalar',
      logs: 'Loglar',
      overview: 'Ulliq korinish',
      save: 'Saqlau',
      approve: 'Makullau',
      reject: 'Bas tartau',
      new_place: 'Jańa orın',
      name: 'Atı',
      aliases: 'Aliaslar (yıllıq)',
      latitude: 'Keńlik (lat)',
      longitude: 'Uzynlıq (lng)',
    },
    en: {
      login_title: 'SAFARON Admin',
      login_sub: 'On the road together — control panel',
      phone: 'Phone',
      password: 'Password',
      login_btn: 'Sign in',
      logout: 'Logout',
      dashboard: 'Dashboard',
      users: 'Users',
      drivers: 'Drivers',
      applications: 'Applications',
      documents: 'Documents',
      trips: 'Trips',
      requests: 'Requests',
      locations: 'Locations',
      pending_locations: 'Pending locations',
      notifications: 'Notifications',
      settings: 'Settings',
      logs: 'Logs',
      overview: 'Overview',
      save: 'Save',
      approve: 'Approve',
      reject: 'Reject',
      new_place: 'New place',
      name: 'Name',
      aliases: 'Aliases (comma separated)',
      latitude: 'Latitude',
      longitude: 'Longitude',
    },
  };

  let lang = localStorage.getItem('safaron_admin_lang') || 'uz';

  function t(key) {
    return (STR[lang] && STR[lang][key]) || STR.uz[key] || key;
  }

  function setLang(code) {
    lang = STR[code] ? code : 'uz';
    localStorage.setItem('safaron_admin_lang', lang);
    applyStatic();
  }

  function applyStatic() {
    const h1 = document.querySelector('#loginView h1');
    if (h1) h1.textContent = t('login_title');
    const sub = document.querySelector('#loginView .muted');
    if (sub) sub.textContent = t('login_sub');
    const labels = document.querySelectorAll('#loginView label');
    if (labels[0]) labels[0].textContent = t('phone');
    if (labels[1]) labels[1].textContent = t('password');
    const btn = document.getElementById('loginBtn');
    if (btn && !btn.disabled) btn.textContent = t('login_btn');
    const logout = document.getElementById('logoutBtn');
    if (logout) logout.textContent = t('logout');
    document.querySelectorAll('#nav button[data-page]').forEach((b) => {
      const p = b.getAttribute('data-page');
      const map = {
        dashboard: 'dashboard',
        users: 'users',
        drivers: 'drivers',
        applications: 'applications',
        documents: 'documents',
        trips: 'trips',
        requests: 'requests',
        locations: 'locations',
        pendingLocations: 'pending_locations',
        notifications: 'notifications',
        settings: 'settings',
        logs: 'logs',
      };
      const key = map[p];
      if (!key) return;
      const ico = b.querySelector('.ico');
      const icon = ico ? ico.outerHTML : '';
      b.innerHTML = `${icon} ${t(key)}`;
    });
  }

  window.SafaronI18n = { t, setLang, getLang: () => lang, applyStatic };
})();
