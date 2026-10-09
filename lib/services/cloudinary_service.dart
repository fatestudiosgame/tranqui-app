import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:async';

class CloudinaryService {
  // ⭐ Tus datos de Cloudinary
  static const String cloudName = 'mucmrgi3';
  static const String uploadPreset = 'tranqui_uploads';

  // Objetivo de compresión (no estricto, solo orientativo para velocidad)
  static const int _targetKB = 150;
  static const Duration _timeout = Duration(seconds: 45);

  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Ruta de carpeta para la galería de un negocio
  static String folderGaleria(String negocioId) =>
      'tranqui/negocios/$negocioId/galeria';

  /// Ruta de carpeta para la foto de un producto del catálogo
  static String folderCatalogo(String negocioId) =>
      'tranqui/negocios/$negocioId/catalogo';

  /// Selecciona una imagen de galería o cámara
  static Future<XFile?> seleccionarImagen({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final picker = ImagePicker();
      return await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
    } catch (e) {
      print('❌ Error seleccionando imagen: $e');
      return null;
    }
  }

  /// Comprime la imagen intentando quedar por debajo de _targetKB.
  /// NUNCA lanza excepción ni bloquea: siempre devuelve los bytes (comprimidos o originales).
  static Future<Uint8List> comprimirImagen(XFile archivo) async {
    // Escalones: [anchoMáx, calidad]
    const escalones = [
      [1600, 85],
      [1280, 75],
      [1024, 65],
      [800, 55],
      [640, 45],
      [500, 35], // Escalón extra por si la imagen es muy pesada
    ];

    Uint8List? mejorResultado;
    int mejorSize = 999999999;

    // Leer bytes originales una sola vez para optimizar memoria y CPU
    final bytesOriginales = await archivo.readAsBytes();
    mejorResultado = bytesOriginales;
    mejorSize = bytesOriginales.lengthInBytes;

    // Si ya es pequeña, la devolvemos rápido sin procesar
    if (mejorSize <= _targetKB * 1024) {
      print('📸 Imagen ya óptima: ${(mejorSize / 1024).toStringAsFixed(0)} KB');
      return mejorResultado;
    }

    for (final escalon in escalones) {
      final ancho = escalon[0];
      final calidad = escalon[1];
      try {
        final comprimido = await FlutterImageCompress.compressWithList(
          bytesOriginales,
          minWidth: ancho,
          minHeight: ancho,
          quality: calidad,
          format: CompressFormat.jpeg,
        );

        final kb = comprimido.lengthInBytes / 1024;
        print(
            '🗜️ Compresión ${ancho}px q$calidad → ${kb.toStringAsFixed(0)} KB');

        // Guardamos el mejor resultado hasta ahora
        if (comprimido.lengthInBytes < mejorSize) {
          mejorResultado = comprimido;
          mejorSize = comprimido.lengthInBytes;
        }

        // Si llegamos al objetivo, paramos para ahorrar CPU y batería
        if (kb <= _targetKB) break;
      } catch (e) {
        print('⚠️ Fallo compresión en escalón $ancho: $e');
      }
    }

    return mejorResultado!;
  }

  /// Sube la imagen (ya comprimida) a Cloudinary sin firmar.
  /// Devuelve la URL pública (secure_url).
  /// NUNCA bloquea por tamaño: sube la mejor versión comprimida lograda.
  static Future<String> subirImagen({
    required XFile archivo,
    required String folder,
  }) async {
    final bytes = await comprimirImagen(archivo);
    final kb = bytes.lengthInBytes / 1024;
    print('🚀 Subiendo imagen optimizada de ${kb.toStringAsFixed(0)} KB...');

    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

    try {
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['secure_url'] as String?;
        if (url == null) throw Exception('Respuesta sin URL');
        print('✅ Imagen subida: $url');
        return url;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(
            data['error']?['message'] ?? 'Error ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('La subida tardó demasiado. Revisa tu conexión.');
    } catch (e) {
      print('❌ Error subiendo a Cloudinary: $e');
      rethrow;
    }
  }
}
