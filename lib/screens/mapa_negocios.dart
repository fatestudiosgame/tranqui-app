import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/banner_widget.dart';
import 'lista_negocios.dart';
import 'comentarios_screen.dart';

class MapaNegocios extends StatefulWidget {
  const MapaNegocios({super.key});

  @override
  State<MapaNegocios> createState() => _MapaNegociosState();
}

class _MapaNegociosState extends State<MapaNegocios> {
  LatLng? _miUbicacion;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> negocios = [];
  bool _cargando = true;
  bool _error = false;
  bool _sincronizando = false;
  bool _modoOffline = false;
  bool _modoSeleccion = false;
  LatLng? _coordenadasSeleccionadas;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _obtenerUbicacion();
    } else {
      _miUbicacion = const LatLng(23.1136, -82.3666);
    }
    _cargarNegocios();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _cargarNegocios() async {
    setState(() {
      _cargando = true;
      _error = false;
      _sincronizando = true;
    });

    List<dynamic> datosLocales = [];
    try {
      datosLocales = LocalStorageService.obtenerNegocios();
      if (datosLocales.isNotEmpty) {
        setState(() {
          negocios = List<Map<String, dynamic>>.from(datosLocales);
          _cargando = false;
        });
        print('📦 Cargados ${negocios.length} negocios desde caché local');
      } else {
        print('⚠️ No hay datos locales guardados');
      }
    } catch (e) {
      await LocalStorageService.limpiarCache();
      datosLocales = [];
      print('❌ Error cargando caché: $e');
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
      if (datosLocales.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📶 Modo offline - Mostrando datos guardados'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _sincronizando = true;
    });

    try {
      final data = await ApiService.getNegocios();
      print('📡 Servidor devolvió ${data.length} negocios');
      setState(() {
        negocios = data;
        _cargando = false;
        _error = false;
        _sincronizando = false;
        _modoOffline = false;
      });
      await LocalStorageService.guardarNegocios(data);
      print('✅ Actualizados ${data.length} negocios desde el servidor');
    } catch (e) {
      print('❌ Error cargando desde servidor: $e');
      if (negocios.isEmpty) {
        setState(() {
          _error = true;
          _cargando = false;
          _sincronizando = false;
        });
      } else {
        setState(() {
          _cargando = false;
          _sincronizando = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠️ No se pudo sincronizar: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _centrarEnNegocio(LatLng punto) {
    _mapController.move(punto, 16.0);
  }

  Future<void> _mostrarFormularioNegocio(LatLng coordenadas) async {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    final municipioController = TextEditingController();

    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Negocio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Ej: Aceptan Transfermóvil, EnZona...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: municipioController,
              decoration: const InputDecoration(
                labelText: 'Municipio',
                hintText: 'Ej: Playa, Vedado, Centro Habana...',
              ),
            ),
          ],
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
              Navigator.pop(context, {
                'nombre': nombre,
                'descripcion': descripcionController.text.trim(),
                'municipio': municipioController.text.trim(),
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
    );

    if (resultado != null) {
      try {
        await ApiService.agregarNegocio(
          nombre: resultado['nombre']!,
          latitud: coordenadas.latitude,
          longitud: coordenadas.longitude,
          descripcion: resultado['descripcion'],
          municipio: resultado['municipio'],
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

  // ⭐ POPUP CON ESTRELLAS Y BOTÓN COMENTARIOS MEJORADO
  void _mostrarPopupNegocio(
      BuildContext context, Map<String, dynamic> negocio) {
    final nombre = negocio['nombre'] as String? ?? 'Negocio local';
    final desc = negocio['descripcion'] ?? '';
    final horario = negocio['horario'] ?? '';
    final id = negocio['id'] as String;

    final promedio = (negocio['promedioPuntuacion'] as num?)?.toDouble();
    final totalVotos = negocio['totalPuntuaciones'] as int? ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (promedio != null && totalVotos > 0) ...[
              Row(
                children: [
                  ...List.generate(5, (index) {
                    final starIndex = index + 1;
                    final isFull = starIndex <= promedio.round();
                    return Icon(
                      isFull ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                      size: 22,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    promedio.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    ' ($totalVotos ${totalVotos == 1 ? 'voto' : 'votos'})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (desc.isNotEmpty) ...[
              const Divider(color: Colors.grey, thickness: 1),
              const SizedBox(height: 6),
              Text(desc),
            ],
            if (horario.isNotEmpty) ...[
              if (desc.isNotEmpty) const SizedBox(height: 8),
              Text('🕐 $horario'),
            ],
          ],
        ),
        actions: [
          // ⭐ BOTÓN COMENTARIOS CON RECARGA AUTOMÁTICA AL VOLVER
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context); // Cerrar popup
              // Navegar a comentarios y esperar a que el usuario regrese
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ComentariosScreen(
                    negocioId: id,
                    negocioNombre: nombre,
                  ),
                ),
              );
              // ⭐ RECARGAR NEGOCIOS AL VOLVER DE COMENTARIOS
              if (mounted) {
                await _cargarNegocios();
              }
            },
            icon: const Icon(Icons.comment),
            label: const Text('Comentarios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _limpiarCache() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar caché'),
        content: const Text(
            '¿Seguro que quieres eliminar todos los datos guardados localmente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await LocalStorageService.limpiarCache();
              setState(() {
                negocios = [];
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Caché limpiada correctamente')),
              );
              await _cargarNegocios();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _obtenerUbicacion() async {
    if (kIsWeb) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Necesito el GPS para funcionar')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso denegado permanentemente')),
      );
      return;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _miUbicacion = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_miUbicacion!, 15.0);
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight =
        AppBar().preferredSize.height + MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        title: _modoSeleccion
            ? const Text('Selecciona ubicación')
            : const Text('TRANQUILÍZATE'),
        backgroundColor:
            _modoSeleccion ? Colors.orange.shade800 : Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (_modoSeleccion)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelarSeleccion,
              tooltip: 'Cancelar',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarNegocios,
            tooltip: 'Recargar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _limpiarCache,
            tooltip: 'Limpiar caché',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListaNegocios(
                    onNegocioSeleccionado: _centrarEnNegocio,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _miUbicacion ?? const LatLng(23.1136, -82.3666),
              initialZoom: _miUbicacion != null ? 15.0 : 12.0,
              onTap: _onMapTap,
              onLongPress: _onMapLongPress,
            ),
            children: [
              TileLayer(
                tileProvider: NetworkTileProvider(),
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.fatestudiosgame.tranqui',
                retinaMode: RetinaMode.isHighDensity(context),
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
              if (negocios.isNotEmpty)
                MarkerLayer(
                  markers: negocios.map((negocio) {
                    final lat = negocio['latitud'] as double;
                    final lon = negocio['longitud'] as double;
                    return Marker(
                      key: ValueKey(negocio['id']),
                      width: 50,
                      height: 50,
                      point: LatLng(lat, lon),
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => _mostrarPopupNegocio(context, negocio),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.store,
                              color: Colors.orange, size: 30),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // BANNER PROMOCIONAL
          Positioned(
            top: appBarHeight + 6,
            left: 0,
            right: 0,
            child: const BannerWidget(),
          ),

          // --- CONTADOR Y ESTADO ---
          Positioned(
            top: appBarHeight + 76,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _cargando ? 'Cargando...' : 'Negocios: ${negocios.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_sincronizando && !_cargando && negocios.isNotEmpty)
                    const Text('Sincronizando...',
                        style: TextStyle(color: Colors.amber, fontSize: 12)),
                  if (_modoSeleccion)
                    const Text('Modo selección',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                  if (_modoOffline && !_cargando && negocios.isNotEmpty)
                    const Text('📶 Offline',
                        style: TextStyle(color: Colors.blue, fontSize: 12)),
                ],
              ),
            ),
          ),

          // --- ERROR DE CONEXIÓN ---
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
        ],
      ),
      floatingActionButton: _modoSeleccion
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _activarModoSeleccion,
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  tooltip: 'Agregar negocio (seleccionar ubicación)',
                  child: const Icon(Icons.add_location),
                  heroTag: null,
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _obtenerUbicacion,
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.gps_fixed),
                  heroTag: null,
                ),
              ],
            ),
    );
  }
}
