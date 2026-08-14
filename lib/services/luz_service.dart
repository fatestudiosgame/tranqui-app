import 'dart:convert';
import 'package:http/http.dart' as http;

class LuzService {
  static const String baseUrl =
      'https://tranqui-server.onrender.com/api'; // Cambiar a tu URL

  static Future<List<Map<String, dynamic>>> getReportes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reportes-luz'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al obtener reportes');
        }
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getReportes: $e');
      rethrow;
    }
  }

  static Future<void> reportarEstado({
    required double latitud,
    required double longitud,
    required bool estado,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reportes-luz'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitud': latitud,
              'longitud': longitud,
              'estado': estado,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 201) {
        throw Exception('Error al guardar reporte');
      }
    } catch (e) {
      print('❌ Error en reportarEstado: $e');
      rethrow;
    }
  }
}
