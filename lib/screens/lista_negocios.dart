import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../data/categorias.dart';

class ListaNegocios extends StatefulWidget {
  final Function(LatLng) onNegocioSeleccionado;

  const ListaNegocios({
    super.key,
    required this.onNegocioSeleccionado,
  });

  @override
  State<ListaNegocios> createState() => _ListaNegociosState();
}

class _ListaNegociosState extends State<ListaNegocios> {
  List<Map<String, dynamic>> negocios = [];
  List<Map<String, dynamic>> negociosFiltrados = [];
  bool _cargando = true;
  String _busqueda = '';
  final TextEditingController _searchController = TextEditingController();

  // Filtro por grupo de categoría
  String? _grupoFiltro;

  // ⭐ NUEVO: ordenamiento (true = recientes, false = alfabético)
  bool _ordenReciente = true;

  @override
  void initState() {
    super.initState();
    _cargarNegocios();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarNegocios() async {
    setState(() {
      _cargando = true;
    });

    try {
      List<dynamic> datosLocales = [];
      try {
        datosLocales = await LocalStorageService.obtenerNegocios();
        if (datosLocales.isNotEmpty) {
          setState(() {
            negocios =
                datosLocales.map((e) => Map<String, dynamic>.from(e)).toList();
            negociosFiltrados = negocios;
            _cargando = false;
          });
        }
      } catch (e) {
        print('⚠️ Error cargando caché: $e');
      }

      final data = await ApiService.getNegocios();
      if (mounted) {
        setState(() {
          negocios = data;
          _filtrarNegocios();
          _cargando = false;
        });
      }
      await LocalStorageService.guardarNegocios(data);
    } catch (e) {
      print('❌ Error cargando negocios: $e');
      if (mounted) {
        setState(() {
          _cargando = false;
        });
        if (negocios.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No se pudieron cargar los negocios'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  // ⭐ Helper: extrae timestamp de un negocio (maneja varios formatos de Firestore)
  DateTime? _obtenerTimestamp(Map<String, dynamic> negocio) {
    // Intentar varios nombres de campo comunes
    final campos = [
      'creadoEn',
      'fechaCreacion',
      'createdAt',
      'timestamp',
      'fecha'
    ];
    for (final campo in campos) {
      final valor = negocio[campo];
      if (valor == null) continue;

      if (valor is String) {
        final parsed = DateTime.tryParse(valor);
        if (parsed != null) return parsed;
      } else if (valor is Map) {
        // Formato Firestore Timestamp: {_seconds: 1234567890, _nanoseconds: ...}
        final seconds = valor['_seconds'] ?? valor['seconds'];
        if (seconds is num) {
          return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
        }
      } else if (valor is num) {
        // Timestamp directo en milisegundos o segundos
        if (valor > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(valor.toInt());
        } else {
          return DateTime.fromMillisecondsSinceEpoch(valor.toInt() * 1000);
        }
      }
    }
    return null;
  }

  // Aplica búsqueda + filtro por grupo + orden VIP + orden elegido
  void _filtrarNegocios() {
    setState(() {
      // 1. Filtrar por búsqueda de texto
      List<Map<String, dynamic>> resultado;
      if (_busqueda.isEmpty) {
        resultado = List.from(negocios); // copia para no mutar el original
      } else {
        final busqueda = _busqueda.toLowerCase();
        resultado = negocios.where((negocio) {
          final nombre = (negocio['nombre'] as String? ?? '').toLowerCase();
          final municipio =
              (negocio['municipio'] as String? ?? '').toLowerCase();
          final provincia =
              (negocio['provincia'] as String? ?? '').toLowerCase();
          return nombre.contains(busqueda) ||
              municipio.contains(busqueda) ||
              provincia.contains(busqueda);
        }).toList();
      }

      // 2. Filtrar por grupo de categoría
      if (_grupoFiltro != null) {
        resultado = resultado.where((negocio) {
          final catId = negocio['categoriaPrincipal'] as String?;
          if (catId == null) return false;
          final grupo = buscarGrupoDeCategoria(catId);
          return grupo?.id == _grupoFiltro;
        }).toList();
      }

      negociosFiltrados = resultado;

      // 3. Ordenar: VIP primero, luego según el modo elegido
      negociosFiltrados.sort((a, b) {
        final aVip = a['esVip'] == true ? 1 : 0;
        final bVip = b['esVip'] == true ? 1 : 0;
        if (aVip != bVip) return bVip.compareTo(aVip); // VIP siempre primero

        if (_ordenReciente) {
          // ⭐ Recientes: más nuevo primero (descendente)
          final fechaA = _obtenerTimestamp(a);
          final fechaB = _obtenerTimestamp(b);
          if (fechaA != null && fechaB != null) {
            return fechaB.compareTo(fechaA);
          }
          // Si uno tiene fecha y el otro no, el que tiene fecha va primero
          if (fechaA != null) return -1;
          if (fechaB != null) return 1;
          // Si ninguno tiene fecha, mantener orden relativo (estable)
          return 0;
        } else {
          // ⭐ Alfabético: A-Z
          final nombreA = (a['nombre'] as String? ?? '').toLowerCase();
          final nombreB = (b['nombre'] as String? ?? '').toLowerCase();
          return nombreA.compareTo(nombreB);
        }
      });
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _busqueda = value;
      _filtrarNegocios();
    });
  }

  void _cambiarFiltroGrupo(String? grupoId) {
    setState(() {
      if (_grupoFiltro == grupoId) {
        _grupoFiltro = null;
      } else {
        _grupoFiltro = grupoId;
      }
      _filtrarNegocios();
    });
  }

  // ⭐ NUEVO: cambiar orden
  void _cambiarOrden(bool recientes) {
    if (_ordenReciente == recientes) return;
    setState(() {
      _ordenReciente = recientes;
      _filtrarNegocios();
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _busqueda = '';
      _grupoFiltro = null;
      _searchController.clear();
      _filtrarNegocios();
    });
  }

  bool get _hayFiltrosActivos =>
      _grupoFiltro != null || _busqueda.trim().isNotEmpty;

  void _seleccionarNegocio(Map<String, dynamic> negocio) {
    final lat = negocio['latitud'] as double;
    final lon = negocio['longitud'] as double;
    widget.onNegocioSeleccionado(LatLng(lat, lon));
    Navigator.pop(context);
  }

  Widget _buildChipsFiltro() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _buildChipFiltro(
              label: 'Todos',
              icono: Icons.apps,
              color: Colors.orange,
              seleccionado: _grupoFiltro == null,
              onTap: () => _cambiarFiltroGrupo(null),
            ),
            const SizedBox(width: 6),
            ...gruposCategorias.map((grupo) {
              final color = obtenerColorGrupo(grupo.colorHex);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _buildChipFiltro(
                  label: grupo.nombre,
                  icono: obtenerIcono(grupo.icono),
                  color: color,
                  seleccionado: _grupoFiltro == grupo.id,
                  onTap: () => _cambiarFiltroGrupo(grupo.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChipFiltro({
    required String label,
    required IconData icono,
    required Color color,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado ? color : color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 16,
              color: seleccionado ? Colors.white : color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? Colors.white : color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐ NUEVO: Toggle de orden (Recientes / A-Z)
  Widget _buildOrdenToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOrdenButton(
            icon: Icons.schedule,
            label: 'Recientes',
            activo: _ordenReciente,
            onTap: () => _cambiarOrden(true),
          ),
          _buildOrdenButton(
            icon: Icons.sort_by_alpha,
            label: 'A-Z',
            activo: !_ordenReciente,
            onTap: () => _cambiarOrden(false),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdenButton({
    required IconData icon,
    required String label,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: activo ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: activo ? Colors.white : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _obtenerNombreGrupoActivo() {
    if (_grupoFiltro == null) return 'Todos';
    final grupo = gruposCategorias.firstWhere(
      (g) => g.id == _grupoFiltro,
      orElse: () => gruposCategorias.first,
    );
    return grupo.nombre;
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
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, municipio o provincia...',
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
          ),

          // Chips de filtro por grupo
          _buildChipsFiltro(),

          // ⭐ Contador + limpiar filtros + toggle de orden
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${negociosFiltrados.length} negocios',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                if (_hayFiltrosActivos) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _limpiarFiltros,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.clear_all,
                              size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 2),
                          Text(
                            'Limpiar',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // ⭐ NUEVO: Toggle de orden
                _buildOrdenToggle(),
              ],
            ),
          ),

          // Aviso de filtro activo
          if (_hayFiltrosActivos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Filtrando: '
                        '${_grupoFiltro != null ? _obtenerNombreGrupoActivo() : 'Todos los tipos'}'
                        '${_busqueda.isNotEmpty ? ' • "${_busqueda}"' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
                : negociosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hayFiltrosActivos
                                  ? Icons.filter_alt_off
                                  : Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _hayFiltrosActivos
                                  ? 'No hay negocios con estos filtros'
                                  : (_busqueda.isEmpty
                                      ? 'No hay negocios disponibles'
                                      : 'No se encontraron resultados'),
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            if (_hayFiltrosActivos) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _limpiarFiltros,
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Limpiar filtros'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: negociosFiltrados.length,
                        itemBuilder: (context, index) {
                          final negocio = negociosFiltrados[index];
                          final esVip = negocio['esVip'] == true;

                          return _buildNegocioCard(negocio, esVip);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNegocioCard(Map<String, dynamic> negocio, bool esVip) {
    final nombre = negocio['nombre'] as String? ?? 'Sin nombre';
    final municipio = negocio['municipio'] as String? ?? '';
    final provincia = negocio['provincia'] as String? ?? '';
    final telefono = negocio['telefono'] as String?;
    final promedio = (negocio['promedioPuntuacion'] as num?)?.toDouble();
    final totalVotos = negocio['totalPuntuaciones'] as int? ?? 0;

    final catId = negocio['categoriaPrincipal'] as String?;
    final categoria = buscarCategoriaPorId(catId);
    final grupo = buscarGrupoDeCategoria(catId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _seleccionarNegocio(negocio),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: esVip
                ? const LinearGradient(
                    colors: [
                      Color(0xFFFFF8E1),
                      Color(0xFFFFECB3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: esVip ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: esVip
                ? Border.all(color: const Color(0xFFFFD700), width: 2)
                : Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              if (esVip)
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: esVip
                      ? const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        )
                      : null,
                  color: esVip ? null : Colors.orange.shade50,
                ),
                child: Icon(
                  esVip ? Icons.star : Icons.store,
                  color: esVip ? Colors.white : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: TextStyle(
                              fontWeight:
                                  esVip ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: esVip ? Colors.black87 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (esVip) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 10, color: Colors.white),
                                SizedBox(width: 2),
                                Text(
                                  'VIP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (municipio.isNotEmpty || provincia.isNotEmpty)
                      Text(
                        [municipio, provincia]
                            .where((s) => s.isNotEmpty)
                            .join(' • '),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (categoria != null && grupo != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: obtenerColorGrupo(grupo.colorHex)
                              .withOpacity(0.1),
                          border: Border.all(
                            color: obtenerColorGrupo(grupo.colorHex)
                                .withOpacity(0.5),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              obtenerIcono(categoria.icono),
                              size: 12,
                              color: obtenerColorGrupo(grupo.colorHex),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              categoria.nombre,
                              style: TextStyle(
                                color: obtenerColorGrupo(grupo.colorHex),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (esVip && telefono != null && telefono.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone,
                              size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            telefono,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (promedio != null && totalVotos > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            promedio.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            ' ($totalVotos)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: esVip ? Colors.orange.shade700 : Colors.grey.shade400,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
