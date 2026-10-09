import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apklis_license_validator/apklis_license_validator.dart';
import 'mis_negocios.dart';
import '../services/api_service.dart';

class PantallaVip extends StatefulWidget {
  const PantallaVip({super.key});

  @override
  State<PantallaVip> createState() => _PantallaVipState();
}

class _PantallaVipState extends State<PantallaVip> {
  bool _cargando = false;
  bool _verificando = true;
  bool _tieneLicenciaActiva = false;
  String? _licenciaActual;
  String? _tipoPlanActual;
  String? _usernameActual;
  DateTime? _fechaExpiracion;
  String? _errorMensaje;

  static const String _keyLicencia = 'vip_licencia';
  static const String _keyTipoPlan = 'vip_tipo_plan';
  static const String _keyUsername = 'vip_username';
  static const String _keyFechaExpiracion = 'vip_fecha_expiracion';

  static const Duration _timeoutCompra = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _verificarLicenciaExistente();
  }

  int _rankPlan(String? plan) {
    final t = (plan ?? '').toLowerCase();
    if (t.contains('oro')) return 3;
    if (t.contains('plata')) return 2;
    if (t.contains('bronce')) return 1;
    return 0;
  }

  String _licenseIdPorTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('oro')) return '03db8bae-3cf0-4d1b-8f72-c39234d1e13d';
    if (t.contains('plata')) return '47bc21c5-5c23-4ab0-802e-1925e0936f5e';
    if (t.contains('bronce')) return 'ddcf3c7f-8172-473a-b911-527e5c361fa0';
    return '';
  }

  List<Map<String, dynamic>> _planesComerciales() {
    return [
      {
        'tipo': 'Bronce Plus',
        'rank': 1,
        'precio': '250 CUP',
        'dias': '30 días',
        'negocios': '1 negocio',
        'color': const Color(0xFFCD7F32),
        'icono': Icons.workspace_premium,
      },
      {
        'tipo': 'Plata Plus',
        'rank': 2,
        'precio': '500 CUP',
        'dias': '180 días',
        'negocios': '3 negocios',
        'color': const Color(0xFF808080),
        'icono': Icons.workspace_premium,
      },
      {
        'tipo': 'Oro Plus',
        'rank': 3,
        'precio': '1000 CUP',
        'dias': '360 días',
        'negocios': '5 negocios',
        'color': const Color(0xFFFFD700),
        'icono': Icons.star,
      },
    ];
  }

  Future<String> _planEfectivo(String username, String planLicencia) async {
    try {
      final todos =
          await ApiService.getNegocios().timeout(const Duration(seconds: 10));
      String maxPlan = planLicencia;
      int maxRank = _rankPlan(planLicencia);
      for (final n in todos) {
        if (n['propietarioUsername'] != username) continue;
        if (n['esVip'] != true) continue;
        final t = (n['tipoVip'] ?? '').toString();
        if (_rankPlan(t) > maxRank) {
          maxRank = _rankPlan(t);
          maxPlan = t;
        }
      }
      return maxPlan;
    } catch (_) {
      return planLicencia;
    }
  }

  Future<void> _verificarLicenciaExistente() async {
    setState(() => _verificando = true);
    try {
      final status = await ApklisLicenseValidator.verifyUserLicense(
        'com.fatestudiosgame.tranqui',
      );
      final esFalloDeFirma = !status.paid &&
          status.username != null &&
          status.username!.isNotEmpty &&
          status.error?.toString().contains('Firma') == true;

      if (status.paid && status.license != null) {
        await _procesarLicenciaValida(
          licencia: status.license!,
          username: status.username ?? '',
        );
      } else if (esFalloDeFirma) {
        await _verificarLicenciaLocal();
        if (!_tieneLicenciaActiva && mounted) _mostrarMensajeFirmaInvalida();
      } else {
        await _verificarLicenciaLocal();
      }
    } catch (e) {
      await _verificarLicenciaLocal();
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _navegarAMisNegocios() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MisNegocios(
          username: _usernameActual ?? '',
          tipoPlan: _tipoPlanActual ?? 'VIP',
          fechaExpiracion: _fechaExpiracion,
          licencia: _licenciaActual ?? '',
        ),
      ),
    );
    if (resultado == true && mounted) {
      setState(() {
        _tieneLicenciaActiva = false;
        _licenciaActual = null;
        _tipoPlanActual = null;
        _usernameActual = null;
        _fechaExpiracion = null;
      });
      _verificarLicenciaExistente();
    }
  }

  Future<void> _procesarLicenciaValida({
    required String licencia,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String tipoPlan = prefs.getString(_keyTipoPlan) ?? 'BroncePlus';
    DateTime? fechaExp = await _obtenerFechaExpiracionLocal();

    try {
      final resultado = await ApiService.getLicenciaVigente(username: username);
      if (resultado['vigente'] == true && resultado['data'] != null) {
        final data = resultado['data'] as Map<String, dynamic>;
        tipoPlan = data['tipoPlan'] as String? ?? tipoPlan;
        if (data['fechaExpiracion'] != null) {
          fechaExp = DateTime.tryParse(data['fechaExpiracion'] as String);
        }
      }
    } catch (_) {}

    tipoPlan = await _planEfectivo(username, tipoPlan);

    if (fechaExp == null) {
      fechaExp =
          DateTime.now().add(Duration(days: _obtenerDiasPorPlan(tipoPlan)));
    }

    setState(() {
      _tieneLicenciaActiva = true;
      _licenciaActual = licencia;
      _usernameActual = username;
      _tipoPlanActual = tipoPlan;
      _fechaExpiracion = fechaExp;
      _verificando = false;
    });

    await _guardarLicenciaLocal(
      licencia: licencia,
      username: username,
      tipoPlan: tipoPlan,
      fechaExpiracion: fechaExp,
    );
  }

  Future<void> _guardarLicenciaLocal({
    required String licencia,
    required String username,
    required String tipoPlan,
    DateTime? fechaExpiracion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLicencia, licencia);
    await prefs.setString(_keyTipoPlan, tipoPlan);
    await prefs.setString(_keyUsername, username);
    if (fechaExpiracion != null) {
      await prefs.setString(
          _keyFechaExpiracion, fechaExpiracion.toIso8601String());
    }
  }

  Future<void> _limpiarLicenciaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLicencia);
    await prefs.remove(_keyTipoPlan);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyFechaExpiracion);
  }

  Future<DateTime?> _obtenerFechaExpiracionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final fechaStr = prefs.getString(_keyFechaExpiracion);
    return fechaStr != null ? DateTime.tryParse(fechaStr) : null;
  }

  int? _diasRestantes() {
    if (_fechaExpiracion == null) return null;
    return _fechaExpiracion!.difference(DateTime.now()).inDays;
  }

  void _mostrarMensajeFirmaInvalida() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Error de validación',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Apklis confirma que tienes una licencia, pero hay un problema con la validación criptográfica.\n\n'
          'Verifica que el archivo license_private_key.pub esté en android/app/src/main/assets/',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoYaPagaste() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ya tienes esta licencia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Ya compraste esta licencia. Si no la ves activa, cierra la app y vuelve a abrirla.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _verificarLicenciaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final licenciaGuardada = prefs.getString(_keyLicencia);
    final fechaExpStr = prefs.getString(_keyFechaExpiracion);
    if (licenciaGuardada != null && fechaExpStr != null) {
      final fechaExp = DateTime.tryParse(fechaExpStr);
      if (fechaExp != null && fechaExp.isAfter(DateTime.now())) {
        String tipoPlan = prefs.getString(_keyTipoPlan) ?? 'BroncePlus';
        final username = prefs.getString(_keyUsername) ?? '';
        if (username.isNotEmpty) {
          tipoPlan = await _planEfectivo(username, tipoPlan);
        }
        setState(() {
          _tieneLicenciaActiva = true;
          _licenciaActual = licenciaGuardada;
          _usernameActual = username;
          _tipoPlanActual = tipoPlan;
          _fechaExpiracion = fechaExp;
          _verificando = false;
        });
        return;
      } else {
        await _limpiarLicenciaLocal();
      }
    }
    setState(() {
      _tieneLicenciaActiva = false;
      _verificando = false;
    });
  }

  Future<void> _mostrarDialogoSinCuenta() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Inicia sesión en Apklis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'No detectamos ninguna cuenta de Apklis en este dispositivo.\n\n'
          'Abre la app de Apklis, inicia sesión y vuelve a intentar.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _verificando = true);
              await _verificarLicenciaExistente();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoPagoPendiente() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tienes un pago pendiente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Tienes un pago sin completar. Apklis bloquea nuevas compras hasta resolverlo.\n\nAbre la app de Apklis → Perfil → Mis licencias → Completa o cancela el pago pendiente.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoErrorPago() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error en el pago',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Hubo un problema al procesar el pago. Suele ser un timeout.\n\nPor favor intenta de nuevo.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoLicenciaActiva() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ya tienes una licencia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Ya tienes una licencia activa. Espera a que expire antes de comprar una nueva.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoTimeout() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('La espera se extendió',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Transfermóvil tardó más de 3 minutos en responder.\n\n'
          'Si el pago NO se realizó en tu banco, no te preocupes: no se cobró nada.\n\n'
          'Si SÍ se descontó el dinero, cierra Tranqui y vuelve a abrirla: la licencia aparecerá automáticamente.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarUpgrade(Map<String, dynamic> plan) async {
    final diasRestantes = _diasRestantes() ?? 0;
    final tipo = plan['tipo'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mejorar a $tipo', style: const TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vas a pasar de ${_tipoPlanActual ?? 'tu plan'} a $tipo.',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Tu tiempo restante de ${_tipoPlanActual ?? 'tu plan'} ($diasRestantes días) NO se transfiere. La nueva licencia correrá desde hoy por ${plan['dias']}.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _comprarLicencia(_licenseIdPorTipo(tipo), tipo);
  }

  Future<void> _comprarLicencia(String licenseId, String tipo) async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });
    try {
      final status = await ApklisLicenseValidator.purchaseLicense(licenseId)
          .timeout(_timeoutCompra);
      if (status.paid && status.license != null) {
        DateTime fechaExpiracion;
        try {
          final resultado = await ApiService.activarLicencia(
            licencia: status.license!,
            tipoPlan: tipo,
            username: status.username ?? 'desconocido',
          ).timeout(const Duration(seconds: 15));
          if (resultado['fechaActivacion'] != null) {
            final fechaActivacion =
                DateTime.parse(resultado['fechaActivacion']);
            fechaExpiracion =
                fechaActivacion.add(Duration(days: _obtenerDiasPorPlan(tipo)));
          } else {
            fechaExpiracion =
                DateTime.now().add(Duration(days: _obtenerDiasPorPlan(tipo)));
          }
        } catch (e) {
          fechaExpiracion =
              DateTime.now().add(Duration(days: _obtenerDiasPorPlan(tipo)));
        }
        await _guardarLicenciaLocal(
          licencia: status.license!,
          username: status.username ?? 'desconocido',
          tipoPlan: tipo,
          fechaExpiracion: fechaExpiracion,
        );
        if (mounted) {
          setState(() {
            _tieneLicenciaActiva = true;
            _licenciaActual = status.license;
            _usernameActual = status.username;
            _tipoPlanActual = tipo;
            _fechaExpiracion = fechaExpiracion;
            _cargando = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ¡Tu negocio ahora es VIP $tipo!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) setState(() => _cargando = false);
        if (status.statusCode == 403) {
          final errorStr = status.error?.toString() ?? '';
          final usernameVacio =
              status.username == null || status.username!.isEmpty;
          if (errorStr.contains('already_paid') ||
              errorStr.contains('Ya pagaste')) {
            await _mostrarDialogoYaPagaste();
          } else if (errorStr.contains('pending_payment') ||
              errorStr.contains('pendiente')) {
            await _mostrarDialogoPagoPendiente();
          } else if (usernameVacio ||
              errorStr.contains('credenciales') ||
              errorStr.contains('autenticación')) {
            await _mostrarDialogoSinCuenta();
          } else {
            await _mostrarDialogoSinCuenta();
          }
        } else if (status.statusCode == 402) {
          await _mostrarDialogoLicenciaActiva();
        } else if (status.statusCode == 400) {
          await _mostrarDialogoErrorPago();
        } else {
          String mensaje =
              status.error ?? 'Error desconocido al procesar el pago';
          if (mounted) {
            setState(() => _errorMensaje = mensaje);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('❌ $mensaje'), backgroundColor: Colors.red),
            );
          }
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _cargando = false);
        await _mostrarDialogoTimeout();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'Error inesperado: $e';
          _cargando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('❌ ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  int _obtenerDiasPorPlan(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('oro')) return 360;
    if (t.contains('plata')) return 180;
    if (t.contains('bronce') || t.contains('prueba')) return 30;
    return 30;
  }

  Future<void> _cerrarSesionVip() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión VIP?'),
        content: const Text(
          'Esto solo elimina la licencia de este dispositivo. Tu cuenta de Apklis no se ve afectada.\n\nÚtil para probar el flujo de compra de nuevo.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _limpiarLicenciaLocal();
      if (mounted) {
        setState(() {
          _tieneLicenciaActiva = false;
          _licenciaActual = null;
          _tipoPlanActual = null;
          _usernameActual = null;
          _fechaExpiracion = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Sesión VIP cerrada. Ahora puedes volver a comprar.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Widget _buildFilaPlanUpgrade(Map<String, dynamic> plan, int rankActual) {
    final rank = plan['rank'] as int;
    final mejorable = rank > rankActual;
    final esActual = rank == rankActual;
    final color = plan['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: mejorable ? color.withOpacity(0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mejorable ? color.withOpacity(0.4) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(plan['icono'] as IconData,
              color: mejorable ? color : Colors.grey, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['tipo'] as String,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: mejorable ? Colors.black87 : Colors.grey)),
                Text(
                    '${plan['precio']} • ${plan['dias']} • ${plan['negocios']}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (mejorable)
            ElevatedButton(
              onPressed: () => _confirmarUpgrade(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: color == const Color(0xFFFFD700)
                    ? Colors.black
                    : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Mejorar', style: TextStyle(fontSize: 12)),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(esActual ? 'Tu plan' : 'Inferior',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionMejorarPlan() {
    final rankActual = _rankPlan(_tipoPlanActual);
    final planes = _planesComerciales();
    final hayMejorables = planes.any((p) => (p['rank'] as int) > rankActual);
    if (!hayMejorables) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.trending_up, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 6),
            Text('Mejorar mi plan',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700)),
          ],
        ),
        const SizedBox(height: 8),
        ...planes.map((p) => _buildFilaPlanUpgrade(p, rankActual)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haz VIP tu Negocio'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (_tieneLicenciaActiva)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión VIP (solo pruebas)',
              onPressed: _cerrarSesionVip,
            ),
        ],
      ),
      body: _verificando
          ? const Center(child: CircularProgressIndicator())
          : _tieneLicenciaActiva
              ? _buildYaEsVip()
              : _buildOpcionesCompra(),
    );
  }

  Widget _buildYaEsVip() {
    final diasRestantes = _diasRestantes();
    final colorPlan = _obtenerColorPlan(_tipoPlanActual);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [colorPlan, colorPlan.withOpacity(0.7)]),
                  ),
                  child:
                      const Icon(Icons.verified, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text('¡Tu negocio es VIP $_tipoPlanActual!',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorPlan),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                if (_usernameActual != null)
                  Text('Usuario: $_usernameActual',
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      colorPlan.withOpacity(0.1),
                      colorPlan.withOpacity(0.05)
                    ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorPlan.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today,
                              color: colorPlan, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            diasRestantes != null
                                ? '$diasRestantes días restantes'
                                : 'Licencia activa',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorPlan),
                          ),
                        ],
                      ),
                      if (_fechaExpiracion != null) ...[
                        const SizedBox(height: 4),
                        Text(
                            'Expira: ${_fechaExpiracion!.day}/${_fechaExpiracion!.month}/${_fechaExpiracion!.year}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
                _buildSeccionMejorarPlan(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navegarAMisNegocios,
                    icon: const Icon(Icons.business),
                    label: const Text('Gestionar mis negocios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.map),
                    label: const Text('Ver mi negocio en el mapa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _obtenerColorPlan(String? tipo) {
    final t = tipo?.toLowerCase() ?? '';
    if (t.contains('oro')) return const Color(0xFFFFD700);
    if (t.contains('plata')) return const Color(0xFF808080);
    if (t.contains('bronce')) return const Color(0xFFCD7F32);
    if (t.contains('prueba')) return Colors.purple;
    return Colors.orange;
  }

  Widget _buildOpcionesCompra() {
    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade700],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Text('Haz VIP tu Negocio',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                        'Destaca en el mapa, recibe llamadas y mensajes directos',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (kDebugMode) ...[
                _buildPlanCard(
                  titulo: 'Prueba 1 peso',
                  precio: '1 CUP',
                  duracion: '30 días',
                  negocios: '1 negocio',
                  icono: Icons.bug_report,
                  color: Colors.purple,
                  descripcion: 'SOLO PARA DESARROLLO',
                  beneficios: [
                    'Prueba del flujo completo',
                    'Costo mínimo: 1 CUP',
                    '1 negocio',
                  ],
                  onComprar: () => _comprarLicencia(
                      'fefae80d-e638-4573-a88b-f3e2c25df0dd', 'Prueba'),
                  esPrueba: true,
                ),
                const SizedBox(height: 16),
              ],
              _buildPlanCard(
                titulo: 'Bronce Plus',
                precio: '250 CUP',
                duracion: '30 días',
                negocios: '1 negocio',
                icono: Icons.workspace_premium,
                color: const Color(0xFFCD7F32),
                descripcion: 'Para emprendedores',
                beneficios: [
                  'Marcador destacado en marrón',
                  'Botón de llamada',
                  'Botón de WhatsApp',
                  'Descripción VIP personalizada',
                  '1 negocio',
                ],
                onComprar: () => _comprarLicencia(
                    'ddcf3c7f-8172-473a-b911-527e5c361fa0', 'BroncePlus'),
              ),
              const SizedBox(height: 16),
              _buildPlanCard(
                titulo: 'Plata Plus',
                precio: '500 CUP',
                duracion: '180 días',
                negocios: '3 negocios',
                icono: Icons.workspace_premium,
                color: const Color(0xFF808080),
                descripcion: 'El favorito de los negocios',
                beneficios: [
                  'Todo lo de Bronce Plus',
                  'Marcador plateado premium',
                  'Mayor visibilidad en el mapa',
                  'Badge "POPULAR"',
                  'Hasta 3 negocios',
                ],
                onComprar: () => _comprarLicencia(
                    '47bc21c5-5c23-4ab0-802e-1925e0936f5e', 'PlataPlus'),
                popular: true,
              ),
              const SizedBox(height: 16),
              _buildPlanCard(
                titulo: 'Oro Plus',
                precio: '1000 CUP',
                duracion: '360 días',
                negocios: '5 negocios',
                icono: Icons.workspace_premium,
                color: const Color(0xFFFFD700),
                descripcion: 'Máxima visibilidad',
                beneficios: [
                  'Todo lo de Plata Plus',
                  'Marcador dorado con estrella',
                  'Máxima prioridad en el mapa',
                  'Badge "PREMIUM"',
                  'Hasta 5 negocios',
                  'Soporte prioritario',
                ],
                onComprar: () => _comprarLicencia(
                    '03db8bae-3cf0-4d1b-8f72-c39234d1e13d', 'OroPlus'),
              ),
              const SizedBox(height: 32),
            ],
          ),
          if (_cargando)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('Procesando pago...',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                          'Espera mientras Transfermóvil\ncompleta la transacción',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _cargando = false),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Cancelar espera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String titulo,
    required String precio,
    required String duracion,
    required String negocios,
    required IconData icono,
    required Color color,
    required String descripcion,
    required List<String> beneficios,
    required VoidCallback onComprar,
    bool popular = false,
    bool esPrueba = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esPrueba
              ? Colors.purple
              : (popular ? Colors.orange : Colors.grey.shade300),
          width: esPrueba ? 2 : (popular ? 2 : 1),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icono, color: color, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                          Text(descripcion,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(precio,
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(duracion,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.store, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      negocios,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...beneficios.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Text(b, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : onComprar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: color == const Color(0xFFFFD700)
                          ? Colors.black
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(esPrueba ? '🧪 Probar ahora' : 'Comprar ahora',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          if (popular)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Text('POPULAR',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          if (esPrueba)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Text('DEV',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
