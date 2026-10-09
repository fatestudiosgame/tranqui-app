import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'services/notificaciones_service.dart';
import 'screens/mapa_negocios.dart';
import 'screens/pagina_negocio.dart';
import 'screens/pantalla_vip.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ 1. Inicializar Firebase
  try {
    await Firebase.initializeApp();
    print('✅ Firebase inicializado correctamente');
  } catch (e) {
    print('⚠️ Error inicializando Firebase: $e');
  }

  // ⭐ 2. Inicializar Hive
  try {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen('negociosbox')) {
      await Hive.openBox('negociosbox');
    }
    print('✅ Hive inicializado correctamente');
  } catch (e) {
    print('⚠️ Error inicializando Hive: $e');
  }

  // ⭐ 3. Inicializar servicio de notificaciones
  try {
    await NotificacionesService.inicializar();
    print('✅ Servicio de notificaciones inicializado');
  } catch (e) {
    print('⚠️ Error inicializando notificaciones: $e');
  }

  // ⭐ 4. Configurar orientación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialNegocioId;
  String? _initialPaginaVipId;

  @override
  void initState() {
    super.initState();
    _leerDeepLinkInicial();
    _verificarAnunciosPendientes();
  }

  Future<void> _verificarAnunciosPendientes() async {
    try {
      await NotificacionesService.verificarAnunciosPendientes();
    } catch (e) {
      print('⚠️ Error verificando anuncios: $e');
    }
  }

  Future<void> _leerDeepLinkInicial() async {
    if (kIsWeb) {
      _leerDeepLinkWeb();
      return;
    }

    try {
      final appLinks = AppLinks();
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('⚠️ Error leyendo deep link inicial: $e');
    }
  }

  void _leerDeepLinkWeb() {
    try {
      final uri = Uri.base;
      final id = uri.queryParameters['id'];
      final path = uri.path;

      if (path.contains('/p/') || uri.fragment.contains('/p/')) {
        String? vipId;
        if (id != null && id.isNotEmpty) {
          vipId = id;
        } else if (uri.fragment.contains('/p/')) {
          final parts = uri.fragment.split('/p/');
          if (parts.length > 1) {
            vipId = parts[1].split('/').first;
          }
        }
        if (vipId != null && vipId.isNotEmpty) {
          setState(() {
            _initialPaginaVipId = vipId;
          });
          return;
        }
      }

      if (id != null && id.isNotEmpty) {
        setState(() {
          _initialNegocioId = id;
        });
      }
    } catch (e) {
      print('⚠️ Error leyendo URL web: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    print('🔗 Deep link recibido en main: $uri');

    if (uri.scheme == 'tranqui') {
      if (uri.host == 'negocio') {
        final negocioId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (negocioId != null && negocioId.isNotEmpty) {
          setState(() {
            _initialNegocioId = negocioId;
          });
        }
      } else if (uri.host == 'p') {
        final vipId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (vipId != null && vipId.isNotEmpty) {
          setState(() {
            _initialPaginaVipId = vipId;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tranqui',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9800),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == '/' && _initialPaginaVipId != null) {
          final vipId = _initialPaginaVipId;
          _initialPaginaVipId = null;
          return MaterialPageRoute(
            builder: (context) => PaginaNegocio(negocioId: vipId!),
          );
        }

        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (context) => MapaNegocios(
              initialNegocioId: _initialNegocioId,
            ),
          );
        }

        if (settings.name?.startsWith('/p/') == true) {
          final vipId = settings.name!.replaceFirst('/p/', '');
          return MaterialPageRoute(
            builder: (context) => PaginaNegocio(negocioId: vipId),
          );
        }

        if (settings.name == '/vip') {
          return MaterialPageRoute(
            builder: (context) => const PantallaVip(),
          );
        }

        return MaterialPageRoute(
          builder: (context) => MapaNegocios(
            initialNegocioId: _initialNegocioId,
          ),
        );
      },
    );
  }
}
