import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static const String baseUrl = 'https://tranqui-server.onrender.com/api';
  static const Duration timeout = Duration(seconds: 10);

  // ========== NEGOCIOS ==========
  static Future<List<Map<String, dynamic>>> getNegocios() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/negocios'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al obtener negocios');
        }
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. Intenta de nuevo.');
    } catch (e) {
      print('❌ Error en getNegocios: $e');
      rethrow;
    }
  }

  static Future<String> agregarNegocio({
    required String nombre,
    required double latitud,
    required double longitud,
    String? descripcion,
    String? municipio,
  }) async {
    try {
      final body = {
        'nombre': nombre,
        'latitud': latitud,
        'longitud': longitud,
        'descripcion': descripcion ?? '',
        'municipio': municipio ?? '',
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/negocios'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['id'];
        } else {
          throw Exception(data['message'] ?? 'Error al agregar negocio');
        }
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. Intenta de nuevo.');
    } catch (e) {
      print('❌ Error en agregarNegocio: $e');
      rethrow;
    }
  }

  // ========== COMENTARIOS (CON PUNTUACIÓN) ==========

  /// Obtener todos los comentarios de un negocio
  static Future<List<Map<String, dynamic>>> getComentarios(
      String negocioId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comentarios/$negocioId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al obtener comentarios');
        }
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. Intenta de nuevo.');
    } catch (e) {
      print('❌ Error en getComentarios: $e');
      rethrow;
    }
  }

  /// Agregar un nuevo comentario (con puntuación opcional)
  static Future<void> agregarComentario({
    required String negocioId,
    required String texto,
    String? autor,
    int? puntuacion, // ⭐ NUEVO: 1-5 estrellas (opcional)
  }) async {
    try {
      final body = {
        'texto': texto,
        'autor': autor ?? 'Anónimo',
        'puntuacion': puntuacion, // Puede ser null
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/comentarios/$negocioId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode != 201) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error al agregar comentario');
      }
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. Intenta de nuevo.');
    } catch (e) {
      print('❌ Error en agregarComentario: $e');
      rethrow;
    }
  }
}
