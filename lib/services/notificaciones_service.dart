import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class NotificacionesService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> inicializar() async {
    // Solicitar permisos (iOS)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configurar notificaciones locales
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Usuario tocó la notificación
        print('🔔 Notificación tocada: ${response.payload}');
      },
    );

    // Obtener token FCM
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _registrarToken(token);
    }

    // Escuchar cambios de token
    _firebaseMessaging.onTokenRefresh.listen(_registrarToken);

    // Escuchar notificaciones en foreground (app abierta)
    FirebaseMessaging.onMessage.listen(_mostrarNotificacionLocal);

    // Escuchar cuando el usuario toca la notificación (app en background)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('🔔 Usuario abrió app desde notificación: ${message.data}');
    });

    // Verificar si la app se abrió desde una notificación (app cerrada)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print(
          '🔔 App abierta desde notificación (cerrada): ${initialMessage.data}');
    }
  }

  static Future<void> _registrarToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('vip_username');

      await ApiService.registrarTokenNotificacion(
          token: token, username: username);
      print('✅ Token FCM registrado: ${token.substring(0, 20)}...');
    } catch (e) {
      print('⚠️ Error registrando token FCM: $e');
    }
  }

  static Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'tranqui_anuncios',
      'Anuncios de Tranqui',
      channelDescription: 'Notificaciones importantes de Tranqui',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['tipo'],
    );
  }

  // Verificar anuncios al abrir la app (para usuarios que no recibieron push)
  static Future<void> verificarAnunciosPendientes() async {
    try {
      final anuncios = await ApiService.obtenerAnunciosActivos();
      final prefs = await SharedPreferences.getInstance();
      final vistos = prefs.getStringList('anuncios_vistos') ?? [];

      for (final anuncio in anuncios) {
        if (!vistos.contains(anuncio['id'])) {
          // Mostrar anuncio como diálogo en la app
          vistos.add(anuncio['id']);
          // Aquí puedes disparar un evento para mostrar el diálogo
        }
      }

      await prefs.setStringList('anuncios_vistos', vistos);
    } catch (e) {
      print('⚠️ Error verificando anuncios: $e');
    }
  }
}
