import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/mapa_negocios.dart';
import 'screens/onboarding_screen.dart';
import 'services/local_storage_service.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();
  runApp(const TranquiApp());
}

class TranquiApp extends StatelessWidget {
  const TranquiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tranquilízate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange,
          secondary: Colors.orange.shade700,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingAndUpdate();
  }

  Future<void> _checkOnboardingAndUpdate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    if (!onboardingCompleted) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
      return;
    }

    // Verificar actualizaciones
    UpdateInfo? updateInfo;
    bool updateError = false;
    try {
      updateInfo = await UpdateService.checkForUpdate();
    } catch (e) {
      print('❌ Error al verificar actualizaciones: $e');
      updateError = true;
    }

    // Si hay error y estamos en release, mostramos un SnackBar
    if (updateError && !kIsWeb) {
      // En release, mostrar un mensaje breve
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No se pudo verificar actualizaciones'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (updateInfo != null) {
      try {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(
            versionName: updateInfo!.versionName,
            releaseNotes: updateInfo!.releaseNotes,
            downloadUrl: updateInfo!.downloadUrl,
          ),
        );
      } catch (e) {
        print('❌ Error al mostrar diálogo: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MapaNegocios()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, color: Colors.white, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Tranqui, aquí aceptan transferencias',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
