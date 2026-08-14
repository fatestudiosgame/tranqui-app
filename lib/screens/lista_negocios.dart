import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class ListaNegocios extends StatefulWidget {
  final void Function(LatLng) onNegocioSeleccionado;

  const ListaNegocios({super.key, required this.onNegocioSeleccionado});

  @override
  State<ListaNegocios> createState() => _ListaNegociosState();
}

class _ListaNegociosState extends State<ListaNegocios> {
  List<Map<String, dynamic>> negocios = [];
  bool cargando = true;
  bool error = false;

  // ⭐ Map para almacenar los grupos: municipio -> lista de negocios
  Map<String, List<Map<String, dynamic>>> grupos = {};

  @override
  void initState() {
    super.initState();
    _cargarNegocios();
  }

  Future<void> _cargarNegocios() async {
    setState(() {
      cargando = true;
      error = false;
    });

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final data = await ApiService.getNegocios();
        setState(() {
          negocios = data;
          cargando = false;
          _agruparPorMunicipio(data);
        });
        await LocalStorageService.guardarNegocios(data);
        return;
      } catch (e) {
        print('Error cargando desde servidor: $e');
      }
    }

    // Fallback a datos locales
    final datosLocales = LocalStorageService.obtenerNegocios();
    if (datosLocales.isNotEmpty) {
      setState(() {
        negocios = List<Map<String, dynamic>>.from(datosLocales);
        cargando = false;
        _agruparPorMunicipio(datosLocales);
      });
    } else {
      setState(() {
        error = true;
        cargando = false;
      });
    }
  }

  // ⭐ Función para agrupar negocios por municipio
  void _agruparPorMunicipio(List<dynamic> lista) {
    final Map<String, List<Map<String, dynamic>>> temp = {};

    for (var negocio in lista) {
      final municipio = (negocio['municipio'] as String? ?? 'Otros').trim();
      if (municipio.isEmpty) {
        temp.putIfAbsent('Otros', () => []).add(negocio);
      } else {
        temp.putIfAbsent(municipio, () => []).add(negocio);
      }
    }

    // Ordenar los municipios alfabéticamente (excepto "Otros" al final)
    final keys = temp.keys.toList()
      ..sort((a, b) {
        if (a == 'Otros') return 1;
        if (b == 'Otros') return -1;
        return a.compareTo(b);
      });

    final ordenado = <String, List<Map<String, dynamic>>>{};
    for (var key in keys) {
      ordenado[key] = temp[key]!;
    }

    setState(() {
      grupos = ordenado;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Negocios'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarNegocios,
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('No hay negocios guardados'),
                      const SizedBox(height: 8),
                      const Text('Conéctate a internet para cargar los datos'),
                      const SizedBox(height: 16),
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
                )
              : negocios.isEmpty
                  ? const Center(child: Text('No hay negocios registrados'))
                  : _buildListaAgrupada(),
    );
  }

  // ⭐ Widget que construye la lista agrupada
  Widget _buildListaAgrupada() {
    final keys = grupos.keys.toList();

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final municipio = keys[index];
        final items = grupos[municipio]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ENCABEZADO DEL MUNICIPIO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.location_city,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    municipio,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} ${items.length == 1 ? 'negocio' : 'negocios'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // ⭐ CORREGIDO: eliminado 'const'
            Divider(height: 0, thickness: 1, color: Colors.grey.shade300),

            // --- NEGOCIOS DE ESTE MUNICIPIO ---
            ...items.map((negocio) {
              final nombre = negocio['nombre'] ?? 'Negocio local';
              final desc = negocio['descripcion'] ?? '';
              final horario = negocio['horario'] ?? '';
              final lat = negocio['latitud'] as double;
              final lon = negocio['longitud'] as double;

              return ListTile(
                title: Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desc.isNotEmpty) ...[
                      // ⭐ CORREGIDO: eliminado 'const'
                      Divider(color: Colors.grey, thickness: 1, height: 8),
                      Text(desc, style: const TextStyle(fontSize: 12)),
                    ],
                    if (horario.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('🕐 $horario', style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '📍 ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                leading: const Icon(Icons.store, color: Colors.orange),
                onTap: () {
                  widget.onNegocioSeleccionado(LatLng(lat, lon));
                  Navigator.pop(context);
                },
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              );
            }).toList(),

            // ⭐ CORREGIDO: eliminado 'const' (no afecta rendimiento)
            const SizedBox(height: 8),
            Divider(height: 16, thickness: 2, color: Colors.grey.shade200),
          ],
        );
      },
    );
  }
}
