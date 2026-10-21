import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home/main_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/active_booking_service.dart';
import 'services/api_client.dart';
import 'services/app_refresh.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/driver_trip_service.dart';
import 'services/error_report_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'l10n/app_strings.dart';
import 'services/trip_completion_service.dart';
import 'services/location_service.dart';
import 'services/place_registry_service.dart';
import 'services/platform_config_service.dart';
import 'services/trip_catalog_service.dart';
import 'services/theme_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tutilmagan xatolarni backendga yuborish — tashqi monitoring xizmati
  // (Sentry va h.k.) ulanmagan bo‘lsa ham ko‘rinmas qolib ketmasin.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // ignore: unawaited_futures
    ErrorReportService.report(details.exception, details.stack, path: 'flutter');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: unawaited_futures
    ErrorReportService.report(error, stack, path: 'platform');
    return true;
  };

  try {
    await ApiClient.instance.load();
    // ignore: unawaited_futures
    ApiClient.instance.ensureConnected();
    await AuthService.instance.load();
    await ProfileService.instance.load();
    await ThemeService.instance.load();
    await ActiveBookingService.instance.load();
    await ChatService.instance.load();
    // ignore: unawaited_futures
    NotificationService.instance.refresh();
    NotificationService.instance.startPolling();
    await DriverTripService.instance.load();
    await TripCompletionService.instance.load();
    await PlaceRegistryService.instance.load();
    await PlatformConfigService.instance.load();
    // ignore: unawaited_futures
    TripCatalogService.instance.refresh();
    // ignore: unawaited_futures
    LocationService.instance.start();
  } catch (_) {
    // Boot paytidagi kutilmagan xato ilovani butunlay to‘xtatib qo‘ymasin —
    // mavjud (default) holatda bo‘lsa ham ilova ochilsin.
  }
  runApp(const SafaronApp());
}

class SafaronApp extends StatefulWidget {
  const SafaronApp({super.key});

  @override
  State<SafaronApp> createState() => _SafaronAppState();
}

class _SafaronAppState extends State<SafaronApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ilova fondan (ekran qulflash, boshqa ilovaga o'tish) qaytganda darhol
  // qayta so'rov yuboramiz. Android ko'pincha fondagi ilovaning Timer'larini
  // to'xtatib/kechiktirib qo'yadi — shunga qaramay bu hech qachon qo'yilmagan
  // edi, shuning uchun haydovchi javob bergan/buyurtma holati o'zgargan
  // bo'lsa ham, foreground'ga qaytgandan keyin ekran navbatdagi tasodifiy
  // timer tikigigacha eskirgan holatda "qotib" qolgandek ko'rinaverardi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: unawaited_futures
      AppRefresh.run();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeService.instance, ProfileService.instance, PlatformConfigService.instance]),
      builder: (context, _) {
        final dark = ThemeService.instance.isDark;
        final lang = ProfileService.instance.languageUiCode;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          ),
        );
        return MaterialApp(
          key: ValueKey('app_${lang}_$dark'),
          title: 'SAFARON TAXI',
          debugShowCheckedModeBanner: false,
          locale: AppStrings.localeFor(lang),
          supportedLocales: const [
            Locale('uz'),
            Locale('uz', 'Cyrl'),
            Locale('ru'),
            Locale('kk'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              secondary: AppColors.accent,
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: AppColors.white,
            useMaterial3: true,
          ),
          // Birinchi marta: Welcome → Til. Keyin: MainShell.
          home: PlatformConfigService.instance.maintenance
              ? const _MaintenanceScreen()
              : (ThemeService.instance.onboarded ? const MainShell() : const WelcomeScreen()),
        );
      },
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            PlatformConfigService.instance.maintenanceMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
