import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class UpdateService {
  static const String updateUrl =
      'https://www.dropbox.com/scl/fi/1n4rxabxiepu98emtdgw0/update.json?rlkey=795j8r1h5xugn3upsg2xtz60i&dl=1';
  static const Duration timeout = Duration(seconds: 15);

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      print('📡 [UPDATE] Verificando actualizaciones desde: $updateUrl');

      final currentPackageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.parse(currentPackageInfo.buildNumber);
      print(
          '📱 [UPDATE] App actual: version=${currentPackageInfo.version}, buildNumber=$currentBuildNumber');

      final String arch = await _getArchitecture();
      print('📱 [UPDATE] Arquitectura del dispositivo: $arch');

      print('⏳ [UPDATE] Descargando JSON...');
      final response = await http.get(Uri.parse(updateUrl)).timeout(timeout);

      if (response.statusCode != 200) {
        print('⚠️ [UPDATE] Error al descargar JSON: ${response.statusCode}');
        return null;
      }

      final String jsonString = utf8.decode(response.bodyBytes);
      final data = jsonDecode(jsonString);

      // ⭐ LEER LA ESTRUCTURA NUEVA ("versions")
      final versions = data['versions'] as Map<String, dynamic>?;

      if (versions == null || versions.isEmpty) {
        print('⚠️ [UPDATE] El JSON no tiene el bloque "versions"');
        return null;
      }

      // Buscar la versión para la arquitectura (o universal como fallback)
      Map<String, dynamic>? versionData;
      String usedArch = arch;

      if (versions.containsKey(arch)) {
        versionData = versions[arch] as Map<String, dynamic>;
        print('📦 [UPDATE] Encontrada versión específica para $arch');
      } else {
        versionData = versions['universal'] as Map<String, dynamic>?;
        usedArch = 'universal';
        print(
            '⚠️ [UPDATE] Arquitectura "$arch" no encontrada. Usando universal.');
      }

      if (versionData == null) {
        print('❌ [UPDATE] No hay versión disponible ni universal');
        return null;
      }

      final remoteVersion = versionData['versionCode'] as int?;
      final downloadUrl = versionData['downloadUrl'] as String?;
      final remoteName = data['versionName'] as String? ?? 'Nueva versión';

      if (remoteVersion == null || downloadUrl == null || downloadUrl.isEmpty) {
        print('❌ [UPDATE] Datos incompletos para $usedArch');
        return null;
      }

      final releaseNotesRaw = data['releaseNotes'];
      List<String> releaseNotes;
      if (releaseNotesRaw is List) {
        releaseNotes = releaseNotesRaw.map((e) => e.toString()).toList();
      } else if (releaseNotesRaw is String) {
        releaseNotes = [releaseNotesRaw];
      } else {
        releaseNotes = ['Novedades de la nueva versión'];
      }

      print(
          '📦 [UPDATE] JSON remoto ($usedArch): versionCode=$remoteVersion, versionName=$remoteName');
      print(
          '🔎 [UPDATE] Comparando: $remoteVersion > $currentBuildNumber ? ${remoteVersion > currentBuildNumber}');

      if (remoteVersion > currentBuildNumber) {
        print('✅ [UPDATE] ¡Hay actualización disponible!');
        return UpdateInfo(
          versionName: remoteName,
          versionCode: remoteVersion,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
        );
      } else {
        print('ℹ️ [UPDATE] No hay actualización disponible.');
        return null;
      }
    } on TimeoutException {
      print('⏰ [UPDATE] Tiempo de espera agotado al descargar JSON.');
      return null;
    } catch (e) {
      print('❌ [UPDATE] Error verificando actualizaciones: $e');
      return null;
    }
  }

  static Future<String> _getArchitecture() async {
    if (!Platform.isAndroid) return 'unknown';

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final abis = androidInfo.supportedAbis;
      final abi =
          abis.isNotEmpty ? abis.first : (androidInfo.hardware ?? 'unknown');

      if (abi.contains('arm64')) return 'arm64-v8a';
      if (abi.contains('armeabi')) return 'armeabi-v7a';
      if (abi.contains('x86_64')) return 'x86_64';
      if (abi.contains('x86')) return 'x86';
      return abi;
    } catch (e) {
      print('⚠️ [UPDATE] Error obteniendo arquitectura: $e');
      return 'unknown';
    }
  }
}

class UpdateInfo {
  final String versionName;
  final int versionCode;
  final List<String> releaseNotes;
  final String downloadUrl;

  UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}
