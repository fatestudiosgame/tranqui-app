import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static const String _negociosBox = 'negociosBox';
  static const String _negociosTimestampKey = 'negocios_timestamp';
  static String? _hivePath;
  static bool _inicializado = false;
  static bool _inicializando = false;

  /// Inicializa Hive de forma segura (idempotente - se puede llamar varias veces)
  static Future<void> init() async {
    // Si ya está inicializado, no hacer nada
    if (_inicializado) return;

    // Evitar inicializaciones concurrentes
    if (_inicializando) {
      // Esperar a que termine la inicialización en curso
      while (_inicializando) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _inicializando = true;
    try {
      if (kIsWeb) {
        await Hive.initFlutter();
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        _hivePath = appDocDir.path;
        Hive.init(_hivePath!);
      }

      // Verificar si la box ya está abierta antes de abrirla
      if (!Hive.isBoxOpen(_negociosBox)) {
        await Hive.openBox(_negociosBox);
      }

      _inicializado = true;
      if (kDebugMode) {
        print(
            '✅ Hive inicializado correctamente${_hivePath != null ? ' en $_hivePath' : ' (web)'}');
      }
    } catch (e) {
      if (kDebugMode)
        print('❌ Error abriendo Hive: $e. Limpiando y reintentando...');
      try {
        await _limpiarArchivosHive();
        if (!Hive.isBoxOpen(_negociosBox)) {
          await Hive.openBox(_negociosBox);
        }
        _inicializado = true;
        if (kDebugMode)
          print('✅ Hive reinicializado correctamente tras limpiar');
      } catch (e2) {
        if (kDebugMode) print('❌ Error fatal reinicializando Hive: $e2');
        _inicializado = false;
      }
    } finally {
      _inicializando = false;
    }
  }

  /// Asegura que Hive esté inicializado antes de cualquier operación
  static Future<void> _asegurarInicializacion() async {
    if (!_inicializado) {
      await init();
    }
  }

  /// Guardar la lista de negocios + timestamp
  static Future<void> guardarNegocios(List<dynamic> negocios) async {
    try {
      await _asegurarInicializacion();
      if (!_inicializado) {
        if (kDebugMode)
          print('⚠️ Hive no inicializado, no se pueden guardar negocios');
        return;
      }

      final box = Hive.isBoxOpen(_negociosBox)
          ? Hive.box(_negociosBox)
          : await Hive.openBox(_negociosBox);

      await box.put('negocios', negocios);
      await box.put(
          _negociosTimestampKey, DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode)
        print(
            '💾 ${negocios.length} negocios guardados en caché con timestamp');
    } catch (e) {
      if (kDebugMode) print('❌ Error guardando negocios: $e');
      try {
        await _recuperarBox();
        final box = await Hive.openBox(_negociosBox);
        await box.put('negocios', negocios);
        await box.put(
            _negociosTimestampKey, DateTime.now().millisecondsSinceEpoch);
        if (kDebugMode) print('💾 Negocios guardados tras recuperación');
      } catch (e2) {
        if (kDebugMode)
          print('❌ Error crítico guardando tras recuperación: $e2');
      }
    }
  }

  /// Obtener la lista de negocios guardada (AHORA ES ASYNC)
  static Future<List<dynamic>> obtenerNegocios() async {
    try {
      await _asegurarInicializacion();
      if (!_inicializado) {
        if (kDebugMode)
          print('⚠️ Hive no inicializado, devolviendo lista vacía');
        return [];
      }

      final box = Hive.isBoxOpen(_negociosBox)
          ? Hive.box(_negociosBox)
          : await Hive.openBox(_negociosBox);
      final data = box.get('negocios', defaultValue: []);

      if (data is List) {
        if (kDebugMode)
          print('📥 ${data.length} negocios cargados desde caché');
        return data;
      } else {
        if (kDebugMode) print('⚠️ Datos de caché corruptos, limpiando...');
        await limpiarCache();
        return [];
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error leyendo caché: $e');
      try {
        await _recuperarBox();
        return [];
      } catch (e2) {
        if (kDebugMode) print('❌ Error crítico recuperando box: $e2');
        return [];
      }
    }
  }

  /// ⭐ NUEVO: Obtener el timestamp de la última actualización
  static Future<DateTime?> obtenerTimestampNegocios() async {
    try {
      await _asegurarInicializacion();
      if (!_inicializado) return null;

      final box = Hive.isBoxOpen(_negociosBox)
          ? Hive.box(_negociosBox)
          : await Hive.openBox(_negociosBox);

      final timestampMs = box.get(_negociosTimestampKey);
      if (timestampMs is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestampMs);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('⚠️ Error obteniendo timestamp: $e');
      return null;
    }
  }

  /// ⭐ NUEVO: Verificar si la caché es vieja (más de X minutos)
  static Future<bool> esCacheVieja({int maxMinutos = 15}) async {
    final timestamp = await obtenerTimestampNegocios();
    if (timestamp == null) return true; // Sin timestamp = vieja

    final ahora = DateTime.now();
    final diferencia = ahora.difference(timestamp);
    return diferencia.inMinutes >= maxMinutos;
  }

  /// Limpiar toda la caché de forma segura
  static Future<void> limpiarCache() async {
    try {
      // Verificar que Hive esté inicializado antes de operar
      await _asegurarInicializacion();
      if (!_inicializado) {
        if (kDebugMode)
          print('⚠️ Hive no está inicializado, limpiando solo archivos');
        await _limpiarArchivosHive();
        return;
      }

      // Si la box está abierta, limpiarla
      if (Hive.isBoxOpen(_negociosBox)) {
        final box = Hive.box(_negociosBox);
        await box.clear();
        if (kDebugMode) print('🗑️ Caché de Hive limpiada (box abierta)');
      } else {
        // Si no está abierta, intentar abrirla, limpiar y cerrar
        try {
          final box = await Hive.openBox(_negociosBox);
          await box.clear();
          await box.close();
          if (kDebugMode)
            print('🗑️ Caché de Hive limpiada (box abierta temporalmente)');
        } catch (e) {
          if (kDebugMode) print('⚠️ No se pudo abrir box para limpiar: $e');
          await _limpiarArchivosHive();
        }
      }
    } catch (e) {
      if (kDebugMode)
        print('❌ Error limpiando caché: $e. Borrando archivos...');
      await _limpiarArchivosHive();
    }
  }

  /// Método privado: intenta recuperar una box corrupta
  static Future<void> _recuperarBox() async {
    try {
      // Cerrar la box si está abierta pero corrupta
      if (Hive.isBoxOpen(_negociosBox)) {
        try {
          await Hive.box(_negociosBox).close();
        } catch (_) {}
      }
      // Borrar archivos físicos
      await _limpiarArchivosHive();
      // Reabrir
      await Hive.openBox(_negociosBox);
      if (kDebugMode) print('✅ Box recuperada correctamente');
    } catch (e) {
      if (kDebugMode) print('❌ No se pudo recuperar la box: $e');
      rethrow;
    }
  }

  /// Método privado: borra los archivos físicos de Hive del disco
  static Future<void> _limpiarArchivosHive() async {
    if (kIsWeb) return; // En web no hay archivos físicos

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final boxPath = '${appDocDir.path}/$_negociosBox.hive';
      final lockPath = '${appDocDir.path}/$_negociosBox.lock';

      for (final path in [boxPath, lockPath]) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode) print('🗑️ Archivo eliminado: $path');
        }
      }

      // Marcar como no inicializado para forzar reinit en el próximo uso
      _inicializado = false;
    } catch (e) {
      if (kDebugMode) print('❌ Error eliminando archivos Hive: $e');
    }
  }
}
