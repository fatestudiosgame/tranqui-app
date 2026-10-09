import 'package:apklis_license_validator/apklis_license_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class ResultadoSyncLicencia {
  final bool esVip;
  final String? tipoPlan;
  final String? username;
  final DateTime? fechaExpiracion;

  /// true si el estado VIP cambió/apareció en esta sincronización
  final bool recienDetectada;

  const ResultadoSyncLicencia({
    required this.esVip,
    this.tipoPlan,
    this.username,
    this.fechaExpiracion,
    this.recienDetectada = false,
  });
}

/// Sincroniza la licencia VIP con APKLIS + backend al abrir la app,
/// sin que el usuario tenga que entrar a la pantalla VIP.
class LicenciaService {
  static const String appId = 'com.fatestudiosgame.tranqui';

  static const String _keyLicencia = 'vip_licencia';
  static const String _keyTipoPlan = 'vip_tipo_plan';
  static const String _keyUsername = 'vip_username';
  static const String _keyFechaExpiracion = 'vip_fecha_expiracion';

  static int diasPorPlan(String? tipo) {
    final t = (tipo ?? '').toLowerCase();
    if (t.contains('oro')) return 360;
    if (t.contains('plata')) return 180;
    if (t.contains('bronce') || t.contains('prueba')) return 30;
    return 30;
  }

  /// Estado VIP según lo guardado en el dispositivo (sin red).
  static Future<ResultadoSyncLicencia> estadoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final licencia = prefs.getString(_keyLicencia);
    final tipoPlan = prefs.getString(_keyTipoPlan);
    final username = prefs.getString(_keyUsername);
    final expStr = prefs.getString(_keyFechaExpiracion);
    final exp = expStr != null ? DateTime.tryParse(expStr) : null;
    final esVip =
        licencia != null && exp != null && exp.isAfter(DateTime.now());
    return ResultadoSyncLicencia(
      esVip: esVip,
      tipoPlan: tipoPlan,
      username: username,
      fechaExpiracion: esVip ? exp : null,
    );
  }

  /// Consulta APKLIS y refresca SharedPreferences en silencio.
  /// NUNCA lanza: si falla (sin internet, etc.) devuelve el estado local.
  static Future<ResultadoSyncLicencia> sincronizar({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final previo = await estadoLocal();

    try {
      final status = await ApklisLicenseValidator.verifyUserLicense(appId)
          .timeout(timeout);

      if (status.paid && status.license != null) {
        final username = status.username ?? previo.username ?? '';
        String tipoPlan = previo.tipoPlan ?? 'BroncePlus';
        DateTime? fechaExp = previo.fechaExpiracion;

        // El backend es la fuente de verdad del plan y la fecha
        try {
          final r = await ApiService.getLicenciaVigente(username: username)
              .timeout(const Duration(seconds: 8));
          if (r['vigente'] == true && r['data'] != null) {
            final data = r['data'] as Map<String, dynamic>;
            tipoPlan = (data['tipoPlan'] as String?) ?? tipoPlan;
            final expStr = data['fechaExpiracion'] as String?;
            if (expStr != null) fechaExp = DateTime.tryParse(expStr);
          }
        } catch (_) {}

        fechaExp ??=
            DateTime.now().add(Duration(days: diasPorPlan(tipoPlan)));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyLicencia, status.license!);
        await prefs.setString(_keyTipoPlan, tipoPlan);
        await prefs.setString(_keyUsername, username);
        await prefs.setString(
            _keyFechaExpiracion, fechaExp.toIso8601String());

        final recien = !previo.esVip || previo.tipoPlan != tipoPlan;

        return ResultadoSyncLicencia(
          esVip: fechaExp.isAfter(DateTime.now()),
          tipoPlan: tipoPlan,
          username: username,
          fechaExpiracion: fechaExp,
          recienDetectada: recien,
        );
      }

      // APKLIS dice que no hay pago: respetar lo local (puede ser un
      // falso negativo por falta de conexión).
      return previo;
    } catch (e) {
      debugPrint('⚠️ [Licencia] sync falló, usando estado local: $e');
      return previo;
    }
  }
}