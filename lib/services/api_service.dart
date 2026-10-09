import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://tranqui-server.onrender.com/api';

  static const Duration _timeoutCorto = Duration(seconds: 10);
  static const Duration _timeoutLargo = Duration(seconds: 60);

  static bool _servidorDespierto = false;

  static Duration get _timeoutActual =>
      _servidorDespierto ? _timeoutCorto : _timeoutLargo;

  // ================================================================
  // NEGOCIOS
  // ================================================================

  static Future<List<Map<String, dynamic>>> getNegocios() async {
    try {
      print(
          '📡 [API] Obteniendo negocios (timeout: ${_timeoutActual.inSeconds}s, despierto: $_servidorDespierto)');

      final response = await http
          .get(Uri.parse('$baseUrl/negocios'))
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al obtener negocios');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on TimeoutException {
      print(
          '⏰ [API] Timeout al obtener negocios (${_timeoutActual.inSeconds}s)');
      throw Exception(
          'El servidor está tardando en responder. Intenta de nuevo.');
    } catch (e) {
      print('❌ [API] Error: $e');
      rethrow;
    }
  }

  /// Obtener UN solo negocio por ID (mucho más rápido que getNegocios)
  static Future<Map<String, dynamic>> getNegocioPorId(String id) async {
    final url = Uri.parse('$baseUrl/negocios/$id');
    try {
      print('📡 [API] Obteniendo negocio $id (endpoint específico)');
      final response = await http.get(url).timeout(_timeoutCorto);
      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
      throw Exception('Negocio no encontrado');
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en getNegocioPorId: $e');
      throw Exception('Error al cargar el negocio: $e');
    }
  }

  static Future<String> agregarNegocio({
    required String nombre,
    required double latitud,
    required double longitud,
    String? descripcion,
    String? provincia,
    String? municipio,
    String? categoriaPrincipal,
    List<String>? categoriasSecundarias,
  }) async {
    try {
      final body = {
        'nombre': nombre,
        'latitud': latitud,
        'longitud': longitud,
        'descripcion': descripcion ?? '',
        'provincia': provincia ?? '',
        'municipio': municipio ?? '',
        'categoriaPrincipal': categoriaPrincipal,
        'categoriasSecundarias': categoriasSecundarias ?? [],
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/negocios'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 201) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['id'];
        } else {
          throw Exception(data['message'] ?? 'Error al agregar negocio');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(
            data['message'] ?? 'Error al agregar: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception(
          'El servidor está tardando en responder. Intenta de nuevo.');
    } catch (e) {
      print('❌ [API] Error en agregarNegocio: $e');
      rethrow;
    }
  }

  // ================================================================
  // GESTIÓN VIP (usuario normal)
  // ================================================================

  static Future<Map<String, dynamic>> reclamarNegocio({
    required String negocioId,
    required String username,
    required String tipoVip,
    required DateTime vipHasta,
  }) async {
    try {
      final body = {
        'username': username,
        'tipoVip': tipoVip,
        'vipHasta': vipHasta.toIso8601String(),
      };

      final response = await http
          .put(
            Uri.parse('$baseUrl/negocios/$negocioId/reclamar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'negociosVigentes': data['negociosVigentes'] ?? 0,
            'limite': data['limite'] ?? 1,
          };
        }
        throw Exception(data['message'] ?? 'Error al reclamar negocio');
      } else if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Este negocio ya fue reclamado');
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Límite alcanzado');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en reclamarNegocio: $e');
      rethrow;
    }
  }

  static Future<void> liberarNegocio({
    required String negocioId,
    required String username,
  }) async {
    try {
      final body = {
        'username': username,
      };

      final response = await http
          .put(
            Uri.parse('$baseUrl/negocios/$negocioId/liberar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Error al liberar negocio');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en liberarNegocio: $e');
      rethrow;
    }
  }

  static Future<void> actualizarNegocioVip({
    required String negocioId,
    required String username,
    String? nombre,
    String? descripcion,
    String? descripcionVip,
    String? horario,
    String? telefono,
    String? whatsapp,
    String? categoriaPrincipal,
    List<String>? categoriasSecundarias,
  }) async {
    try {
      final body = <String, dynamic>{
        'username': username,
      };

      if (nombre != null) body['nombre'] = nombre;
      if (descripcion != null) body['descripcion'] = descripcion;
      if (descripcionVip != null) body['descripcionVip'] = descripcionVip;
      if (horario != null) body['horario'] = horario;
      if (telefono != null) body['telefono'] = telefono;
      if (whatsapp != null) body['whatsapp'] = whatsapp;
      if (categoriaPrincipal != null) {
        body['categoriaPrincipal'] = categoriaPrincipal;
      }
      if (categoriasSecundarias != null) {
        body['categoriasSecundarias'] = categoriasSecundarias;
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/negocios/$negocioId/vip'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Error al actualizar negocio');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en actualizarNegocioVip: $e');
      rethrow;
    }
  }

  // ================================================================
  // ⭐ FOTOS (Cloudinary)
  // ================================================================

  /// Guardar lista de URLs de fotos del negocio (propietario VIP o admin)
  static Future<void> actualizarFotosNegocio({
    required String negocioId,
    required String username,
    required List<String> fotos,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/negocios/$negocioId/fotos'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'fotos': fotos}),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Error al guardar fotos');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en actualizarFotosNegocio: $e');
      rethrow;
    }
  }

  // ================================================================
  // ⭐ LICENCIAS (preservar fecha original + fuente de verdad del tipo de plan)
  // ================================================================

  /// Registra la licencia en el backend la primera vez.
  /// Si ya estaba activada, devuelve la fecha original (NO se sobreescribe).
  /// Si intenta bajar de plan (downgrade) con una licencia superior vigente → 403.
  static Future<Map<String, dynamic>> activarLicencia({
    required String licencia,
    required String tipoPlan,
    required String username,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/licencias/activar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'licencia': licencia,
              'tipoPlan': tipoPlan,
              'username': username,
            }),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'fechaActivacion': data['fechaActivacion'],
            'yaExistia': data['yaExistia'] ?? false,
            'tipoPlan': data['tipoPlan'] ?? tipoPlan,
          };
        }
      }

      // ⭐ Manejo específico del downgrade bloqueado (403)
      if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ??
            'No puedes bajar de plan. Elige un plan superior.');
      }

      throw Exception('Error al activar licencia');
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en activarLicencia: $e');
      rethrow;
    }
  }

  /// ⭐ Consultar la licencia vigente del usuario.
  /// Fuente de verdad del tipo de plan (no confiar en SharedPreferences).
  static Future<Map<String, dynamic>> getLicenciaVigente({
    required String username,
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/licencias/vigente?username=$username'))
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'vigente': data['vigente'] == true,
            'data': data['data'],
          };
        }
      }
      return {'vigente': false, 'data': null};
    } on TimeoutException {
      return {'vigente': false, 'data': null};
    } catch (e) {
      print('❌ [API] Error en getLicenciaVigente: $e');
      return {'vigente': false, 'data': null};
    }
  }

  // ================================================================
  // CATEGORÍAS
  // ================================================================

  static Future<List<Map<String, dynamic>>> getCategorias() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/categorias'))
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al obtener categorías');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en getCategorias: $e');
      rethrow;
    }
  }

  // ================================================================
  // CATÁLOGO VIP
  // ================================================================

  /// Obtener lista plana de productos de un catálogo
  static Future<List<Map<String, dynamic>>> getCatalogoLista(
      String negocioId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/negocios/$negocioId/catalogo'))
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(
              (data['data'] as List).map((p) => Map<String, dynamic>.from(p)));
        }
        throw Exception(data['message'] ?? 'Error al obtener catálogo');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en getCatalogoLista: $e');
      rethrow;
    }
  }

  /// Obtener productos agrupados por categoría (para vista pública)
  static Future<Map<String, List<Map<String, dynamic>>>> getCatalogoAgrupado(
      String negocioId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/negocios/$negocioId/catalogo/agrupado'))
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          final rawData = data['data'] as Map<String, dynamic>;
          final result = <String, List<Map<String, dynamic>>>{};

          rawData.forEach((categoria, productos) {
            result[categoria] = List<Map<String, dynamic>>.from(
                (productos as List).map((p) => Map<String, dynamic>.from(p)));
          });

          return result;
        }
        throw Exception(data['message'] ?? 'Error al obtener catálogo');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en getCatalogoAgrupado: $e');
      rethrow;
    }
  }

  /// ⭐ Agregar producto al catálogo (admin o propietario)
  static Future<String> agregarProductoCatalogo({
    required String negocioId,
    String? adminUsername,
    String? propietarioUsername,
    required String nombre,
    String? descripcion,
    double? precio,
    String? moneda,
    String? categoria,
    String? imagenUrl,
    int? orden,
    bool? agotado,
  }) async {
    try {
      final body = <String, dynamic>{
        'nombre': nombre,
        'descripcion': descripcion ?? '',
        'precio': precio ?? 0,
        'moneda': moneda ?? 'CUP',
        'categoria': categoria ?? 'General',
        'imagenUrl': imagenUrl ?? '',
        'orden': orden ?? 0,
        'agotado': agotado ?? false,
      };

      if (adminUsername != null) body['adminUsername'] = adminUsername;
      if (propietarioUsername != null) {
        body['propietarioUsername'] = propietarioUsername;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/negocios/$negocioId/catalogo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 201) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['id'];
        }
        throw Exception(data['message'] ?? 'Error al agregar producto');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en agregarProductoCatalogo: $e');
      rethrow;
    }
  }

  /// ⭐ Actualizar producto del catálogo (admin o propietario)
  static Future<void> actualizarProductoCatalogo({
    required String negocioId,
    required String productoId,
    String? adminUsername,
    String? propietarioUsername,
    String? nombre,
    String? descripcion,
    double? precio,
    String? moneda,
    String? categoria,
    String? imagenUrl,
    int? orden,
    bool? activo,
    bool? agotado,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (adminUsername != null) body['adminUsername'] = adminUsername;
      if (propietarioUsername != null) {
        body['propietarioUsername'] = propietarioUsername;
      }
      if (nombre != null) body['nombre'] = nombre;
      if (descripcion != null) body['descripcion'] = descripcion;
      if (precio != null) body['precio'] = precio;
      if (moneda != null) body['moneda'] = moneda;
      if (categoria != null) body['categoria'] = categoria;
      if (imagenUrl != null) body['imagenUrl'] = imagenUrl;
      if (orden != null) body['orden'] = orden;
      if (activo != null) body['activo'] = activo;
      if (agotado != null) body['agotado'] = agotado;

      final response = await http
          .put(
            Uri.parse('$baseUrl/negocios/$negocioId/catalogo/$productoId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Error al actualizar producto');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en actualizarProductoCatalogo: $e');
      rethrow;
    }
  }

  /// ⭐ Eliminar producto del catálogo (soft delete) - admin o propietario
  static Future<void> eliminarProductoCatalogo({
    required String negocioId,
    required String productoId,
    String? adminUsername,
    String? propietarioUsername,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (adminUsername != null) body['adminUsername'] = adminUsername;
      if (propietarioUsername != null) {
        body['propietarioUsername'] = propietarioUsername;
      }

      final request = http.Request(
        'DELETE',
        Uri.parse('$baseUrl/negocios/$negocioId/catalogo/$productoId'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);

      final streamedResponse = await request.send().timeout(_timeoutActual);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Error al eliminar producto');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en eliminarProductoCatalogo: $e');
      rethrow;
    }
  }

  // ================================================================
  // ADMIN: Verificación
  // ================================================================

  static Future<bool> verificarEsAdmin(String username) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/admin/verificar?username=$username'))
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        return data['esAdmin'] == true;
      }
      return false;
    } on TimeoutException {
      return false;
    } catch (e) {
      print('❌ [API] Error en verificarEsAdmin: $e');
      return false;
    }
  }

  // ================================================================
  // ADMIN: Editar cualquier negocio
  // ================================================================

  static Future<void> adminEditarNegocio({
    required String adminUsername,
    required String negocioId,
    String? nombre,
    String? descripcion,
    String? descripcionVip,
    String? horario,
    String? telefono,
    String? whatsapp,
    String? categoriaPrincipal,
    List<String>? categoriasSecundarias,
    String? provincia,
    String? municipio,
    double? latitud,
    double? longitud,
  }) async {
    try {
      final body = <String, dynamic>{
        'adminUsername': adminUsername,
      };

      if (nombre != null) body['nombre'] = nombre;
      if (descripcion != null) body['descripcion'] = descripcion;
      if (descripcionVip != null) body['descripcionVip'] = descripcionVip;
      if (horario != null) body['horario'] = horario;
      if (telefono != null) body['telefono'] = telefono;
      if (whatsapp != null) body['whatsapp'] = whatsapp;
      if (categoriaPrincipal != null) {
        body['categoriaPrincipal'] = categoriaPrincipal;
      }
      if (categoriasSecundarias != null) {
        body['categoriasSecundarias'] = categoriasSecundarias;
      }
      if (provincia != null) body['provincia'] = provincia;
      if (municipio != null) body['municipio'] = municipio;
      if (latitud != null) body['latitud'] = latitud;
      if (longitud != null) body['longitud'] = longitud;

      final response = await http
          .put(
            Uri.parse('$baseUrl/admin/negocios/$negocioId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Error al editar negocio');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en adminEditarNegocio: $e');
      rethrow;
    }
  }

  // ================================================================
  // ADMIN: Borrar cualquier negocio
  // ================================================================

  static Future<void> adminBorrarNegocio({
    required String adminUsername,
    required String negocioId,
  }) async {
    try {
      final body = {
        'adminUsername': adminUsername,
      };

      final request = http.Request(
        'DELETE',
        Uri.parse('$baseUrl/admin/negocios/$negocioId'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);

      final streamedResponse = await request.send().timeout(_timeoutActual);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Error al borrar negocio');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en adminBorrarNegocio: $e');
      rethrow;
    }
  }

  // ================================================================
  // ADMIN: Cambiar estado VIP
  // ================================================================

  static Future<void> adminCambiarVipStatus({
    required String adminUsername,
    required String negocioId,
    required String accion,
    String? tipoVip,
    String? propietarioUsername,
    DateTime? vipHasta,
    bool? esNegocioPrueba,
  }) async {
    try {
      final body = <String, dynamic>{
        'adminUsername': adminUsername,
        'accion': accion,
      };

      if (tipoVip != null) body['tipoVip'] = tipoVip;
      if (propietarioUsername != null) {
        body['propietarioUsername'] = propietarioUsername;
      }
      if (vipHasta != null) body['vipHasta'] = vipHasta.toIso8601String();
      if (esNegocioPrueba != null) {
        body['esNegocioPrueba'] = esNegocioPrueba;
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/admin/negocios/$negocioId/vip-status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Error al cambiar VIP status');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en adminCambiarVipStatus: $e');
      rethrow;
    }
  }

  // ================================================================
  // ADMIN: Estadísticas del sistema
  // ================================================================

  static Future<Map<String, dynamic>> adminGetStats({
    required String adminUsername,
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/admin/stats?adminUsername=$adminUsername'))
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return Map<String, dynamic>.from(data['data']);
        }
        throw Exception(data['message'] ?? 'Error al obtener estadísticas');
      } else if (response.statusCode == 403) {
        throw Exception('No autorizado');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en adminGetStats: $e');
      rethrow;
    }
  }

  // ================================================================
  // COMENTARIOS
  // ================================================================

  static Future<List<Map<String, dynamic>>> getComentarios(
      String negocioId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/comentarios/$negocioId'))
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al obtener comentarios');
        }
      } else {
        throw Exception('Error al obtener comentarios');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder');
    } catch (e) {
      print('❌ [API] Error en getComentarios: $e');
      rethrow;
    }
  }

  static Future<void> agregarComentario({
    required String negocioId,
    required String texto,
    String? autor,
    int? puntuacion,
  }) async {
    try {
      final body = {
        'texto': texto,
        'autor': autor ?? 'Anónimo',
        'puntuacion': puntuacion,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/comentarios/$negocioId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 201) {
        _servidorDespierto = true;
        print('✅ [API] Comentario agregado correctamente');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error al agregar comentario');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder');
    } catch (e) {
      print('❌ [API] Error en agregarComentario: $e');
      rethrow;
    }
  }

  // ================================================================
  // ⭐ NOTIFICACIONES PUSH (FCM)
  // ================================================================

  /// Registra el token FCM del dispositivo en el servidor.
  /// Se llama automáticamente cuando Firebase genera o renueva el token.
  static Future<void> registrarTokenNotificacion({
    required String token,
    String? username,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/notificaciones/registrar-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'username': username,
            }),
          )
          .timeout(_timeoutCorto);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        print('✅ [API] Token FCM registrado');
      } else {
        print('⚠️ [API] Error registrando token: ${response.statusCode}');
      }
    } on TimeoutException {
      print('⚠️ [API] Timeout registrando token FCM');
    } catch (e) {
      // No lanzar excepción: el registro de token NO debe bloquear la app
      print('⚠️ [API] Error silencioso registrando token: $e');
    }
  }

  /// Envía una notificación push a TODOS los dispositivos registrados.
  /// Solo administradores pueden usar este endpoint.
  static Future<Map<String, dynamic>> enviarNotificacionATodos({
    required String adminUsername,
    required String titulo,
    required String mensaje,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/notificaciones/enviar-todos'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'adminUsername': adminUsername,
              'titulo': titulo,
              'mensaje': mensaje,
            }),
          )
          .timeout(_timeoutActual);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'enviados': data['enviados'] ?? 0,
            'fallos': data['fallos'] ?? 0,
            'total': data['total'] ?? 0,
            'anuncioId': data['anuncioId'],
          };
        }
        throw Exception(data['message'] ?? 'Error al enviar notificación');
      } else if (response.statusCode == 403) {
        throw Exception('Solo administradores pueden enviar notificaciones');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('El servidor está tardando en responder.');
    } catch (e) {
      print('❌ [API] Error en enviarNotificacionATodos: $e');
      rethrow;
    }
  }

  /// Obtiene los anuncios activos guardados en Firestore.
  /// Se usa como fallback cuando la app se abre y no recibió el push
  /// (usuario tenía la app cerrada o estaba sin internet).
  static Future<List<Map<String, dynamic>>> obtenerAnunciosActivos() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/notificaciones/anuncios-activos'))
          .timeout(_timeoutCorto);

      if (response.statusCode == 200) {
        _servidorDespierto = true;
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(
              (data['data'] as List).map((a) => Map<String, dynamic>.from(a)));
        }
      }
      return [];
    } on TimeoutException {
      print('⚠️ [API] Timeout obteniendo anuncios');
      return [];
    } catch (e) {
      // No lanzar excepción: los anuncios son un feature secundario
      print('⚠️ [API] Error silencioso obteniendo anuncios: $e');
      return [];
    }
  }
}
