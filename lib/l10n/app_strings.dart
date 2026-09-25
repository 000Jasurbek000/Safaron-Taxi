import 'package:flutter/material.dart';

import '../services/profile_service.dart';

/// Asosiy UI matnlari — til sozlamasi bo‘yicha.
class AppStrings {
  AppStrings._();

  static String get lang => ProfileService.instance.languageUiCode;

  static Locale localeFor(String code) => switch (code) {
        'ru' => const Locale('ru'),
        'kk' => const Locale('kk'),
        'uz_cyrl' => const Locale('uz', 'Cyrl'),
        _ => const Locale('uz'),
      };

  static String t(String key) {
    final table = _strings[lang] ?? _strings['uz']!;
    return table[key] ?? _strings['uz']![key] ?? key;
  }

  static const _strings = <String, Map<String, String>>{
    'uz': _uz,
    'uz_cyrl': _uzCyrl,
    'ru': _ru,
    'kk': _kk,
  };

  // ============================================================
  // O'ZBEK TILI — LOTIN
  // ============================================================

  static const _uz = {
    'home_title': 'Qayerga borasiz?',
    'from': 'Qayerdan?',
    'to': 'Qayerga?',
    'pick_place': 'Manzilni tanlang',
    'other_place': 'Boshqa manzil',
    'find_taxi': 'Taksi topish',
    'route_distance': 'Yo‘l masofasi',
    'driver_distance': 'Sizgacha masofa',
    'language_settings': 'Til sozlamalari',

    'nav_home': 'Bosh sahifa',
    'nav_trips': 'Safarlarim',
    'nav_messages': 'Xabarlar',
    'nav_profile': 'Profil',
    'nav_order': 'Buyurtma',
    'nav_create_trip': 'Safar yaratish',
    'nav_my_trips': 'Safarlarim',

    'exit_title': 'Chiqasizmi?',
    'exit_message': 'Ilovadan chiqishni xohlaysizmi?',
    'yes': 'Ha',
    'no': 'Yo‘q',
    'cancel': 'Bekor qilish',

    'popular_routes': 'Mashhur yo‘nalishlar',
    'see_all': 'Barchasini ko‘rish',
    'locating': 'Aniqlanmoqda...',
    'tap_to_refresh': 'Yangilash uchun bosing',

    'exact_pickup': 'Aniq olib ketish joyi',
    'edit': 'O‘zgartirish',
    'passengers': 'Yo‘lovchilar',

    'enter_addresses':
        'Qayerdan va Qayerga manzillarini kiriting',

    'prebook_title': 'Oldindan bron qilish',
    'prebook_subtitle':
        'Sana va vaqtni tanlab, oldindan buyurtma bering',

    'profile': 'Profil',
    'register_first': 'Avval ro‘yxatdan o‘ting',
    'register_hint':
        'Profil, safarlar va xabarlar uchun telefon orqali ro‘yxatdan o‘ting.',
    'register_btn': 'Ro‘yxatdan o‘tish',

    'user_default': 'Foydalanuvchi',
    'driver': 'Haydovchi',
    'passenger': 'Yo‘lovchi',
    'rating': 'Reyting',
    'trip': 'Safar',
    'experience': 'Tajriba',
    'years_suffix': 'yil',

    'menu_orders': 'Buyurtmalar',
    'menu_create_trip': 'Safar yaratish',
    'menu_my_car': 'Mening avtomobilim',
    'menu_messages': 'Xabarlar',
    'menu_earnings': 'Daromadlarim',
    'menu_appearance': 'Ko‘rinish',
    'menu_settings': 'Sozlamalar',
    'menu_language': 'Til sozlamalari',
    'menu_faq': 'Tez-tez so‘raladigan savollar',
    'menu_help': 'Yordam',
    'menu_about': 'Ilova haqida',
    'menu_logout': 'Chiqish',

    'theme_light': 'Kunduzgi',
    'theme_dark': 'Tungi',
    'theme_auto': 'Avtomatik',
    'appearance': 'Ko‘rinish',
    'new_badge': 'Yangi',

    'become_driver_prompt': 'Haydovchi bo‘lishni xohlaysizmi?',

    'logout_title': 'Chiqish',
    'logout_confirm': 'Haqiqatan ham hisobdan chiqasizmi?',
    'logged_out': 'Hisobdan chiqildi',

    'register_title': 'Ro‘yxatdan o‘tish',
    'register_subtitle':
        'Ism, familiya va telefon raqamingiz yetarli',
    'first_name': 'Ism *',
    'last_name': 'Familiya *',
    'continue_btn': 'Davom etish',

    'waiting': 'Kutilmoqda...',
    'server_error':
        'Serverga ulanib bo‘lmadi. Internet va Wi-Fi ni tekshiring.',

    'language_pick_title': 'Tilni tanlang',
    'language_pick_subtitle': 'Faqat birinchi marta so‘raladi',
    'start_btn': 'Boshlash',

    'pending_application':
        'Arizangiz tekshirilmoqda. Natija bildirishnoma orqali keladi.',

    'messages_title': 'Xabarlar',
    'messages_register_hint':
        'Xabarlarni ko‘rish uchun avval ro‘yxatdan o‘ting',
    'messages_subtitle':
        'Haydovchilar bilan yozishmalaringiz shu yerda saqlanadi',

    'settings_title': 'Sozlamalar',
    'personal_info': 'Shaxsiy ma’lumotlar',
    'first_name_short': 'Ism',
    'last_name_short': 'Familiya',
    'experience_years': 'Tajriba (yil)',

    'save': 'Saqlash',
    'saving': 'Saqlanmoqda...',
    'saved': 'Saqlandi',

    'phone_number': 'Telefon raqami',
    'phone_change_hint':
        'Raqamni o‘zgartirish SMS tasdiqlash bilan keyingi yangilanishda qo‘shiladi.',

    'faq_title': 'Tez-tez so‘raladigan savollar',
    'help_title': 'Yordam',
    'about_title': 'Ilova haqida',

    'exact_pickup_title': 'Aniq olib ketish joyi',
    'exact_pickup_desc':
        'Asosiy manzillar taksi topish uchun. Haydovchi sizni aniq qayerdan olib ketishini yozing.',
    'route_label': 'Yo‘nalish',
    'exact_pickup_hint': 'Masalan: 44-maktab oldi',
    'exact_pickup_examples':
        'Masalan: 44-maktab oldi, bozor darvozasi, OFY binosi yonida',
    'exact_pickup_required': 'Aniq olib ketish joyini yozing',

    'available_taxis': 'Mavjud taksilar',
    'pickup_label': 'Olib ketish',

    'today': 'Bugun',
    'tomorrow': 'Ertaga',
    'all': 'Barchasi',

    'taxi_count_fmt': 'ta taksi · onlayn va oflayn',

    'morning': 'Ertalab',
    'afternoon': 'Kunduz',
    'evening': 'Kechqurun',

    'prebook_subtitle_short':
        'Kerakli sana va vaqtga buyurtma',

    'waiting_drivers':
        'Haydovchilar javobini kutmoqdamiz...',

    'waiting_broadcast':
        'So‘rovingiz yaqin atrofdagi barcha haydovchilarga yuborildi.',

    'waiting_time_label': 'Kutilayotgan vaqt',
    'up_to_1_hour': '(1 soatgacha)',

    'trip_on_way': 'Safarda',
    'driver_on_way': 'Haydovchi yo‘lda',
    'driver_coming': 'Haydovchi siz tomonga harakatlanmoqda',

    'online_status': 'Onlayn',
    'offline_status': 'Oflayn',

    'orders_coming': 'Buyurtmalar keladi',

    'referral_code_optional': 'Taklif kodi (ixtiyoriy)',

    'taxis_hint':
        'Manzil yozing — mos yo‘nalishlar darhol chiqadi',

    'taxis_empty': 'Taksi mavjud emas',
    'taxis_empty_hint':
        'Hozircha ro‘yxatda taksi yo‘q. Keyinroq qayta urinib ko‘ring.',

    'taxis_no_match': 'Mos taksi topilmadi',
    'taxis_no_match_hint':
        'Boshqa manzil yozing yoki filtrni o‘zgartiring.',

    'menu_rewards': 'Bonus va do‘st taklifi',

    'rewards_title': 'Bonus va do‘st taklifi',
    'rewards_subtitle':
        'Kodni ulashing, shartlarni bajaring va bonus oling',

    'copy_code': 'Kodni nusxalash',
    'share': 'Ulashish',
    'copied': 'Nusxalandi',

    'invited': 'Taklif qilinganlar',
    'successful': 'Muvaffaqiyatli',

    'bonus_earned': 'Olingan bonus',
    'bonus_balance': 'Mavjud bonus',
    'bonus_held': 'Yechishda band',

    'withdraw': 'Bonusni yechib olish',

    'bonus_rules_title': 'Bonus shartlari',
    'bonus_rules_note':
        'Summalar admin panelda belgilanadi. Admin o‘zgartirsa, shu yerda yangilanadi.',

    'bonus_history': 'Bonus tarixi',
    'withdraw_history': 'Yechib olish tarixi',

    'telegram_username': 'Telegram username',

    'no_bonus_to_withdraw':
        'Sizda yechib olish uchun bonus mablag‘i mavjud emas.',

    'referral_off': 'Taklif tizimi hozir o‘chirilgan.',
    'bonus_off': 'Bonus tizimi hozir o‘chirilgan.',

    'rule_passenger_first_trip':
        'Birinchi tasdiqlangan safaringizdan keyin {amount} so‘m olasiz. Admin tasdiqlagach, balansga tushadi.',

    'rule_passenger_referral':
        'Do‘stingiz sizning kodingiz bilan ro‘yxatdan o‘tib, birinchi safarini yakunlasa, sizga {amount} so‘m beriladi.',

    'rule_driver_referral':
        'Taklif qilgan haydovchingiz birinchi tasdiqlangan safarni qilsa, sizga {amount} so‘m beriladi.',

    'rule_driver_milestone':
        '{trips} ta tasdiqlangan safardan keyin {amount} so‘m bonus olasiz.',

    'rule_generic':
        '{title}: {amount} so‘m. Kerakli safar: {trips}.',

    'som': 'so‘m',

    'accept': 'Qabul qilish',
    'accept_this_price': 'Shu narxda qabul qilish',
    'own_price': 'O‘z narxim bilan',
    'reject': 'Bekor qilish',
  };

  // ============================================================
  // O'ZBEK TILI — KIRILL
  // ============================================================

  static const _uzCyrl = {
    'home_title': 'Қаерга борасиз?',
    'from': 'Қаердан?',
    'to': 'Қаерга?',
    'pick_place': 'Манзилни танланг',
    'other_place': 'Бошқа манзил',
    'find_taxi': 'Такси топиш',
    'route_distance': 'Йўл масофаси',
    'driver_distance': 'Сизгача масофа',
    'language_settings': 'Тил созламалари',

    'nav_home': 'Бош саҳифа',
    'nav_trips': 'Сафарларим',
    'nav_messages': 'Хабарлар',
    'nav_profile': 'Профиль',
    'nav_order': 'Буюртма',
    'nav_create_trip': 'Сафар яратиш',
    'nav_my_trips': 'Сафарларим',

    'exit_title': 'Чиқасизми?',
    'exit_message': 'Иловадан чиқишни хоҳлайсизми?',
    'yes': 'Ҳа',
    'no': 'Йўқ',
    'cancel': 'Бекор қилиш',

    'popular_routes': 'Машҳур йўналишлар',
    'see_all': 'Барчасини кўриш',
    'locating': 'Аниқланмоқда...',
    'tap_to_refresh': 'Янгилаш учун босинг',

    'exact_pickup': 'Аниқ олиб кетиш жойи',
    'edit': 'Ўзгартириш',
    'passengers': 'Йўловчилар',

    'enter_addresses':
        'Қаердан ва Қаерга манзилларини киритинг',

    'prebook_title': 'Олдиндан брон қилиш',
    'prebook_subtitle':
        'Сана ва вақтни танлаб, олдиндан буюртма беринг',

    'profile': 'Профиль',
    'register_first': 'Аввал рўйхатдан ўтинг',
    'register_hint':
        'Профиль, сафарлар ва хабарлар учун телефон орқали рўйхатдан ўтинг.',
    'register_btn': 'Рўйхатдан ўтиш',

    'user_default': 'Фойдаланувчи',
    'driver': 'Ҳайдовчи',
    'passenger': 'Йўловчи',
    'rating': 'Рейтинг',
    'trip': 'Сафар',
    'experience': 'Тажриба',
    'years_suffix': 'йил',

    'menu_orders': 'Буюртмалар',
    'menu_create_trip': 'Сафар яратиш',
    'menu_my_car': 'Менинг автомобилям',
    'menu_messages': 'Хабарлар',
    'menu_earnings': 'Даромадларим',
    'menu_appearance': 'Кўриниш',
    'menu_settings': 'Созламалар',
    'menu_language': 'Тил созламалари',
    'menu_faq': 'Тез-тез сўраладиган саволлар',
    'menu_help': 'Ёрдам',
    'menu_about': 'Илова ҳақида',
    'menu_logout': 'Чиқиш',

    'theme_light': 'Кундузги',
    'theme_dark': 'Тунги',
    'theme_auto': 'Автоматик',
    'appearance': 'Кўриниш',
    'new_badge': 'Янги',

    'become_driver_prompt':
        'Ҳайдовчи бўлишни хоҳлайсизми?',

    'logout_title': 'Чиқиш',
    'logout_confirm':
        'Ҳақиқатан ҳам ҳисобдан чиқасизми?',
    'logged_out': 'Ҳисобдан чиқилди',

    'register_title': 'Рўйхатдан ўтиш',
    'register_subtitle':
        'Исм, фамилия ва телефон рақамингиз етарли',
    'first_name': 'Исм *',
    'last_name': 'Фамилия *',
    'continue_btn': 'Давом этиш',

    'waiting': 'Кутилмоқда...',
    'server_error':
        'Серверга уланиб бўлмади. Интернет ва Wi-Fi ни текширинг.',

    'language_pick_title': 'Тилни танланг',
    'language_pick_subtitle':
        'Фақат биринчи марта сўралади',
    'start_btn': 'Бошлаш',

    'pending_application':
        'Аризангиз текширилмоқда. Натижа билдиришнома орқали келади.',

    'messages_title': 'Хабарлар',
    'messages_register_hint':
        'Хабарларни кўриш учун аввал рўйхатдан ўтинг',
    'messages_subtitle':
        'Ҳайдовчилар билан ёзишмаларингиз шу ерда сақланади',

    'settings_title': 'Созламалар',
    'personal_info': 'Шахсий маълумотлар',
    'first_name_short': 'Исм',
    'last_name_short': 'Фамилия',
    'experience_years': 'Тажриба (йил)',

    'save': 'Сақлаш',
    'saving': 'Сақланмоқда...',
    'saved': 'Сақланди',

    'phone_number': 'Телефон рақами',
    'phone_change_hint':
        'Рақамни ўзгартириш SMS тасдиқлаш билан кейинги янгиланишда қўшилади.',

    'faq_title': 'Тез-тез сўраладиган саволлар',
    'help_title': 'Ёрдам',
    'about_title': 'Илова ҳақида',

    'exact_pickup_title':
        'Аниқ олиб кетиш жойи',

    'exact_pickup_desc':
        'Асосий манзиллар такси топиш учун. Ҳайдовчи сизни аниқ қаердан олиб кетишини ёзинг.',

    'route_label': 'Йўналиш',

    'exact_pickup_hint':
        'Масалан: 44-мактаб олди',

    'exact_pickup_examples':
        'Масалан: 44-мактаб олди, бозор дарвозаси, ОФЙ биноси ёнида',

    'exact_pickup_required':
        'Аниқ олиб кетиш жойини ёзинг',

    'available_taxis': 'Мавжуд таксилар',
    'pickup_label': 'Олиб кетиш',

    'today': 'Бугун',
    'tomorrow': 'Эртага',
    'all': 'Барчаси',

    'taxi_count_fmt':
        'та такси · онлайн ва офлайн',

    'morning': 'Эрталаб',
    'afternoon': 'Кундуз',
    'evening': 'Кечқурун',

    'prebook_subtitle_short':
        'Керакли сана ва вақтга буюртма',

    'waiting_drivers':
        'Ҳайдовчилар жавобини кутмоқдамиз...',

    'waiting_broadcast':
        'Сўровингиз яқин атрофдаги барча ҳайдовчиларга юборилди.',

    'waiting_time_label': 'Кутилаётган вақт',
    'up_to_1_hour': '(1 соатгача)',

    'trip_on_way': 'Сафарда',
    'driver_on_way': 'Ҳайдовчи йўлда',
    'driver_coming':
        'Ҳайдовчи сиз томон ҳаракатланмоқда',

    'online_status': 'Онлайн',
    'offline_status': 'Офлайн',

    'orders_coming': 'Буюртмалар келади',

    'referral_code_optional':
        'Таклиф коди (ихтиёрий)',

    'taxis_hint':
        'Манзил ёзинг — мос йўналишлар дарҳол чиқади',

    'taxis_empty': 'Такси мавжуд эмас',
    'taxis_empty_hint':
        'Ҳозирча рўйхатда такси йўқ. Кейинроқ қайта уриниб кўринг.',

    'taxis_no_match':
        'Мос такси топилмади',

    'taxis_no_match_hint':
        'Бошқа манзил ёзинг ёки фильтрни ўзгартиринг.',

    'menu_rewards':
        'Бонус ва дўст таклифи',

    'rewards_title':
        'Бонус ва дўст таклифи',

    'rewards_subtitle':
        'Кодни улашинг, шартларни бажаринг ва бонус олинг',

    'copy_code': 'Кодни нусхалаш',
    'share': 'Улашиш',
    'copied': 'Нусхаланди',

    'invited': 'Таклиф қилинганлар',
    'successful': 'Муваффақиятли',

    'bonus_earned': 'Олинган бонус',
    'bonus_balance': 'Мавжуд бонус',
    'bonus_held': 'Ечишда банд',

    'withdraw': 'Бонусни ечиб олиш',

    'bonus_rules_title':
        'Бонус шартлари',

    'bonus_rules_note':
        'Суммалар админ панелида белгиланади. Админ ўзгартирса, шу ерда янгиланади.',

    'bonus_history': 'Бонус тарихи',
    'withdraw_history': 'Ечиб олиш тарихи',

    'telegram_username':
        'Telegram username',

    'no_bonus_to_withdraw':
        'Сизда ечиб олиш учун бонус маблағи мавжуд эмас.',

    'referral_off':
        'Таклиф тизими ҳозир ўчирилган.',

    'bonus_off':
        'Бонус тизими ҳозир ўчирилган.',

    'rule_passenger_first_trip':
        'Биринчи тасдиқланган сафарингиздан кейин {amount} сўм оласиз. Админ тасдиқлагач, балансга тушади.',

    'rule_passenger_referral':
        'Дўстингиз сизнинг кодингиз билан рўйхатдан ўтиб, биринчи сафарини якунласа, сизга {amount} сўм берилади.',

    'rule_driver_referral':
        'Таклиф қилган ҳайдовчингиз биринчи тасдиқланган сафарни қилса, сизга {amount} сўм берилади.',

    'rule_driver_milestone':
        '{trips} та тасдиқланган сафардан кейин {amount} сўм бонус оласиз.',

    'rule_generic':
        '{title}: {amount} сўм. Керакли сафар: {trips}.',

    'som': 'сўм',

    'accept': 'Қабул қилиш',
    'accept_this_price':
        'Шу нархда қабул қилиш',
    'own_price':
        'Ўз нархим билан',
    'reject': 'Бекор қилиш',
  };

  // ============================================================
  // РУССКИЙ ЯЗЫК
  // ============================================================

  static const _ru = {
    'home_title': 'Куда поедете?',
    'from': 'Откуда?',
    'to': 'Куда?',
    'pick_place': 'Выберите адрес',
    'other_place': 'Другой адрес',
    'find_taxi': 'Найти такси',
    'route_distance': 'Расстояние',
    'driver_distance': 'Расстояние до вас',
    'language_settings': 'Язык',

    'nav_home': 'Главная',
    'nav_trips': 'Мои поездки',
    'nav_messages': 'Сообщения',
    'nav_profile': 'Профиль',
    'nav_order': 'Заказ',
    'nav_create_trip': 'Создать поездку',
    'nav_my_trips': 'Мои поездки',

    'exit_title': 'Выйти?',
    'exit_message': 'Вы хотите выйти из приложения?',
    'yes': 'Да',
    'no': 'Нет',
    'cancel': 'Отмена',

    'popular_routes': 'Популярные маршруты',
    'see_all': 'Смотреть все',
    'locating': 'Определение...',
    'tap_to_refresh': 'Нажмите для обновления',

    'exact_pickup': 'Точная точка посадки',
    'edit': 'Изменить',
    'passengers': 'Пассажиры',

    'enter_addresses':
        'Укажите адреса «Откуда» и «Куда»',

    'prebook_title': 'Предварительное бронирование',
    'prebook_subtitle':
        'Выберите дату и время для заказа заранее',

    'profile': 'Профиль',
    'register_first': 'Сначала зарегистрируйтесь',
    'register_hint':
        'Зарегистрируйтесь по телефону для профиля, поездок и сообщений.',
    'register_btn': 'Регистрация',

    'user_default': 'Пользователь',
    'driver': 'Водитель',
    'passenger': 'Пассажир',
    'rating': 'Рейтинг',
    'trip': 'Поездка',
    'experience': 'Опыт',
    'years_suffix': 'лет',

    'menu_orders': 'Заказы',
    'menu_create_trip': 'Создать поездку',
    'menu_my_car': 'Мой автомобиль',
    'menu_messages': 'Сообщения',
    'menu_earnings': 'Мой доход',
    'menu_appearance': 'Оформление',
    'menu_settings': 'Настройки',
    'menu_language': 'Язык',
    'menu_faq': 'Частые вопросы',
    'menu_help': 'Помощь',
    'menu_about': 'О приложении',
    'menu_logout': 'Выйти',

    'theme_light': 'Светлая',
    'theme_dark': 'Тёмная',
    'theme_auto': 'Авто',
    'appearance': 'Оформление',
    'new_badge': 'Новое',

    'become_driver_prompt':
        'Хотите стать водителем?',

    'logout_title': 'Выход',
    'logout_confirm':
        'Вы действительно хотите выйти из аккаунта?',
    'logged_out': 'Вы вышли из аккаунта',

    'register_title': 'Регистрация',
    'register_subtitle':
        'Достаточно имени, фамилии и номера телефона',
    'first_name': 'Имя *',
    'last_name': 'Фамилия *',
    'continue_btn': 'Продолжить',

    'waiting': 'Подождите...',
    'server_error':
        'Не удалось подключиться к серверу. Проверьте интернет и Wi-Fi.',

    'language_pick_title': 'Выберите язык',
    'language_pick_subtitle':
        'Спрашивается только при первом запуске',
    'start_btn': 'Начать',

    'pending_application':
        'Ваша заявка проверяется. Результат придёт уведомлением.',

    'messages_title': 'Сообщения',
    'messages_register_hint':
        'Зарегистрируйтесь, чтобы видеть сообщения',
    'messages_subtitle':
        'Здесь сохраняется переписка с водителями',

    'settings_title': 'Настройки',
    'personal_info': 'Личные данные',
    'first_name_short': 'Имя',
    'last_name_short': 'Фамилия',
    'experience_years': 'Опыт (лет)',

    'save': 'Сохранить',
    'saving': 'Сохранение...',
    'saved': 'Сохранено',

    'phone_number': 'Номер телефона',
    'phone_change_hint':
        'Смена номера с SMS-подтверждением будет добавлена в следующем обновлении.',

    'faq_title': 'Частые вопросы',
    'help_title': 'Помощь',
    'about_title': 'О приложении',

    'exact_pickup_title':
        'Точная точка посадки',

    'exact_pickup_desc':
        'Основные адреса для поиска такси. Укажите, откуда именно вас забрать.',

    'route_label': 'Маршрут',

    'exact_pickup_hint':
        'Например: у 44-й школы',

    'exact_pickup_examples':
        'Например: у 44-й школы, у ворот базара, у здания МФЙ',

    'exact_pickup_required':
        'Укажите точку посадки',

    'available_taxis': 'Доступные такси',
    'pickup_label': 'Посадка',

    'today': 'Сегодня',
    'tomorrow': 'Завтра',
    'all': 'Все',

    'taxi_count_fmt':
        'такси · онлайн и офлайн',

    'morning': 'Утро',
    'afternoon': 'День',
    'evening': 'Вечер',

    'prebook_subtitle_short':
        'Заказ на нужную дату и время',

    'waiting_drivers':
        'Ждём ответа водителей...',

    'waiting_broadcast':
        'Запрос отправлен всем ближайшим водителям.',

    'waiting_time_label': 'Время ожидания',
    'up_to_1_hour': '(до 1 часа)',

    'trip_on_way': 'В пути',
    'driver_on_way': 'Водитель в пути',
    'driver_coming':
        'Водитель направляется к вам',

    'online_status': 'Онлайн',
    'offline_status': 'Офлайн',

    'orders_coming': 'Придут заказы',

    'referral_code_optional':
        'Код приглашения (необязательно)',

    'taxis_hint':
        'Введите адрес — подходящие маршруты появятся сразу',

    'taxis_empty': 'Такси нет',
    'taxis_empty_hint':
        'Сейчас в списке нет такси. Попробуйте позже.',

    'taxis_no_match':
        'Подходящее такси не найдено',

    'taxis_no_match_hint':
        'Введите другой адрес или смените фильтр.',

    'menu_rewards':
        'Бонус и приглашение',

    'rewards_title':
        'Бонус и приглашение друга',

    'rewards_subtitle':
        'Поделитесь кодом, выполните условия и получите бонус',

    'copy_code': 'Скопировать код',
    'share': 'Поделиться',
    'copied': 'Скопировано',

    'invited': 'Приглашено',
    'successful': 'Успешно',

    'bonus_earned': 'Полученный бонус',
    'bonus_balance': 'Доступный бонус',
    'bonus_held': 'На выводе',

    'withdraw': 'Вывести бонус',

    'bonus_rules_title': 'Условия бонуса',

    'bonus_rules_note':
        'Суммы задаёт админ. Если админ изменит их, здесь они обновятся.',

    'bonus_history': 'История бонусов',
    'withdraw_history': 'История вывода',

    'telegram_username': 'Telegram username',

    'no_bonus_to_withdraw':
        'Нет бонуса для вывода.',

    'referral_off':
        'Система приглашений сейчас выключена.',

    'bonus_off':
        'Бонусная система сейчас выключена.',

    'rule_passenger_first_trip':
        'После первой подтверждённой поездки вы получите {amount} сум. Сумма зачислится после подтверждения админом.',

    'rule_passenger_referral':
        'Если друг зарегистрируется по вашему коду и завершит первую поездку, вы получите {amount} сум.',

    'rule_driver_referral':
        'Если приглашённый водитель выполнит первую подтверждённую поездку, вы получите {amount} сум.',

    'rule_driver_milestone':
        'После {trips} подтверждённых поездок вы получите {amount} сум.',

    'rule_generic':
        '{title}: {amount} сум. Нужно поездок: {trips}.',

    'som': 'сум',

    'accept': 'Принять',
    'accept_this_price': 'Принять эту цену',
    'own_price': 'Со своей ценой',
    'reject': 'Отменить',
  };

  // ============================================================
  // ҚАЗАҚ ТІЛІ
  // ============================================================

  static const _kk = {
    'home_title': 'Қайда барасыз?',
    'from': 'Қайдан?',
    'to': 'Қайда?',
    'pick_place': 'Мекенжайды таңдаңыз',
    'other_place': 'Басқа мекенжай',
    'find_taxi': 'Такси табу',
    'route_distance': 'Жол қашықтығы',
    'driver_distance': 'Сізге дейінгі қашықтық',
    'language_settings': 'Тіл баптаулары',

    'nav_home': 'Басты бет',
    'nav_trips': 'Сапарларым',
    'nav_messages': 'Хабарламалар',
    'nav_profile': 'Профиль',
    'nav_order': 'Тапсырыс',
    'nav_create_trip': 'Сапар жасау',
    'nav_my_trips': 'Сапарларым',

    'exit_title': 'Шығасыз ба?',
    'exit_message': 'Қолданбадан шыққыңыз келе ме?',
    'yes': 'Иә',
    'no': 'Жоқ',
    'cancel': 'Болдырмау',

    'popular_routes': 'Танымал бағыттар',
    'see_all': 'Барлығын көру',
    'locating': 'Анықталуда...',
    'tap_to_refresh': 'Жаңарту үшін басыңыз',

    'exact_pickup': 'Нақты алып кету орны',
    'edit': 'Өзгерту',
    'passengers': 'Жолаушылар',

    'enter_addresses':
        '«Қайдан?» және «Қайда?» мекенжайларын енгізіңіз',

    'prebook_title': 'Алдын ала брондау',
    'prebook_subtitle':
        'Күн мен уақытты таңдап, алдын ала тапсырыс беріңіз',

    'profile': 'Профиль',
    'register_first': 'Алдымен тіркеліңіз',
    'register_hint':
        'Профиль, сапарлар және хабарламалар үшін телефон нөмірі арқылы тіркеліңіз.',
    'register_btn': 'Тіркелу',

    'user_default': 'Пайдаланушы',
    'driver': 'Жүргізуші',
    'passenger': 'Жолаушы',
    'rating': 'Рейтинг',
    'trip': 'Сапар',
    'experience': 'Тәжірибе',
    'years_suffix': 'жыл',

    'menu_orders': 'Тапсырыстар',
    'menu_create_trip': 'Сапар жасау',
    'menu_my_car': 'Менің көлігім',
    'menu_messages': 'Хабарламалар',
    'menu_earnings': 'Табысым',
    'menu_appearance': 'Көрініс',
    'menu_settings': 'Баптаулар',
    'menu_language': 'Тіл баптаулары',
    'menu_faq': 'Жиі қойылатын сұрақтар',
    'menu_help': 'Көмек',
    'menu_about': 'Қолданба туралы',
    'menu_logout': 'Шығу',

    'theme_light': 'Күндізгі',
    'theme_dark': 'Түнгі',
    'theme_auto': 'Автоматты',
    'appearance': 'Көрініс',
    'new_badge': 'Жаңа',

    'become_driver_prompt':
        'Жүргізуші болғыңыз келе ме?',

    'logout_title': 'Шығу',
    'logout_confirm':
        'Шотыңыздан шынымен шыққыңыз келе ме?',
    'logged_out': 'Шоттан шықтыңыз',

    'register_title': 'Тіркелу',
    'register_subtitle':
        'Аты-жөніңіз бен телефон нөміріңіз жеткілікті',
    'first_name': 'Аты *',
    'last_name': 'Тегі *',
    'continue_btn': 'Жалғастыру',

    'waiting': 'Күтілуде...',
    'server_error':
        'Серверге қосылу мүмкін болмады. Интернет пен Wi-Fi желісін тексеріңіз.',

    'language_pick_title': 'Тілді таңдаңыз',
    'language_pick_subtitle':
        'Тек бірінші рет сұралады',
    'start_btn': 'Бастау',

    'pending_application':
        'Өтінішіңіз тексерілуде. Нәтиже хабарлама арқылы жіберіледі.',

    'messages_title': 'Хабарламалар',
    'messages_register_hint':
        'Хабарламаларды көру үшін алдымен тіркеліңіз',
    'messages_subtitle':
        'Жүргізушілермен жазысқан хабарламаларыңыз осында сақталады',

    'settings_title': 'Баптаулар',
    'personal_info': 'Жеке мәліметтер',
    'first_name_short': 'Аты',
    'last_name_short': 'Тегі',
    'experience_years': 'Тәжірибе (жыл)',

    'save': 'Сақтау',
    'saving': 'Сақталуда...',
    'saved': 'Сақталды',

    'phone_number': 'Телефон нөмірі',
    'phone_change_hint':
        'Нөмірді SMS арқылы растау мүмкіндігі келесі жаңартуда қосылады.',

    'faq_title': 'Жиі қойылатын сұрақтар',
    'help_title': 'Көмек',
    'about_title': 'Қолданба туралы',

    'exact_pickup_title':
        'Нақты алып кету орны',

    'exact_pickup_desc':
        'Такси табу үшін негізгі мекенжайлар көрсетіледі. Жүргізуші сізді нақты қай жерден алып кететінін жазыңыз.',

    'route_label': 'Бағыт',

    'exact_pickup_hint':
        'Мысалы: 44-мектептің алдында',

    'exact_pickup_examples':
        'Мысалы: 44-мектептің алдында, базар қақпасында, МФЙ ғимаратының жанында',

    'exact_pickup_required':
        'Нақты алып кету орнын жазыңыз',

    'available_taxis': 'Қолжетімді таксилер',
    'pickup_label': 'Алып кету',

    'today': 'Бүгін',
    'tomorrow': 'Ертең',
    'all': 'Барлығы',

    'taxi_count_fmt':
        'такси · онлайн және офлайн',

    'morning': 'Таңертең',
    'afternoon': 'Күндіз',
    'evening': 'Кешке',

    'prebook_subtitle_short':
        'Қажетті күн мен уақытқа тапсырыс',

    'waiting_drivers':
        'Жүргізушілердің жауабын күтіп отырмыз...',

    'waiting_broadcast':
        'Сұранысыңыз жақын маңдағы барлық жүргізушілерге жіберілді.',

    'waiting_time_label': 'Күту уақыты',
    'up_to_1_hour': '(1 сағатқа дейін)',

    'trip_on_way': 'Сапарда',
    'driver_on_way': 'Жүргізуші жолда',
    'driver_coming':
        'Жүргізуші сізге қарай келе жатыр',

    'online_status': 'Онлайн',
    'offline_status': 'Офлайн',

    'orders_coming': 'Тапсырыстар келеді',

    'referral_code_optional':
        'Шақыру коды (міндетті емес)',

    'taxis_hint':
        'Мекенжайды жазыңыз — сәйкес бағыттар бірден шығады',

    'taxis_empty': 'Такси жоқ',
    'taxis_empty_hint':
        'Қазір тізімде такси жоқ. Кейінірек қайталап көріңіз.',

    'taxis_no_match':
        'Сәйкес такси табылмады',

    'taxis_no_match_hint':
        'Басқа мекенжай енгізіңіз немесе сүзгіні өзгертіңіз.',

    'menu_rewards':
        'Бонус және дос шақыру',

    'rewards_title':
        'Бонус және дос шақыру',

    'rewards_subtitle':
        'Кодты бөлісіңіз, шарттарды орындаңыз және бонус алыңыз',

    'copy_code': 'Кодты көшіру',
    'share': 'Бөлісу',
    'copied': 'Көшірілді',

    'invited': 'Шақырылғандар',
    'successful': 'Сәтті',

    'bonus_earned': 'Алынған бонус',
    'bonus_balance': 'Қолжетімді бонус',
    'bonus_held': 'Шығарылуда',

    'withdraw': 'Бонусты шығару',

    'bonus_rules_title':
        'Бонус шарттары',

    'bonus_rules_note':
        'Сомаларды әкімші белгілейді. Әкімші өзгерткен жағдайда, бұл жерде де жаңартылады.',

    'bonus_history': 'Бонус тарихы',
    'withdraw_history': 'Шығару тарихы',

    'telegram_username':
        'Telegram username',

    'no_bonus_to_withdraw':
        'Шығарып алуға қолжетімді бонус жоқ.',

    'referral_off':
        'Шақыру жүйесі қазір өшірулі.',

    'bonus_off':
        'Бонус жүйесі қазір өшірулі.',

    'rule_passenger_first_trip':
        'Бірінші расталған сапарыңыздан кейін {amount} сум аласыз. Сома әкімші растағаннан кейін балансыңызға түседі.',

    'rule_passenger_referral':
        'Досыңыз сіздің кодыңызбен тіркеліп, бірінші сапарын аяқтаса, сізге {amount} сум беріледі.',

    'rule_driver_referral':
        'Шақырған жүргізушіңіз бірінші расталған сапарын орындаса, сізге {amount} сум беріледі.',

    'rule_driver_milestone':
        '{trips} расталған сапардан кейін {amount} сум бонус аласыз.',

    'rule_generic':
        '{title}: {amount} сум. Қажетті сапар саны: {trips}.',

    'som': 'сум',

    'accept': 'Қабылдау',
    'accept_this_price':
        'Осы бағамен қабылдау',
    'own_price':
        'Өз бағаммен',
    'reject': 'Бас тарту',
  };
}