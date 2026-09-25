import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home/main_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/active_booking_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/driver_trip_service.dart';
import 'services/profile_service.dart';
import 'l10n/app_strings.dart';
import 'services/trip_completion_service.dart';
import 'services/location_service.dart';
import 'services/place_registry_service.dart';
import 'services/platform_config_service.dart';
import 'services/theme_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.load();
  // Bir Wi‑Fi da serverni avtomatik topish (IP o‘zgarganda ham ishlaydi)
  // ignore: unawaited_futures
  ApiClient.instance.ensureConnected();
  await AuthService.instance.load();
  await ProfileService.instance.load();
  await ThemeService.instance.load();
  await ActiveBookingService.instance.load();
  await ChatService.instance.load();
  await DriverTripService.instance.load();
  await TripCompletionService.instance.load();
  await PlaceRegistryService.instance.load();
  await PlatformConfigService.instance.load();
  // ignore: unawaited_futures
  LocationService.instance.start();
  runApp(const SafaronApp());
}

class SafaronApp extends StatelessWidget {
  const SafaronApp({super.key});

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
