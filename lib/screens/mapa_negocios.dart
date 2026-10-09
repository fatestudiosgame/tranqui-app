import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../data/cuba_locations.dart';
import '../data/categorias.dart';
import '../widgets/banner_widget.dart';
import '../widgets/fotos_widgets.dart';
import 'lista_negocios.dart';
import 'comentarios_screen.dart';
import 'pantalla_vip.dart';
import 'mis_negocios.dart';
import 'admin_panel.dart';
import 'catalogo_negocio.dart';
import 'gestionar_catalogo.dart';
import 'gestion_fotos_negocio.dart';
import 'pagina_negocio.dart';
import '../services/compartir_service.dart';
import '../services/licencia_service.dart';

class MapaNegocios extends StatefulWidget {
  final String? initialNegocioId;

  const MapaNegocios({super.key, this.initialNegocioId});

  @override
  State<MapaNegocios> createState() => _MapaNegociosState();
}

class _MapaNegociosState extends State<MapaNegocios>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  LatLng? _miUbicacion;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> negocios = [];
  bool _cargando = true;
  bool _error = false;
  bool _sincronizando = false;
  bool _modoOffline = false;
  bool _modoSeleccion = false;
  LatLng? _coordenadasSeleccionadas;
  String? _grupoSeleccionado;
  bool _obteniendoUbicacion = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  CacheStore? _mapCacheStore;
  CacheOptions? _mapCacheOptions;
  bool _cacheInicializado = false;
  String _appVersion = '';
  Timer? _tituloTimer;
  bool _mostrandoContador = false;
  bool _actualizandoEnSegundoPlano = false;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSubscription;
  String? _ultimoDeepLinkProcesado;

  static const List<String> _slogans = [
    'Aquí pasan transferencia sin ponerte cara rara 😏',
    'Los negocios de aquí que no le tienen miedo a Transfermóvil 💪',
    'Aquí la transferencia no es ciencia ficción 🚀',
    'Paga aquí con transferencia sin que te miren feo 👀',
  ];
  late String _sloganActual;

  // ⭐ FIX: Límites de coordenadas válidas para Cuba
  static const double _minLat = 19.0;
  static const double _maxLat = 24.0;
  static const double _minLon = -85.5;
  static const double _maxLon = -73.5;
  static const double _minZoom = 5.0;
  static const double _maxZoom = 18.0;

  // ⭐ FIX: Validar coordenadas antes de usarlas en el mapa
  bool _coordenadasValidas(LatLng punto) {
    return punto.latitude.isFinite &&
        punto.longitude.isFinite &&
        punto.latitude >= _minLat &&
        punto.latitude <= _maxLat &&
        punto.longitude >= _minLon &&
        punto.longitude <= _maxLon;
  }

  // ⭐ FIX: Mover el mapa de forma segura
  void _moverMapaSeguro(LatLng punto, double zoom) {
    if (!_coordenadasValidas(punto)) {
      print('⚠️ Coordenadas inválidas, no moviendo mapa: $punto');
      return;
    }
    final zoomSeguro = zoom.clamp(_minZoom, _maxZoom);
    try {
      _mapController.move(punto, zoomSeguro);
    } catch (e) {
      print('⚠️ Error moviendo mapa: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _sloganActual = _slogans[Random().nextInt(_slogans.length)];
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _inicializarCache();
    _obtenerUbicacion();
    _cargarNegocios().then((_) {
      if (widget.initialNegocioId != null &&
          widget.initialNegocioId!.isNotEmpty) {
        _abrirNegocioPorId(widget.initialNegocioId!, intentos: 0);
      }
    });
    _obtenerVersionApp();
    _iniciarTimerTitulo();
    _initDeepLinks();
    LicenciaService.sincronizar().then((r) {
      if (!mounted) return;
      setState(() {});
      if (r.recienDetectada && r.esVip) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Licencia VIP activa: ${r.tipoPlan}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarYActualizarSiNecesario();
    }
  }

  Future<void> _verificarYActualizarSiNecesario() async {
    if (_actualizandoEnSegundoPlano) return;
    if (negocios.isEmpty) return;
    final cacheVieja = await LocalStorageService.esCacheVieja(maxMinutos: 15);
    if (!cacheVieja || !mounted) return;
    bool hasInternet;
    if (kIsWeb) {
      hasInternet = true;
    } else {
      final connectivityResult = await Connectivity().checkConnectivity();
      hasInternet = connectivityResult != ConnectivityResult.none;
    }
    if (!hasInternet || !mounted) return;
    await _actualizarEnSegundoPlano();
  }

  Future<void> _actualizarEnSegundoPlano() async {
    if (_actualizandoEnSegundoPlano) return;
    setState(() {
      _actualizandoEnSegundoPlano = true;
    });
    try {
      final data =
          await ApiService.getNegocios().timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() {
          negocios = data;
          _modoOffline = false;
          _error = false;
        });
        await LocalStorageService.guardarNegocios(data);
        print('🔄 Negocios actualizados en segundo plano: ${data.length}');
      }
    } catch (e) {
      print('⚠️ Actualización en segundo plano falló: $e');
    } finally {
      if (mounted) {
        setState(() {
          _actualizandoEnSegundoPlano = false;
        });
      }
    }
  }

  void _initDeepLinks() {
    if (kIsWeb) {
      _leerDeepLinkWeb();
      return;
    }
    try {
      _deepLinkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
        _handleDeepLink(uri);
      });
    } catch (e) {
      print('⚠️ Error deep links: $e');
    }
  }

  void _leerDeepLinkWeb() {
    try {
      final uri = Uri.base;
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        print('🌐 Deep link web detectado: id=$id');
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _abrirNegocioPorId(id, intentos: 0);
          }
        });
      }
    } catch (e) {
      print('⚠️ Error leyendo URL web: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    print('🔗 Deep link recibido en mapa: $uri');
    if (uri.scheme == 'tranqui' && uri.host == 'negocio') {
      final negocioId =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (negocioId != null && negocioId.isNotEmpty) {
        _abrirNegocioPorId(negocioId, intentos: 0);
      }
    }
  }

  void _abrirNegocioPorId(String negocioId, {required int intentos}) {
    if (_ultimoDeepLinkProcesado == negocioId) {
      print('⚠️ Deep link ya procesado, ignorando: $negocioId');
      return;
    }
    if (intentos >= 35) {
      print('❌ Máximo de reintentos alcanzado: $negocioId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se pudo abrir el negocio'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (negocios.isEmpty) {
      print('⏳ Esperando negocios para deep link (intento ${intentos + 1})...');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _abrirNegocioPorId(negocioId, intentos: intentos + 1);
        }
      });
      return;
    }
    _ultimoDeepLinkProcesado = negocioId;
    final negocio = negocios.firstWhere(
      (n) => n['id'] == negocioId,
      orElse: () => <String, dynamic>{},
    );
    if (negocio.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Negocio no encontrado'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final esVip = negocio['esVip'] == true;
    if (esVip) {
      Future.delayed(const Duration(milliseconds: 400), () async {
        if (mounted) {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaginaNegocio(negocioId: negocioId),
            ),
          );
          // ⭐ FIX: Validar el resultado antes de mover el mapa
          if (resultado is LatLng && mounted) {
            _centrarEnNegocio(resultado);
          } else if (resultado == true && mounted) {
            await _cargarNegocios();
          }
        }
      });
      return;
    }
    final lat = negocio['latitud'] as double?;
    final lon = negocio['longitud'] as double?;
    // ⭐ FIX: Validar coordenadas antes de crear LatLng
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      print('⚠️ Coordenadas inválidas para negocio $negocioId');
      return;
    }
    final punto = LatLng(lat, lon);
    if (!_coordenadasValidas(punto)) {
      print('⚠️ Coordenadas fuera de rango para negocio $negocioId: $punto');
      return;
    }
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _moverMapaSeguro(punto, 17.0);
      print('✅ Mapa centrado en: $lat, $lon');
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        _mostrarPopupNegocio(context, negocio);
      }
    });
  }

  void _iniciarTimerTitulo() {
    _tituloTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _mostrandoContador = !_mostrandoContador;
        });
      }
    });
  }

  List<Map<String, dynamic>> get negociosFiltrados {
    if (_grupoSeleccionado == null || _grupoSeleccionado == 'todos') {
      return negocios;
    }
    return negocios.where((n) {
      final cat = n['categoriaPrincipal'] as String?;
      if (cat == null) return false;
      final grupo = buscarGrupoDeCategoria(cat);
      return grupo?.id == _grupoSeleccionado;
    }).toList();
  }

  void _cambiarFiltroGrupo(String? grupoId) {
    setState(() {
      if (_grupoSeleccionado == grupoId) {
        _grupoSeleccionado = null;
      } else {
        _grupoSeleccionado = grupoId;
      }
    });
  }

  Future<void> _obtenerVersionApp() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      print('❌ Error obteniendo versión: $e');
    }
  }

  Future<void> _inicializarCache() async {
    try {
      if (kIsWeb) {
        _mapCacheStore = MemCacheStore();
        setState(() {
          _cacheInicializado = true;
        });
        return;
      }
      final dir = await getApplicationSupportDirectory();
      _mapCacheStore = HiveCacheStore('${dir.path}/map_cache');
      _mapCacheOptions = CacheOptions(
        store: _mapCacheStore!,
        policy: CachePolicy.request,
        maxStale: const Duration(days: 90),
        hitCacheOnErrorExcept: [401, 403],
      );
      setState(() {
        _cacheInicializado = true;
      });
    } catch (e) {
      print('❌ Error inicializando caché del mapa: $e');
      setState(() {
        _cacheInicializado = true;
      });
    }
  }

  Future<void> _limpiarCacheYRecargar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar caché y recargar'),
        content: const Text(
            'Se eliminarán los datos y mapas guardados, y se recargará todo desde el servidor. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await LocalStorageService.limpiarCache();
    } catch (e) {
      print('⚠️ Error limpiando datos: $e');
    }
    try {
      await _mapCacheStore?.clean();
    } catch (e) {
      print('⚠️ Error limpiando mapas: $e');
    }
    if (mounted) {
      setState(() {
        negocios = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Caché limpiada, recargando...'),
          backgroundColor: Colors.green,
        ),
      );
      await _cargarNegocios();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _tituloTimer?.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  void _abrirWhatsAppContacto() async {
    const url = 'https://wa.me/5353906342';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  void _abrirWhatsApp(String whatsapp) async {
    final numeroLimpio = whatsapp.replaceAll(RegExp(r'[^\d]'), '');
    final url = 'https://wa.me/$numeroLimpio';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Future<void> _cargarNegocios() async {
    setState(() {
      _cargando = true;
      _error = false;
      _sincronizando = true;
    });
    List<dynamic> datosLocales = [];
    try {
      datosLocales = await LocalStorageService.obtenerNegocios();
      if (datosLocales.isNotEmpty) {
        setState(() {
          negocios =
              datosLocales.map((e) => Map<String, dynamic>.from(e)).toList();
          _cargando = false;
          _modoOffline = true;
        });
      }
    } catch (e) {
      datosLocales = [];
    }
    bool hasInternet;
    if (kIsWeb) {
      hasInternet = true;
    } else {
      final connectivityResult = await Connectivity().checkConnectivity();
      hasInternet = connectivityResult != ConnectivityResult.none;
    }
    if (!hasInternet) {
      setState(() {
        _cargando = false;
        _sincronizando = false;
        _modoOffline = true;
        if (datosLocales.isEmpty) _error = true;
      });
      return;
    }
    final bool tieneDatosLocales = datosLocales.isNotEmpty;
    try {
      final timeout = tieneDatosLocales
          ? const Duration(seconds: 15)
          : const Duration(seconds: 60);
      final data = await ApiService.getNegocios().timeout(timeout);
      if (mounted) {
        setState(() {
          negocios = data;
          _cargando = false;
          _error = false;
          _sincronizando = false;
          _modoOffline = false;
        });
      }
      await LocalStorageService.guardarNegocios(data);
    } on TimeoutException {
      if (tieneDatosLocales && mounted) {
        setState(() {
          _cargando = false;
          _sincronizando = false;
          _modoOffline = true;
        });
      } else if (mounted) {
        setState(() {
          _error = true;
          _cargando = false;
          _sincronizando = false;
        });
      }
    } catch (e) {
      if (!tieneDatosLocales) {
        if (mounted) {
          setState(() {
            _error = true;
            _cargando = false;
            _sincronizando = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cargando = false;
            _sincronizando = false;
            _modoOffline = true;
          });
        }
      }
    }
  }

  // ⭐ FIX: Centrar el mapa de forma segura
  void _centrarEnNegocio(LatLng punto) {
    if (!_coordenadasValidas(punto)) {
      print('⚠️ Coordenadas inválidas en _centrarEnNegocio: $punto');
      return;
    }
    _moverMapaSeguro(punto, 16.0);
  }

  IconData _obtenerIconoPorCategoria(String? categoriaId) {
    if (categoriaId == null) return Icons.store;
    final grupo = buscarGrupoDeCategoria(categoriaId);
    if (grupo == null) return Icons.store;
    return obtenerIcono(grupo.icono);
  }

  Future<void> _mostrarFiltroCategorias() async {
    final hayFiltroActivo =
        _grupoSeleccionado != null && _grupoSeleccionado != 'todos';
    final resultado = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Filtrar por categoría',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (hayFiltroActivo) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Filtro activo: ${_obtenerNombreGrupoActivo()}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'QUITAR_FILTRO'),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Quitar filtro actual'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildChipFiltroSheet(
                label: 'Todos',
                icono: Icons.apps,
                color: Colors.orange,
                seleccionado:
                    _grupoSeleccionado == null || _grupoSeleccionado == 'todos',
                onTap: () => Navigator.pop(context, 'todos'),
              ),
              const SizedBox(height: 8),
              ...gruposCategorias.map((grupo) {
                final color = obtenerColorGrupo(grupo.colorHex);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildChipFiltroSheet(
                    label: grupo.nombre,
                    icono: obtenerIcono(grupo.icono),
                    color: color,
                    seleccionado: _grupoSeleccionado == grupo.id,
                    onTap: () => Navigator.pop(context, grupo.id),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (resultado == 'QUITAR_FILTRO') {
      _cambiarFiltroGrupo(null);
    } else if (resultado != null && mounted) {
      _cambiarFiltroGrupo(resultado);
    }
  }

  String _obtenerNombreGrupoActivo() {
    if (_grupoSeleccionado == null || _grupoSeleccionado == 'todos') {
      return 'Todos';
    }
    final grupo = gruposCategorias.firstWhere(
      (g) => g.id == _grupoSeleccionado,
      orElse: () => gruposCategorias.first,
    );
    return grupo.nombre;
  }

  Widget _buildChipFiltroSheet({
    required String label,
    required IconData icono,
    required Color color,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? color : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: seleccionado ? color : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (seleccionado) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarFormularioNegocio(LatLng coordenadas) async {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    String? provinciaSeleccionada;
    String? municipioSeleccionado;
    String? grupoSeleccionado;
    String? categoriaSeleccionada;
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nuevo Negocio', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '📍 ${coordenadas.latitude.toStringAsFixed(6)}, ${coordenadas.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Negocio *',
                      hintText: 'Ej: Restaurante Fellini',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Aceptan Transfermóvil, EnZona...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: grupoSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Grupo *',
                      hintText: 'Ej: Comida, Compras...',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: gruposCategorias.map((grupo) {
                      return DropdownMenuItem<String>(
                        value: grupo.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(obtenerIcono(grupo.icono), size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(grupo.nombre,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        grupoSeleccionado = newValue;
                        categoriaSeleccionada = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Categoría *',
                      hintText: grupoSeleccionado == null
                          ? 'Primero elige un grupo'
                          : 'Selecciona la categoría',
                      prefixIcon: const Icon(Icons.label),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: grupoSeleccionado == null
                        ? <DropdownMenuItem<String>>[]
                        : (gruposCategorias
                                .firstWhere((g) => g.id == grupoSeleccionado,
                                    orElse: () => gruposCategorias.first)
                                .categorias)
                            .map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat.id,
                              child: Text(cat.nombre,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                    onChanged: grupoSeleccionado == null
                        ? null
                        : (String? newValue) {
                            setDialogState(() {
                              categoriaSeleccionada = newValue;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: provinciaSeleccionada,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Provincia *',
                      hintText: 'Selecciona la provincia',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: provincias.map((String provincia) {
                      return DropdownMenuItem<String>(
                        value: provincia,
                        child: Text(provincia, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        provinciaSeleccionada = newValue;
                        municipioSeleccionado = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: municipioSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Municipio *',
                      hintText: 'Selecciona el municipio',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: provinciaSeleccionada == null
                        ? <DropdownMenuItem<String>>[]
                        : (cubaLocations[provinciaSeleccionada] ?? <String>[])
                            .map((String municipio) {
                            return DropdownMenuItem<String>(
                              value: municipio,
                              child: Text(municipio,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                    onChanged: provinciaSeleccionada == null
                        ? null
                        : (String? newValue) {
                            setDialogState(() {
                              municipioSeleccionado = newValue;
                            });
                          },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                if (grupoSeleccionado == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona el grupo')),
                  );
                  return;
                }
                if (categoriaSeleccionada == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona la categoría')),
                  );
                  return;
                }
                if (provinciaSeleccionada == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona la provincia')),
                  );
                  return;
                }
                if (municipioSeleccionado == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona el municipio')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'nombre': nombre,
                  'descripcion': descripcionController.text.trim(),
                  'grupo': grupoSeleccionado!,
                  'categoria': categoriaSeleccionada!,
                  'provincia': provinciaSeleccionada!,
                  'municipio': municipioSeleccionado!,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (resultado != null) {
      try {
        await ApiService.agregarNegocio(
          nombre: resultado['nombre'],
          latitud: coordenadas.latitude,
          longitud: coordenadas.longitude,
          descripcion: resultado['descripcion'],
          provincia: resultado['provincia'],
          municipio: resultado['municipio'],
          categoriaPrincipal: resultado['categoria'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Negocio agregado con éxito')),
          );
          if (_modoSeleccion) {
            setState(() {
              _modoSeleccion = false;
              _coordenadasSeleccionadas = null;
            });
          }
          await _cargarNegocios();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al guardar: ${e.toString().replaceFirst('Exception: ', '')}'),
            ),
          );
        }
      }
    } else {
      if (_modoSeleccion) {
        setState(() {
          _modoSeleccion = false;
          _coordenadasSeleccionadas = null;
        });
      }
    }
  }

  void _onMapTap(TapPosition? tapPosition, LatLng punto) {
    if (_modoSeleccion) {
      setState(() {
        _coordenadasSeleccionadas = punto;
      });
      _mostrarFormularioNegocio(punto);
    }
  }

  void _onMapLongPress(TapPosition? tapPosition, LatLng punto) {
    if (!_modoSeleccion) {
      _mostrarFormularioNegocio(punto);
    }
  }

  Future<void> _manejarLongPressMarcador(
      BuildContext context, Map<String, dynamic> negocio) async {
    final esAdmin = await _verificarSiEsAdmin();
    if (esAdmin) {
      _mostrarOpcionesAdmin(context, negocio);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    final esDueno =
        username.isNotEmpty && negocio['propietarioUsername'] == username;
    if (esDueno && _esVipVigente(negocio)) {
      _mostrarOpcionesDueno(context, negocio, username);
      return;
    }
    _mostrarPopupNegocio(context, negocio);
  }

  Future<void> _mostrarOpcionesDueno(BuildContext context,
      Map<String, dynamic> negocio, String username) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.store, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mi negocio: ${negocio['nombre'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildOpcionAdmin(
                icon: Icons.edit,
                color: Colors.blue,
                titulo: 'Editar información',
                descripcion: 'Nombre, descripción, horario, teléfonos',
                onTap: () => Navigator.pop(context, 'editar'),
              ),
              const SizedBox(height: 8),
              _buildOpcionAdmin(
                icon: Icons.menu_book,
                color: Colors.teal,
                titulo: 'Gestionar catálogo',
                descripcion: 'Agregar o editar productos',
                onTap: () => Navigator.pop(context, 'catalogo'),
              ),
              const SizedBox(height: 8),
              _buildOpcionAdmin(
                icon: Icons.photo_library,
                color: Colors.teal,
                titulo: 'Gestionar fotos',
                descripcion: 'Subir o quitar fotos',
                onTap: () => Navigator.pop(context, 'fotos'),
              ),
            ],
          ),
        ),
      ),
    );
    if (accion == null) return;
    switch (accion) {
      case 'editar':
        await _editarNegocioDueno(negocio, username);
        break;
      case 'catalogo':
        await _gestionarCatalogo(negocio);
        break;
      case 'fotos':
        await _gestionarFotos(negocio);
        break;
    }
  }

  Future<void> _editarNegocioDueno(
      Map<String, dynamic> negocio, String username) async {
    final nombreController =
        TextEditingController(text: negocio['nombre'] ?? '');
    final descripcionController =
        TextEditingController(text: negocio['descripcion'] ?? '');
    final descripcionVipController =
        TextEditingController(text: negocio['descripcionVip'] ?? '');
    final horarioController =
        TextEditingController(text: negocio['horario'] ?? '');
    final telefonoController =
        TextEditingController(text: negocio['telefono'] ?? '');
    final whatsappController =
        TextEditingController(text: negocio['whatsapp'] ?? '');
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar mi negocio', style: TextStyle(fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.store),
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 12),
                TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        isDense: true),
                    maxLines: 2),
                const SizedBox(height: 12),
                TextField(
                    controller: descripcionVipController,
                    decoration: const InputDecoration(
                        labelText: 'Descripción VIP',
                        prefixIcon: Icon(Icons.star),
                        border: OutlineInputBorder(),
                        isDense: true),
                    maxLines: 2),
                const SizedBox(height: 12),
                TextField(
                    controller: horarioController,
                    decoration: const InputDecoration(
                        labelText: 'Horario',
                        prefixIcon: Icon(Icons.schedule),
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 12),
                TextField(
                    controller: telefonoController,
                    decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        isDense: true),
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(
                    controller: whatsappController,
                    decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        prefixIcon: Icon(Icons.chat),
                        border: OutlineInputBorder(),
                        isDense: true),
                    keyboardType: TextInputType.phone),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'nombre': nombreController.text.trim(),
              'descripcion': descripcionController.text.trim(),
              'descripcionVip': descripcionVipController.text.trim(),
              'horario': horarioController.text.trim(),
              'telefono': telefonoController.text.trim(),
              'whatsapp': whatsappController.text.trim(),
            }),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (resultado == null) return;
    try {
      await ApiService.actualizarNegocioVip(
        negocioId: negocio['id'],
        username: username,
        nombre: resultado['nombre'],
        descripcion: resultado['descripcion'],
        descripcionVip: resultado['descripcionVip'],
        horario: resultado['horario'],
        telefono: resultado['telefono'],
        whatsapp: resultado['whatsapp'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Negocio actualizado'),
              backgroundColor: Colors.green),
        );
        await _cargarNegocios();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '❌ Error: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _mostrarOpcionesAdmin(
      BuildContext context, Map<String, dynamic> negocio) async {
    final esVip = negocio['esVip'] == true;
    final esPrueba = negocio['esNegocioPrueba'] == true;
    final accion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.indigo),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Opciones de Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                negocio['nombre'] ?? 'Sin nombre',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (esVip) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: esPrueba ? Colors.orange : Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    esPrueba
                        ? 'TEST (${(negocio['tipoVip'] ?? 'vip').toString().toUpperCase()})'
                        : (negocio['tipoVip'] ?? 'VIP')
                            .toString()
                            .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildOpcionAdmin(
                icon: Icons.edit,
                color: Colors.blue,
                titulo: 'Editar negocio',
                descripcion: 'Modificar datos del negocio',
                onTap: () => Navigator.pop(context, 'editar'),
              ),
              const SizedBox(height: 8),
              if (esVip) ...[
                _buildOpcionAdmin(
                  icon: Icons.menu_book,
                  color: Colors.teal,
                  titulo: 'Gestionar catálogo',
                  descripcion: 'Agregar o editar productos del catálogo',
                  onTap: () => Navigator.pop(context, 'catalogo'),
                ),
                const SizedBox(height: 8),
                _buildOpcionAdmin(
                  icon: Icons.photo_library,
                  color: Colors.teal,
                  titulo: 'Gestionar fotos',
                  descripcion: 'Subir o quitar fotos del negocio',
                  onTap: () => Navigator.pop(context, 'fotos'),
                ),
                const SizedBox(height: 8),
                _buildOpcionAdmin(
                  icon: Icons.swap_horiz,
                  color: Colors.purple,
                  titulo: 'Cambiar tipo de VIP',
                  descripcion: 'Cambiar entre Bronce, Plata, Oro, etc.',
                  onTap: () => Navigator.pop(context, 'cambiar-tipo'),
                ),
                const SizedBox(height: 8),
                _buildOpcionAdmin(
                  icon: Icons.access_time,
                  color: Colors.blue,
                  titulo: 'Extender VIP',
                  descripcion: 'Extender la fecha de expiración',
                  onTap: () => Navigator.pop(context, 'extender'),
                ),
                const SizedBox(height: 8),
                _buildOpcionAdmin(
                  icon: Icons.link_off,
                  color: Colors.red,
                  titulo: 'Liberar negocio',
                  descripcion: 'Quitar VIP y propietario',
                  onTap: () => Navigator.pop(context, 'liberar'),
                ),
              ] else
                _buildOpcionAdmin(
                  icon: Icons.add_business,
                  color: Colors.green,
                  titulo: 'Hacer VIP',
                  descripcion: 'Asignar VIP manualmente',
                  onTap: () => Navigator.pop(context, 'reclamar'),
                ),
              const SizedBox(height: 8),
              _buildOpcionAdmin(
                icon: Icons.delete_forever,
                color: Colors.red,
                titulo: 'Eliminar negocio',
                descripcion: 'Borrar permanentemente del sistema',
                onTap: () => Navigator.pop(context, 'borrar'),
              ),
              const SizedBox(height: 8),
              _buildOpcionAdmin(
                icon: Icons.info_outline,
                color: Colors.grey,
                titulo: 'Ver información',
                descripcion: 'Abrir detalles del negocio',
                onTap: () => Navigator.pop(context, 'info'),
              ),
            ],
          ),
        ),
      ),
    );
    if (accion == null) return;
    switch (accion) {
      case 'editar':
        await _editarNegocioAdmin(negocio);
        break;
      case 'catalogo':
        await _gestionarCatalogo(negocio);
        break;
      case 'fotos':
        await _gestionarFotos(negocio);
        break;
      case 'cambiar-tipo':
        await _cambiarTipoVipAdmin(negocio);
        break;
      case 'extender':
        await _extenderVipDesdeMapa(negocio);
        break;
      case 'liberar':
        await _liberarNegocioDesdeMapa(negocio);
        break;
      case 'reclamar':
        await _reclamarNegocioAdminDesdeMapa(negocio);
        break;
      case 'borrar':
        await _borrarNegocioAdmin(negocio);
        break;
      case 'info':
        if (mounted) _mostrarPopupNegocio(context, negocio);
        break;
    }
  }

  Widget _buildOpcionAdmin({
    required IconData icon,
    required Color color,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    descripcion,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _gestionarCatalogo(Map<String, dynamic> negocio) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty) return;
    final esAdmin = await _verificarSiEsAdmin();
    final esDueno = negocio['propietarioUsername'] == username;
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GestionarCatalogo(
            negocioId: negocio['id'],
            negocioNombre: negocio['nombre'] ?? 'Negocio',
            adminUsername: esAdmin ? username : null,
            propietarioUsername: esDueno ? username : null,
          ),
        ),
      );
    }
  }

  Future<void> _gestionarFotos(Map<String, dynamic> negocio) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GestionFotosNegocio(
          negocioId: negocio['id'],
          negocioNombre: negocio['nombre'] ?? 'Negocio',
          username: username,
          tipoPlan: (negocio['tipoVip'] as String?) ?? 'oro',
        ),
      ),
    );
  }

  Future<void> _editarNegocioAdmin(Map<String, dynamic> negocio) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty) return;
    final nombreController =
        TextEditingController(text: negocio['nombre'] ?? '');
    final descripcionController =
        TextEditingController(text: negocio['descripcion'] ?? '');
    final descripcionVipController =
        TextEditingController(text: negocio['descripcionVip'] ?? '');
    final horarioController =
        TextEditingController(text: negocio['horario'] ?? '');
    final telefonoController =
        TextEditingController(text: negocio['telefono'] ?? '');
    final whatsappController =
        TextEditingController(text: negocio['whatsapp'] ?? '');
    String grupoSeleccionado =
        buscarGrupoDeCategoria(negocio['categoriaPrincipal'] as String?)?.id ??
            'comida';
    String categoriaSeleccionada =
        (negocio['categoriaPrincipal'] as String?) ?? 'restaurante';
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings,
                  color: Colors.indigo, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editar: ${negocio['nombre'] ?? 'Negocio'}',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: grupoSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Grupo',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: gruposCategorias.map((grupo) {
                      return DropdownMenuItem<String>(
                        value: grupo.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(obtenerIcono(grupo.icono), size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(grupo.nombre,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        grupoSeleccionado = newValue ?? 'comida';
                        final grupoObj = gruposCategorias.firstWhere(
                          (g) => g.id == grupoSeleccionado,
                          orElse: () => gruposCategorias.first,
                        );
                        categoriaSeleccionada = grupoObj.categorias.first.id;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.label),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: gruposCategorias
                        .firstWhere((g) => g.id == grupoSeleccionado,
                            orElse: () => gruposCategorias.first)
                        .categorias
                        .map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat.id,
                        child:
                            Text(cat.nombre, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        categoriaSeleccionada = newValue ?? 'otros';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.store),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descripcionVipController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción VIP',
                      prefixIcon: Icon(Icons.star),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: horarioController,
                    decoration: const InputDecoration(
                      labelText: 'Horario',
                      prefixIcon: Icon(Icons.schedule),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: telefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: whatsappController,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp',
                      prefixIcon: Icon(Icons.chat),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'nombre': nombreController.text.trim(),
                  'descripcion': descripcionController.text.trim(),
                  'descripcionVip': descripcionVipController.text.trim(),
                  'horario': horarioController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  'whatsapp': whatsappController.text.trim(),
                  'categoriaPrincipal': categoriaSeleccionada,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (resultado == null) return;
    try {
      await ApiService.adminEditarNegocio(
        adminUsername: username,
        negocioId: negocio['id'],
        nombre: resultado['nombre'],
        descripcion: resultado['descripcion'],
        descripcionVip: resultado['descripcionVip'],
        horario: resultado['horario'],
        telefono: resultado['telefono'],
        whatsapp: resultado['whatsapp'],
        categoriaPrincipal: resultado['categoriaPrincipal'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Negocio actualizado'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cambiarTipoVipAdmin(Map<String, dynamic> negocio) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty) return;
    final tipoActual = (negocio['tipoVip'] as String?) ?? 'bronce';
    String tipoSeleccionado = tipoActual;
    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.purple, size: 22),
              SizedBox(width: 8),
              Expanded(
                child:
                    Text('Cambiar tipo de VIP', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    negocio['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tipo actual: ${tipoActual.toUpperCase()}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text('Selecciona el nuevo tipo:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildOpcionTipoVip(
                      setDialogState,
                      'prueba',
                      'Prueba',
                      'DEV',
                      Colors.purple,
                      tipoSeleccionado,
                      (v) => tipoSeleccionado = v),
                  _buildOpcionTipoVip(
                      setDialogState,
                      'bronceplus',
                      'Bronce Plus',
                      'B+',
                      const Color(0xFFCD7F32),
                      tipoSeleccionado,
                      (v) => tipoSeleccionado = v),
                  _buildOpcionTipoVip(
                      setDialogState,
                      'plataplus',
                      'Plata Plus',
                      'P+',
                      const Color(0xFF808080),
                      tipoSeleccionado,
                      (v) => tipoSeleccionado = v),
                  _buildOpcionTipoVip(
                      setDialogState,
                      'oroplus',
                      'Oro Plus',
                      'O+',
                      const Color(0xFFFFD700),
                      tipoSeleccionado,
                      (v) => tipoSeleccionado = v),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (tipoSeleccionado == tipoActual) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(context, tipoSeleccionado);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cambiar'),
            ),
          ],
        ),
      ),
    );
    if (resultado == null || resultado == tipoActual) return;
    try {
      await ApiService.adminCambiarVipStatus(
        adminUsername: username,
        negocioId: negocio['id'],
        accion: 'cambiar-tipo',
        tipoVip: resultado,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ Tipo de VIP cambiado a ${resultado.toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildOpcionTipoVip(
    void Function(void Function()) setDialogState,
    String valor,
    String nombre,
    String badge,
    Color color,
    String tipoSeleccionado,
    void Function(String) onChanged,
  ) {
    final seleccionado = tipoSeleccionado == valor;
    return InkWell(
      onTap: () {
        setDialogState(() => onChanged(valor));
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? color : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nombre,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: seleccionado ? color : Colors.black87,
                ),
              ),
            ),
            if (seleccionado) Icon(Icons.check_circle, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _extenderVipDesdeMapa(Map<String, dynamic> negocio) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty) return;
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Nueva fecha de expiración',
    );
    if (fecha == null) return;
    try {
      await ApiService.adminCambiarVipStatus(
        adminUsername: username,
        negocioId: negocio['id'],
        accion: 'extender',
        vipHasta: fecha,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ VIP extendido hasta ${fecha.day}/${fecha.month}/${fecha.year}'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _liberarNegocioDesdeMapa(Map<String, dynamic> negocio) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Liberar este negocio?'),
        content: Text(
          'Se quitará el estado VIP y el propietario de "${negocio['nombre']}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ApiService.adminCambiarVipStatus(
        adminUsername: username,
        negocioId: negocio['id'],
        accion: 'liberar',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Negocio liberado'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _borrarNegocioAdmin(Map<String, dynamic> negocio) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty) return;
    final nombreController = TextEditingController();
    final nombreNegocio = negocio['nombre'] ?? 'Sin nombre';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text('Eliminar permanentemente',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vas a eliminar PERMANENTEMENTE:',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                nombreNegocio,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta acción NO se puede deshacer. Se perderán fotos, catálogo, comentarios y todo lo asociado.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Para confirmar, escribe el nombre EXACTO del negocio:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nombreController,
                decoration: InputDecoration(
                  hintText: nombreNegocio,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreController.text.trim() == nombreNegocio) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ El nombre no coincide'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ApiService.adminBorrarNegocio(
        adminUsername: username,
        negocioId: negocio['id'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Negocio "$nombreNegocio" eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reclamarNegocioAdminDesdeMapa(
      Map<String, dynamic> negocio) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty) return;
    final propietarioController = TextEditingController();
    String tipoVipSeleccionado = 'bronceplus';
    DateTime? vipHasta;
    bool esNegocioPrueba = false;
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_business, color: Colors.green, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text('Hacer VIP manualmente',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: esNegocioPrueba
                          ? Colors.orange.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: esNegocioPrueba
                            ? Colors.orange
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: esNegocioPrueba,
                          onChanged: (value) {
                            setDialogState(() {
                              esNegocioPrueba = value ?? false;
                            });
                          },
                          activeColor: Colors.orange,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Negocio de prueba',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Text(
                                esNegocioPrueba
                                    ? 'Propietario: ${username}_usuario_test'
                                    : 'Para testing',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!esNegocioPrueba) ...[
                    TextField(
                      controller: propietarioController,
                      decoration: const InputDecoration(
                        labelText: 'Username del propietario',
                        hintText: 'Ej: noblesse',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    value: tipoVipSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de VIP',
                      prefixIcon: Icon(Icons.workspace_premium),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'prueba', child: Text('Prueba')),
                      DropdownMenuItem(
                          value: 'bronceplus', child: Text('Bronce Plus')),
                      DropdownMenuItem(
                          value: 'plataplus', child: Text('Plata Plus')),
                      DropdownMenuItem(
                          value: 'oroplus', child: Text('Oro Plus')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => tipoVipSeleccionado = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (fecha != null) {
                        setDialogState(() => vipHasta = fecha);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      vipHasta == null
                          ? 'Elegir fecha de expiración'
                          : 'Vence: ${vipHasta!.day}/${vipHasta!.month}/${vipHasta!.year}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!esNegocioPrueba &&
                    propietarioController.text.trim().isEmpty) {
                  return;
                }
                if (vipHasta == null) return;
                Navigator.pop(context, {
                  'propietario': esNegocioPrueba
                      ? '${username}_usuario_test'
                      : propietarioController.text.trim(),
                  'tipoVip': tipoVipSeleccionado,
                  'vipHasta': vipHasta,
                  'esNegocioPrueba': esNegocioPrueba,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reclamar'),
            ),
          ],
        ),
      ),
    );
    if (resultado == null) return;
    try {
      await ApiService.adminCambiarVipStatus(
        adminUsername: username,
        negocioId: negocio['id'],
        accion: 'reclamar',
        tipoVip: resultado['tipoVip'],
        propietarioUsername: resultado['propietario'],
        vipHasta: resultado['vipHasta'],
        esNegocioPrueba: resultado['esNegocioPrueba'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado['esNegocioPrueba'] == true
                  ? '✅ Negocio de prueba creado: ${username}_usuario_test'
                  : '✅ Negocio reclamado manualmente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _activarModoSeleccion() {
    if (_miUbicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espera a que obtenga tu ubicación')),
      );
      return;
    }
    setState(() {
      _modoSeleccion = true;
      _coordenadasSeleccionadas = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toca un punto en el mapa para seleccionar la ubicación'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _cancelarSeleccion() {
    setState(() {
      _modoSeleccion = false;
      _coordenadasSeleccionadas = null;
    });
  }

  Widget _buildMarcadorNormal(IconData iconoGrupo) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.orange, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Icon(iconoGrupo, color: Colors.orange, size: 26),
    );
  }

  Widget _buildMarcadorBronce(IconData iconoGrupo) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFCD7F32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.brown.withOpacity(0.4), blurRadius: 6)
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(iconoGrupo, color: Colors.black87, size: 26),
    );
  }

  Widget _buildMarcadorPlata(IconData iconoGrupo) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFC0C0C0),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.4), blurRadius: 6)
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(iconoGrupo, color: Colors.black87, size: 26),
    );
  }

  Widget _buildMarcadorOro(IconData iconoGrupo) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFD700),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.amber.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(iconoGrupo, color: Colors.black87, size: 28),
    );
  }

  Widget _buildMarcadorPrueba(IconData iconoGrupo) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.purple,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.purple.withOpacity(0.4), blurRadius: 6)
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(iconoGrupo, color: Colors.white, size: 26),
    );
  }

  String? _obtenerTipoVip(Map<String, dynamic> negocio) {
    final esVip = negocio['esVip'] == true;
    if (!esVip) return null;
    final tipoVip = negocio['tipoVip'] as String?;
    if (tipoVip != null && tipoVip.isNotEmpty) {
      return tipoVip.toLowerCase();
    }
    return 'bronce';
  }

  bool _esVipVigente(Map<String, dynamic> negocio) {
    if (negocio['esVip'] != true) return false;
    final raw = negocio['vipHasta'];
    if (raw == null) return true;
    DateTime? fecha;
    if (raw is String) {
      fecha = DateTime.tryParse(raw);
    } else if (raw is Map) {
      final s = raw['_seconds'] ?? raw['seconds'];
      if (s is num) {
        fecha = DateTime.fromMillisecondsSinceEpoch(s.toInt() * 1000);
      }
    } else if (raw is num) {
      fecha = DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000);
    }
    if (fecha == null) return true;
    return fecha.isAfter(DateTime.now());
  }

  double _obtenerTamanoMarcador(String? tipoVip) {
    switch (tipoVip) {
      case 'oro':
      case 'oroplus':
        return 60;
      case 'plata':
      case 'plataplus':
        return 56;
      case 'bronce':
      case 'bronceplus':
        return 52;
      case 'prueba':
        return 52;
      default:
        return 46;
    }
  }

  LinearGradient _obtenerGradienteVip(String? tipoVip) {
    switch (tipoVip) {
      case 'oro':
      case 'oroplus':
        return const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]);
      case 'plata':
      case 'plataplus':
        return const LinearGradient(
            colors: [Color(0xFFC0C0C0), Color(0xFF808080)]);
      case 'bronce':
      case 'bronceplus':
        return const LinearGradient(
            colors: [Color(0xFFCD7F32), Color(0xFF8B4513)]);
      case 'prueba':
        return const LinearGradient(colors: [Colors.purple, Color(0xFF6A1B9A)]);
      default:
        return const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)]);
    }
  }

  String _obtenerTextoVip(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro')) return 'VIP ORO';
    if (t.contains('plata')) return 'VIP PLATA';
    if (t.contains('bronce')) return 'VIP BRONCE';
    if (t.contains('prueba')) return 'VIP PRUEBA';
    return 'VIP';
  }

  IconData _obtenerIconoVip(String tipoVip) {
    if (tipoVip.contains('oro')) return Icons.star;
    if (tipoVip.contains('prueba')) return Icons.bug_report;
    return Icons.workspace_premium;
  }

  Color _colorTextoVip(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro') || t.contains('plata') || t.contains('bronce')) {
      return Colors.black87;
    }
    return Colors.white;
  }

  Color _colorVip(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro')) return const Color(0xFFFFD700);
    if (t.contains('plata')) return const Color(0xFFC0C0C0);
    if (t.contains('bronce')) return const Color(0xFFCD7F32);
    if (t.contains('prueba')) return Colors.purple;
    return Colors.orange;
  }

  Color _obtenerColorBadgeSolido(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro')) return const Color(0xFF8B6914);
    if (t.contains('plata')) return const Color(0xFF4A4A4A);
    if (t.contains('bronce')) return const Color(0xFF6B3410);
    if (t.contains('prueba')) return const Color(0xFF6A1B9A);
    return const Color(0xFFE65100);
  }

  Future<String> _obtenerPreviewComentario(String negocioId) async {
    try {
      final comentarios = await ApiService.getComentarios(negocioId);
      if (comentarios.isNotEmpty) {
        final ultimo = comentarios.first;
        final texto = (ultimo['texto'] ?? '').toString();
        final autor = (ultimo['autor'] ?? 'Anónimo').toString();
        final limpio = texto.replaceAll('\n', ' ').trim();
        return '$autor: $limpio';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  void _compartirNegocio(Map<String, dynamic> negocio) {
    final id = negocio['id'] as String;
    final nombre = negocio['nombre'] ?? 'Negocio';
    final esVip = negocio['esVip'] == true;
    final shareUrl = esVip
        ? 'https://fatestudiosgame.github.io/tranqui-web/p/$id/'
        : 'https://fatestudiosgame.github.io/tranqui-web/negocio/?id=$id';
    CompartirService.mostrar(
      context: context,
      nombre: nombre,
      url: shareUrl,
    );
  }

  void _mostrarPopupNegocio(
      BuildContext context, Map<String, dynamic> negocio) {
    final nombre = negocio['nombre'] as String? ?? 'Negocio local';
    final desc = negocio['descripcion'] ?? '';
    final horario = negocio['horario'] ?? '';
    final id = negocio['id'] as String;
    final tipoVip = _obtenerTipoVip(negocio);
    final esVip = tipoVip != null;
    final categoriaId = negocio['categoriaPrincipal'] as String?;
    final categoria = buscarCategoriaPorId(categoriaId);
    final grupo = buscarGrupoDeCategoria(categoriaId);
    final fotos = (negocio['fotos'] as List?)?.cast<String>() ?? [];
    final whatsapp = negocio['whatsapp'] as String?;
    final descVip = negocio['descripcionVip'] as String? ?? '';
    final promedio = (negocio['promedioPuntuacion'] as num?)?.toDouble();
    final totalVotos = negocio['totalPuntuaciones'] as int? ?? 0;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (esVip && tipoVip != null)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _obtenerColorBadgeSolido(tipoVip),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _obtenerIconoVip(tipoVip),
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _obtenerTextoVip(tipoVip),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (esVip && tipoVip != null)
                          const SizedBox(height: 10),
                        Row(
                          children: [
                            AvatarRotadorFotos(
                              fotos: fotos,
                              fallbackIcon: categoria != null
                                  ? obtenerIcono(categoria.icono)
                                  : Icons.store,
                              fallbackColor:
                                  esVip ? _colorVip(tipoVip) : Colors.orange,
                              onTap: fotos.isNotEmpty
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VisorFotosFullScreen(
                                              fotos: fotos),
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (categoria != null && grupo != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: obtenerColorGrupo(grupo.colorHex)
                              .withOpacity(0.1),
                          border: Border.all(
                            color: obtenerColorGrupo(grupo.colorHex),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              obtenerIcono(categoria.icono),
                              size: 12,
                              color: obtenerColorGrupo(grupo.colorHex),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              categoria.nombre,
                              style: TextStyle(
                                color: obtenerColorGrupo(grupo.colorHex),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (promedio != null && totalVotos > 0) ...[
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              (index + 1) <= promedio.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.orange,
                              size: 20,
                            );
                          }),
                          const SizedBox(width: 6),
                          Text(
                            promedio.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            ' ($totalVotos)',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (negocio['propietarioUsername'] != null &&
                        negocio['propietarioUsername']
                            .toString()
                            .isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: negocio['esNegocioPrueba'] == true
                              ? Colors.orange.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: negocio['esNegocioPrueba'] == true
                                ? Colors.orange.shade200
                                : Colors.blue.shade100,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              negocio['esNegocioPrueba'] == true
                                  ? Icons.bug_report
                                  : Icons.person,
                              size: 14,
                              color: negocio['esNegocioPrueba'] == true
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                negocio['esNegocioPrueba'] == true
                                    ? 'Negocio de prueba'
                                    : 'Propietario: @${negocio['propietarioUsername']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: negocio['esNegocioPrueba'] == true
                                      ? Colors.orange.shade700
                                      : Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (esVip && descVip.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _obtenerGradienteVip(tipoVip!)
                              .colors
                              .first
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _obtenerGradienteVip(tipoVip)
                                .colors
                                .first
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.star,
                              color: _obtenerGradienteVip(tipoVip).colors.first,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                descVip,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _obtenerGradienteVip(tipoVip)
                                      .colors
                                      .first,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (desc.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (desc.isNotEmpty && !(esVip && descVip.isNotEmpty))
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    if (horario.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              horario,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconoAccion(
                          icon: Icons.share,
                          tooltip: 'Compartir',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.pop(context);
                            _compartirNegocio(negocio);
                          },
                        ),
                        if (esVip && whatsapp != null && whatsapp.isNotEmpty)
                          _buildIconoAccion(
                            icon: Icons.chat,
                            tooltip: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            onTap: () {
                              Navigator.pop(context);
                              _abrirWhatsApp(whatsapp);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<String>(
                      future: _obtenerPreviewComentario(id),
                      builder: (context, snapshot) {
                        final preview = snapshot.data;
                        final tieneComentario =
                            preview != null && preview.isNotEmpty;
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ComentariosScreen(
                                    negocioId: id,
                                    negocioNombre: nombre,
                                  ),
                                ),
                              );
                              if (mounted) {
                                await _cargarNegocios();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade50,
                              foregroundColor: Colors.orange.shade800,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.orange.shade200),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.comment,
                                    size: 18, color: Colors.orange.shade800),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tieneComentario
                                        ? preview!
                                        : 'Agregar comentario',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: tieneComentario
                                          ? FontStyle.normal
                                          : FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (esVip)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CatalogoNegocio(
                                  negocioId: id,
                                  negocioNombre: nombre,
                                  propietarioUsername:
                                      negocio['propietarioUsername'],
                                  esVip: esVip,
                                  tipoVip: tipoVip,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu_book, size: 20),
                          label: const Text('Ver Catálogo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _obtenerGradienteVip(tipoVip!).colors.first,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    if (!esVip)
                      FutureBuilder<bool>(
                        future: _verificarSiEsVip(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const SizedBox.shrink();
                          }
                          final usuarioEsVip = snapshot.data ?? false;
                          if (!usuarioEsVip) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _reclamarNegocioDesdeMapa(negocio);
                                },
                                icon: const Icon(Icons.add_business, size: 18),
                                label: const Text('Reclamar este negocio'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -14,
              right: -14,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconoAccion({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Future<void> _reclamarNegocioDesdeMapa(Map<String, dynamic> negocio) async {
    final esVip = await _verificarSiEsVip();
    if (!esVip) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  '⚠️ Debes tener una licencia VIP para reclamar negocios'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    final tipoPlan = prefs.getString('vip_tipo_plan') ?? 'VIP';
    final fechaExpStr = prefs.getString('vip_fecha_expiracion');
    final limite = _obtenerLimitePorPlan(tipoPlan);
    if (fechaExpStr == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  '❌ No se encontró la fecha de expiración de tu licencia'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }
    final fechaExpiracion = DateTime.tryParse(fechaExpStr);
    if (fechaExpiracion == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('❌ Error al procesar la fecha de expiración'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }
    final misNegociosCount = negocios.where((n) {
      return n['esVip'] == true && n['propietarioUsername'] == username;
    }).length;
    if (misNegociosCount >= limite) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⚠️ Alcanzaste el límite de $limite negocio(s) VIP para el plan $tipoPlan'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Reclamar este negocio?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              negocio['nombre'] ?? 'Negocio sin nombre',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esto marcará el negocio como tuyo y aparecerá destacado en el mapa.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus negocios: $misNegociosCount/$limite',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reclamar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ApiService.reclamarNegocio(
        negocioId: negocio['id'],
        username: username,
        tipoVip: tipoPlan,
        vipHasta: fechaExpiracion,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Negocio "${negocio['nombre']}" reclamado como VIP $tipoPlan'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
      }
    } catch (e) {
      if (mounted) {
        String mensaje = '❌ Error al reclamar: $e';
        Color color = Colors.red;
        if (e.toString().contains('ya fue reclamado')) {
          mensaje = '⚠️ Este negocio ya fue reclamado por otro usuario';
          color = Colors.orange;
          await _cargarNegocios();
        } else if (e.toString().contains('límite')) {
          mensaje = '⚠️ Has alcanzado el límite de negocios para tu plan';
          color = Colors.orange;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: color,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  int _obtenerLimitePorPlan(String tipoPlan) {
    final t = tipoPlan.toLowerCase();
    if (t.contains('oro')) return 5;
    if (t.contains('plata')) return 3;
    if (t.contains('bronce')) return 1;
    if (t.contains('prueba')) return 1;
    return 1;
  }

  Future<void> _obtenerUbicacion() async {
    if (_obteniendoUbicacion) return;
    _obteniendoUbicacion = true;
    try {
      if (kIsWeb) {
        await _obtenerUbicacionWeb();
      } else {
        await _obtenerUbicacionMovil();
      }
    } catch (e) {
      _usarUbicacionPorDefecto('Error inesperado: $e');
    } finally {
      _obteniendoUbicacion = false;
    }
  }

  Future<void> _obtenerUbicacionWeb() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _usarUbicacionPorDefecto('Servicio no habilitado en navegador');
        return;
      }
    } catch (e) {
      _usarUbicacionPorDefecto('Error verificando servicio');
      return;
    }
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (e) {
      _usarUbicacionPorDefecto('Error verificando permisos');
      return;
    }
    if (permission == LocationPermission.denied) {
      try {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _usarUbicacionPorDefecto('Permiso denegado por el usuario');
          return;
        }
      } catch (e) {
        _usarUbicacionPorDefecto('Error al solicitar permiso');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _usarUbicacionPorDefecto('Permiso denegado permanentemente');
      return;
    }
    try {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        if (mounted) {
          setState(() {
            _miUbicacion =
                LatLng(lastPosition.latitude, lastPosition.longitude);
          });
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _moverMapaSeguro(_miUbicacion!, 15.0);
          }
        }
        return;
      }
    } catch (e) {
      // continuar
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('Timeout al obtener ubicación web');
        },
      );
      if (mounted) {
        setState(() {
          _miUbicacion = LatLng(position.latitude, position.longitude);
        });
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _moverMapaSeguro(_miUbicacion!, 15.0);
        }
      }
    } catch (e) {
      _usarUbicacionPorDefecto(e.toString());
    }
  }

  void _usarUbicacionPorDefecto(String razon) {
    if (mounted) {
      setState(() {
        _miUbicacion = const LatLng(23.1136, -82.3666);
      });
    }
  }

  Future<void> _obtenerUbicacionMovil() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      _usarUbicacionPorDefecto('GPS deshabilitado');
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _usarUbicacionPorDefecto('Permiso denegado');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _usarUbicacionPorDefecto('Permiso denegado permanentemente');
      return;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _miUbicacion = LatLng(position.latitude, position.longitude);
        });
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _moverMapaSeguro(_miUbicacion!, 15.0);
        }
      }
    } catch (e) {
      _usarUbicacionPorDefecto(e.toString());
    }
  }

  void _abrirListaNegocios() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListaNegocios(
          onNegocioSeleccionado: _centrarEnNegocio,
        ),
      ),
    );
  }

  void _abrirPantallaVip() async {
    Navigator.pop(context);
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PantallaVip()),
    );
    if (resultado is LatLng && mounted) {
      _centrarEnNegocio(resultado);
    } else if (resultado == true && mounted) {
      await _cargarNegocios();
    }
  }

  Future<bool> _verificarSiEsVip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final licencia = prefs.getString('vip_licencia');
      final fechaExpStr = prefs.getString('vip_fecha_expiracion');
      if (licencia == null || fechaExpStr == null) return false;
      final fechaExp = DateTime.tryParse(fechaExpStr);
      if (fechaExp == null) return false;
      return fechaExp.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Future<bool> _verificarSiEsAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('vip_username');
      if (username == null || username.isEmpty) return false;
      return await ApiService.verificarEsAdmin(username);
    } catch (e) {
      return false;
    }
  }

  void _abrirPanelAdmin() async {
    Navigator.pop(context);
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('vip_username') ?? '';
    if (username.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Debes tener una licencia VIP activa'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminPanel(adminUsername: username),
        ),
      );
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.store, color: Colors.orange, size: 36),
                ),
                const SizedBox(height: 12),
                const Text(
                  'TRANQUILÍZATE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _sloganActual,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _abrirListaNegocios();
                          },
                          icon:
                              const Icon(Icons.format_list_bulleted, size: 20),
                          label: const Text('Ver listado de negocios'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      FutureBuilder<bool>(
                        future: _verificarSiEsVip(),
                        builder: (context, snapshot) {
                          final esVip = snapshot.data ?? false;
                          return SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _abrirPantallaVip,
                              icon: Icon(
                                  esVip
                                      ? Icons.business
                                      : Icons.workspace_premium,
                                  size: 18),
                              label: Text(esVip
                                  ? 'Mis Negocios VIP'
                                  : 'Hacer VIP mi negocio'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade800,
                                side: BorderSide(color: Colors.orange.shade400),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                FutureBuilder<bool>(
                  future: _verificarSiEsAdmin(),
                  builder: (context, snapshot) {
                    final esAdmin = snapshot.data ?? false;
                    if (!esAdmin) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ElevatedButton.icon(
                        onPressed: _abrirPanelAdmin,
                        icon: const Icon(Icons.admin_panel_settings, size: 18),
                        label: const Text('Panel Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                _buildDrawerSectionTitle('Acciones'),
                ListTile(
                  leading: const Icon(Icons.autorenew, color: Colors.orange),
                  title: const Text('Limpiar caché y recargar'),
                  subtitle: const Text(
                    'Datos y mapas guardados',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _limpiarCacheYRecargar();
                  },
                ),
                const Divider(),
                _buildDrawerSectionTitle('Contacto'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '¿Tienes sugerencias, ideas o alguna propuesta? Escríbenos, nos encanta escucharte.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.support_agent, color: Colors.orange),
                  title: const Text('Contacta a los desarrolladores'),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirWhatsAppContacto();
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  const Text(
                    'fatestudiosgame',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '© ${DateTime.now().year} Todos los derechos reservados',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                  if (_appVersion.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'v$_appVersion',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTrianguloBotones() {
    final hayFiltroActivo =
        _grupoSeleccionado != null && _grupoSeleccionado != 'todos';
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            right: 76,
            bottom: 80,
            child: FloatingActionButton(
              heroTag: 'btnFiltro',
              onPressed: _mostrarFiltroCategorias,
              backgroundColor: hayFiltroActivo
                  ? obtenerColorGrupo(gruposCategorias
                      .firstWhere(
                        (g) => g.id == _grupoSeleccionado,
                        orElse: () => gruposCategorias.first,
                      )
                      .colorHex)
                  : Colors.orange,
              foregroundColor: Colors.white,
              mini: true,
              tooltip: hayFiltroActivo
                  ? 'Filtro: ${_obtenerNombreGrupoActivo()}'
                  : 'Filtrar por categoría',
              child: Icon(
                hayFiltroActivo
                    ? obtenerIcono(gruposCategorias
                        .firstWhere(
                          (g) => g.id == _grupoSeleccionado,
                          orElse: () => gruposCategorias.first,
                        )
                        .icono)
                    : Icons.filter_list,
                size: 22,
              ),
            ),
          ),
          Positioned(
            right: 88,
            bottom: 8,
            child: FloatingActionButton(
              heroTag: 'btnAgregar',
              onPressed: _activarModoSeleccion,
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              tooltip: 'Agregar negocio (seleccionar ubicación)',
              child: const Icon(Icons.add_location),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 8,
            child: FloatingActionButton(
              heroTag: 'btnUbicacion',
              onPressed: _obtenerUbicacion,
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              tooltip: 'Mi ubicación',
              child: const Icon(Icons.gps_fixed),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight =
        AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
    final negociosAMostrar = negociosFiltrados;
    final Widget tituloAppBar;
    if (_modoSeleccion) {
      tituloAppBar = const Text('Selecciona ubicación');
    } else if (_mostrandoContador) {
      tituloAppBar = Text(
        _cargando
            ? 'Cargando...'
            : 'Hay ${negociosAMostrar.length} negocios disponibles',
        style: const TextStyle(fontSize: 15),
        overflow: TextOverflow.ellipsis,
      );
    } else {
      tituloAppBar = const Text('TRANQUILÍZATE');
    }
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _modoSeleccion
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                tooltip: 'Menú',
              ),
        title: tituloAppBar,
        backgroundColor:
            _modoSeleccion ? Colors.orange.shade800 : Colors.orange,
        foregroundColor: Colors.white,
        actions: _modoSeleccion
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _cancelarSeleccion,
                  tooltip: 'Cancelar',
                ),
              ]
            : null,
      ),
      drawer: _buildDrawer(),
      onDrawerChanged: (isOpen) {
        if (isOpen) {
          setState(() {
            _sloganActual = _slogans[Random().nextInt(_slogans.length)];
          });
        }
      },
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _miUbicacion ?? const LatLng(23.1136, -82.3666),
              initialZoom: _miUbicacion != null ? 14.0 : 10.0,
              onTap: _onMapTap,
              onLongPress: _onMapLongPress,
              // ⭐ FIX: Zoom consistente con TileLayer
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              // ⭐ FIX: Limitar el rango de coordenadas para evitar NaN/Infinity
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  LatLng(_minLat, _minLon),
                  LatLng(_maxLat, _maxLon),
                ),
              ),
            ),
            children: [
              if (_cacheInicializado && _mapCacheStore != null)
                TileLayer(
                  tileProvider: CachedTileProvider(
                    store: _mapCacheStore!,
                    maxStale: const Duration(days: 30),
                  ),
                  urlTemplate:
                      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=cb1_2djt_1_2314ecd586b7898a72a20685',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.fatestudiosgame.tranqui',
                  retinaMode: false,
                  // ⭐ FIX: minZoom consistente con MapOptions
                  maxNativeZoom: 18,
                  maxZoom: 18,
                  minZoom: 5,
                  panBuffer: 0,
                )
              else
                TileLayer(
                  tileProvider: NetworkTileProvider(),
                  urlTemplate:
                      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=cb1_2djt_1_2314ecd586b7898a72a20685',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.fatestudiosgame.tranqui',
                  retinaMode: false,
                  // ⭐ FIX: minZoom consistente con MapOptions
                  maxNativeZoom: 18,
                  maxZoom: 18,
                  minZoom: 5,
                  panBuffer: 0,
                ),
              if (_miUbicacion != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: _miUbicacion!,
                      alignment: Alignment.center,
                      child: const Icon(Icons.my_location,
                          color: Colors.blue, size: 40),
                    ),
                  ],
                ),
              if (_coordenadasSeleccionadas != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: _coordenadasSeleccionadas!,
                      alignment: Alignment.center,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
              if (negociosAMostrar.isNotEmpty)
                Builder(
                  builder: (mapContext) {
                    LatLngBounds? visibleBounds;
                    try {
                      final camera = MapCamera.of(mapContext);
                      visibleBounds = camera.visibleBounds;
                    } catch (e) {
                      visibleBounds = null;
                    }
                    List<Map<String, dynamic>> negociosVisibles;
                    if (visibleBounds != null) {
                      final bounds = visibleBounds;
                      negociosVisibles = negociosAMostrar.where((negocio) {
                        final lat = negocio['latitud'] as double?;
                        final lon = negocio['longitud'] as double?;
                        // ⭐ FIX: Validar coordenadas antes de usarlas
                        if (lat == null ||
                            lon == null ||
                            !lat.isFinite ||
                            !lon.isFinite) {
                          return false;
                        }
                        return bounds.contains(LatLng(lat, lon));
                      }).toList();
                    } else {
                      negociosVisibles = negociosAMostrar;
                    }
                    final marcadoresAMostrar =
                        negociosVisibles.take(50).toList();
                    return MarkerLayer(
                      markers: marcadoresAMostrar.map((negocio) {
                        final lat = negocio['latitud'] as double;
                        final lon = negocio['longitud'] as double;
                        final categoriaId =
                            negocio['categoriaPrincipal'] as String?;
                        final iconoGrupo =
                            _obtenerIconoPorCategoria(categoriaId);
                        final tipoVip = _obtenerTipoVip(negocio);
                        final tamano = _obtenerTamanoMarcador(tipoVip);
                        Widget marcador;
                        switch (tipoVip) {
                          case 'oro':
                          case 'oroplus':
                            marcador = _buildMarcadorOro(iconoGrupo);
                            break;
                          case 'plata':
                          case 'plataplus':
                            marcador = _buildMarcadorPlata(iconoGrupo);
                            break;
                          case 'bronce':
                          case 'bronceplus':
                            marcador = _buildMarcadorBronce(iconoGrupo);
                            break;
                          case 'prueba':
                            marcador = _buildMarcadorPrueba(iconoGrupo);
                            break;
                          default:
                            marcador = _buildMarcadorNormal(iconoGrupo);
                        }
                        return Marker(
                          key: ValueKey(negocio['id']),
                          width: tamano,
                          height: tamano,
                          point: LatLng(lat, lon),
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () async {
                              if (_esVipVigente(negocio)) {
                                final resultado = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaginaNegocio(
                                      negocioId: negocio['id'] as String,
                                    ),
                                  ),
                                );
                                // ⭐ FIX: Validar resultado antes de mover el mapa
                                if (resultado is LatLng && mounted) {
                                  _centrarEnNegocio(resultado);
                                } else if (resultado == true && mounted) {
                                  await _cargarNegocios();
                                }
                              } else {
                                _mostrarPopupNegocio(context, negocio);
                              }
                            },
                            onLongPress: () =>
                                _manejarLongPressMarcador(context, negocio),
                            child: marcador,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
          Positioned(
            top: appBarHeight + 6,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const BannerWidget(),
                if (_actualizandoEnSegundoPlano)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Actualizando negocios...',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_cargando && negocios.isEmpty && !_error)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.orange.shade300),
                            ),
                          ),
                          const Icon(Icons.cloud_outlined,
                              color: Colors.white, size: 36),
                        ],
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _pulseAnimation,
                        child: const Text(
                          '☕ Despertando servidor...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'La primera vez puede tardar hasta 1 minuto',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_error && negocios.isEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 30),
                    const SizedBox(height: 8),
                    const Text(
                      'Sin conexión al servidor',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      negocios.isEmpty
                          ? 'No hay datos guardados. Conéctate a internet para cargar los negocios.'
                          : 'Mostrando datos guardados localmente. Conéctate para actualizar.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _cargarNegocios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_modoSeleccion) _buildTrianguloBotones(),
        ],
      ),
    );
  }
}
