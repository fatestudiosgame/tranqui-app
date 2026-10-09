import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/local_storage_service.dart';
import '../services/api_service.dart';
import '../data/categorias.dart';
import 'gestionar_catalogo.dart';

class MisNegocios extends StatefulWidget {
  final String username;
  final String tipoPlan;
  final DateTime? fechaExpiracion;
  final String licencia;

  const MisNegocios({
    super.key,
    required this.username,
    required this.tipoPlan,
    this.fechaExpiracion,
    required this.licencia,
  });

  @override
  State<MisNegocios> createState() => _MisNegociosState();
}

class _MisNegociosState extends State<MisNegocios> {
  List<Map<String, dynamic>> _misNegocios = [];
  bool _cargando = true;
  String? _accionEnProceso;

  @override
  void initState() {
    super.initState();
    _cargarNegocios();
  }

  Future<void> _cargarNegocios() async {
    setState(() => _cargando = true);

    try {
      final todosServidor = await ApiService.getNegocios();
      await LocalStorageService.guardarNegocios(todosServidor);
      _procesarNegocios(todosServidor);
    } catch (e) {
      try {
        final todosLocal = await LocalStorageService.obtenerNegocios();
        _procesarNegocios(
          todosLocal.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📶 Mostrando datos guardados (sin conexión)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (_) {
        if (mounted) setState(() => _cargando = false);
      }
    }
  }

  void _procesarNegocios(List<Map<String, dynamic>> todos) {
    final mios = todos.where((n) {
      final esVip = n['esVip'] == true;
      final propietario = n['propietarioUsername'] as String?;
      return esVip && propietario == widget.username;
    }).toList();

    if (mounted) {
      setState(() {
        _misNegocios = mios;
        _cargando = false;
      });
    }
  }

  int _limitePorPlan() {
    final t = widget.tipoPlan.toLowerCase();
    if (t.contains('oro')) return 5;
    if (t.contains('plata')) return 3;
    if (t.contains('bronce')) return 1;
    if (t.contains('prueba')) return 1;
    return 1;
  }

  Color _colorPlan() {
    final t = widget.tipoPlan.toLowerCase();
    if (t.contains('oro')) return const Color(0xFFFFD700);
    if (t.contains('plata')) return const Color(0xFF808080);
    if (t.contains('bronce')) return const Color(0xFFCD7F32);
    if (t.contains('prueba')) return Colors.purple;
    return Colors.orange;
  }

  Future<void> _editarNegocio(Map<String, dynamic> negocio) async {
    final nombreController =
        TextEditingController(text: negocio['nombre'] ?? '');
    final descripcionController =
        TextEditingController(text: negocio['descripcion'] ?? '');
    final horarioController =
        TextEditingController(text: negocio['horario'] ?? '');
    final telefonoController =
        TextEditingController(text: negocio['telefono'] ?? '');
    final whatsappController =
        TextEditingController(text: negocio['whatsapp'] ?? '');
    final descVipController =
        TextEditingController(text: negocio['descripcionVip'] ?? '');

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
          title: Text('Editar: ${negocio['nombre'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                            child: Text(
                              grupo.nombre,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                      .firstWhere(
                        (g) => g.id == grupoSeleccionado,
                        orElse: () => gruposCategorias.first,
                      )
                      .categorias
                      .map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Text(cat.nombre),
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
                    labelText: 'Nombre del negocio',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción general',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descVipController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción VIP (destacada)',
                    prefixIcon: Icon(Icons.star),
                    hintText: 'Ej: 10% de descuento con Transfermóvil',
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
                    hintText: 'Ej: Lun-Vie 9am-6pm',
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
                    hintText: '+53 5xxx xxxx',
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
                    hintText: '+53 5xxx xxxx',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
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
                  'descripcionVip': descVipController.text.trim(),
                  'horario': horarioController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  'whatsapp': whatsappController.text.trim(),
                  'categoriaPrincipal': categoriaSeleccionada,
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

    if (resultado == null) return;

    setState(() => _accionEnProceso = negocio['id']);

    try {
      await ApiService.actualizarNegocioVip(
        negocioId: negocio['id'],
        username: widget.username,
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
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accionEnProceso = null);
    }
  }

  void _gestionarCatalogo(Map<String, dynamic> negocio) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GestionarCatalogo(
          negocioId: negocio['id'],
          negocioNombre: negocio['nombre'] ?? 'Negocio',
          propietarioUsername: widget.username,
        ),
      ),
    );
  }

  void _verEnMapa(Map<String, dynamic> negocio) {
    final lat = negocio['latitud'] as double?;
    final lon = negocio['longitud'] as double?;
    if (lat != null && lon != null) {
      Navigator.pop(context, LatLng(lat, lon));
    }
  }

  @override
  Widget build(BuildContext context) {
    final limite = _limitePorPlan();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Negocios VIP'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarNegocios,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 16),

                  // ⭐ LISTA DE NEGOCIOS PROPIOS
                  if (_misNegocios.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.business,
                              size: 56, color: Colors.orange.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'Aún no tienes negocios VIP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ve al mapa, mantén presionado un marcador y elige "Reclamar como mío" para comenzar.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.map),
                            label: const Text('Ir al mapa'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: _colorPlan(), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '${_misNegocios.length}/$limite negocio(s) VIP',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._misNegocios.map(
                      (negocio) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildNegocioCard(negocio),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildNegocioCard(Map<String, dynamic> negocio) {
    final nombre = negocio['nombre'] ?? 'Sin nombre';
    final desc = negocio['descripcion'] ?? '';
    final provincia = negocio['provincia'] ?? '';
    final municipio = negocio['municipio'] ?? '';
    final enProceso = _accionEnProceso == negocio['id'];

    final catId = negocio['categoriaPrincipal'] as String?;
    final categoria = buscarCategoriaPorId(catId);
    final grupo = buscarGrupoDeCategoria(catId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _colorPlan().withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: icono + nombre + badge plan
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _colorPlan().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.star,
                    color: _colorPlan(),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provincia.isNotEmpty || municipio.isNotEmpty)
                        Text(
                          '$municipio, $provincia',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorPlan(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.tipoPlan.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Categoría
            if (categoria != null && grupo != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: obtenerColorGrupo(grupo.colorHex).withOpacity(0.1),
                  border: Border.all(
                    color: obtenerColorGrupo(grupo.colorHex).withOpacity(0.5),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      obtenerIcono(categoria.icono),
                      size: 14,
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
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            if (enProceso)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              // Botón principal: Gestionar Catálogo
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _gestionarCatalogo(negocio),
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: const Text('Gestionar Catálogo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ⭐ Fila: Editar y Ver en Mapa (sin botón Liberar)
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.edit,
                    label: 'Editar',
                    color: Colors.blue,
                    onTap: () => _editarNegocio(negocio),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.map,
                    label: 'Ver en Mapa',
                    color: Colors.green,
                    onTap: () => _verEnMapa(negocio),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
