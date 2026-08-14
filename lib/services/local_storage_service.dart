import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // <-- NUEVA IMPORTACIÓN

class LocalStorageService {
  static const String _negociosBox = 'negociosBox';
  static String? _hivePath;

  // Inicializa Hive de forma segura
  static Future<void> init() async {
    try {
      // Obtener la ruta de documentos una sola vez
      final appDocDir = await getApplicationDocumentsDirectory();
      _hivePath = appDocDir.path;
      Hive.init(_hivePath!); // Inicializar Hive con esa ruta
      await Hive.openBox(_negociosBox);
      if (kDebugMode) print('✅ Hive inicializado correctamente en $_hivePath');
    } catch (e) {
      if (kDebugMode) print('❌ Error abriendo Hive: $e. Limpiando...');
      await limpiarCache();
      // Reintentar abrir después de limpiar
      await Hive.openBox(_negociosBox);
      if (kDebugMode) print('✅ Hive reinicializado correctamente');
    }
  }

  // Guardar la lista de negocios
  static Future<void> guardarNegocios(List<dynamic> negocios) async {
    try {
      final box = await Hive.openBox(_negociosBox);
      await box.put('negocios', negocios);
    } catch (e) {
      if (kDebugMode) print('❌ Error guardando: $e. Reintentando...');
      await limpiarCache();
      final box = await Hive.openBox(_negociosBox);
      await box.put('negocios', negocios);
    }
  }

  // Obtener la lista de negocios guardada
  static List<dynamic> obtenerNegocios() {
    try {
      final box = Hive.box(_negociosBox);
      final data = box.get('negocios', defaultValue: []);
      if (data is List) {
        return data;
      } else {
        limpiarCache();
        return [];
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error leyendo caché: $e. Limpiando...');
      limpiarCache();
      return [];
    }
  }

  // Limpiar toda la caché de forma segura
  static Future<void> limpiarCache() async {
    try {
      final box = await Hive.openBox(_negociosBox);
      await box.clear();
      if (kDebugMode) print('🗑️ Caché de Hive limpiada');
    } catch (e) {
      if (kDebugMode)
        print('❌ Error limpiando caché: $e. Intentando borrar archivos...');
      try {
        // Obtener la ruta de documentos y eliminar el archivo de la caja
        final appDocDir = await getApplicationDocumentsDirectory();
        final boxPath = '${appDocDir.path}/$_negociosBox.hive';
        final file = File(boxPath);
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode) print('🗑️ Archivo de Hive eliminado: $boxPath');
        }
      } catch (e2) {
        if (kDebugMode) print('❌ Error eliminando archivo: $e2');
      }
    }
  }
}
