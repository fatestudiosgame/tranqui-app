import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/categorias.dart';

class AdminPanel extends StatefulWidget {
  final String adminUsername;

  const AdminPanel({
    super.key,
    required this.adminUsername,
  });

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<Map<String, dynamic>> _negocios = [];
  List<Map<String, dynamic>> _negociosFiltrados = [];
  bool _cargando = true;
  String? _accionEnProceso;

  final TextEditingController _searchController = TextEditingController();
  String _busqueda = '';

  String _filtroEstado = 'todos';
  String? _grupoFiltro;

  Map<String, dynamic>? _estadisticas;

  @override
  void initState() {
    super.initState();
    _cargarNegocios();
    _cargarEstadisticas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarNegocios() async {
    setState(() => _cargando = true);

    try {
      final data = await ApiService.getNegocios();
      if (mounted) {
        setState(() {
          _negocios = data;
          _aplicarFiltros();
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error cargando negocios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final stats = await ApiService.adminGetStats(
        adminUsername: widget.adminUsername,
      );
      if (mounted) {
        setState(() {
          _estadisticas = stats;
        });
      }
    } catch (e) {
      print('⚠️ Error cargando estadísticas: $e');
    }
  }

  void _aplicarFiltros() {
    var resultado = List<Map<String, dynamic>>.from(_negocios);

    if (_filtroEstado == 'vip') {
      resultado = resultado.where((n) => n['esVip'] == true).toList();
    } else if (_filtroEstado == 'normales') {
      resultado = resultado.where((n) => n['esVip'] != true).toList();
    } else if (_filtroEstado == 'pruebas') {
      resultado = resultado.where((n) => n['esNegocioPrueba'] == true).toList();
    }

    if (_grupoFiltro != null) {
      resultado = resultado.where((n) {
        final catId = n['categoriaPrincipal'] as String?;
        if (catId == null) return false;
        final grupo = buscarGrupoDeCategoria(catId);
        return grupo?.id == _grupoFiltro;
      }).toList();
    }

    if (_busqueda.trim().isNotEmpty) {
      final query = _busqueda.toLowerCase();
      resultado = resultado.where((n) {
        final nombre = (n['nombre'] ?? '').toString().toLowerCase();
        final provincia = (n['provincia'] ?? '').toString().toLowerCase();
        final municipio = (n['municipio'] ?? '').toString().toLowerCase();
        final propietario =
            (n['propietarioUsername'] ?? '').toString().toLowerCase();
        return nombre.contains(query) ||
            provincia.contains(query) ||
            municipio.contains(query) ||
            propietario.contains(query);
      }).toList();
    }

    setState(() {
      _negociosFiltrados = resultado;
    });
  }

  // ⭐ NUEVO: Enviar notificación push a todos los dispositivos
  Future<void> _enviarNotificacionGlobal() async {
    final tituloController = TextEditingController();
    final mensajeController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.indigo, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Enviar notificación a todos',
                style: TextStyle(fontSize: 16),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.indigo),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El mensaje llegará como notificación push a todos los usuarios con la app instalada.',
                          style: TextStyle(fontSize: 12, color: Colors.indigo),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ej: Actualización importante',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mensajeController,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    hintText: 'Ej: Actualiza la app antes del 30 de octubre',
                    prefixIcon: Icon(Icons.message),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (tituloController.text.trim().isEmpty ||
                  mensajeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Completa el título y el mensaje'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.send),
            label: const Text('Enviar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostrar indicador de carga mientras envía
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Enviando notificación...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final resultado = await ApiService.enviarNotificacionATodos(
        adminUsername: widget.adminUsername,
        titulo: tituloController.text.trim(),
        mensaje: mensajeController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Enviado a ${resultado['enviados']} dispositivos (${resultado['fallos']} fallos)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ⭐ CORREGIDO: Diálogo de edición sin overflow
  Future<void> _editarNegocio(Map<String, dynamic> negocio) async {
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
    final provinciaController =
        TextEditingController(text: negocio['provincia'] ?? '');
    final municipioController =
        TextEditingController(text: negocio['municipio'] ?? '');

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
              const Icon(Icons.edit, color: Colors.blue, size: 22),
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
                        child: Text(
                          cat.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: provinciaController,
                    decoration: const InputDecoration(
                      labelText: 'Provincia',
                      prefixIcon: Icon(Icons.location_city),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: municipioController,
                    decoration: const InputDecoration(
                      labelText: 'Municipio',
                      prefixIcon: Icon(Icons.place),
                      border: OutlineInputBorder(),
                      isDense: true,
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
                Navigator.pop(context, {
                  'nombre': nombreController.text.trim(),
                  'descripcion': descripcionController.text.trim(),
                  'descripcionVip': descripcionVipController.text.trim(),
                  'horario': horarioController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  'whatsapp': whatsappController.text.trim(),
                  'provincia': provinciaController.text.trim(),
                  'municipio': municipioController.text.trim(),
                  'categoriaPrincipal': categoriaSeleccionada,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
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
      await ApiService.adminEditarNegocio(
        adminUsername: widget.adminUsername,
        negocioId: negocio['id'],
        nombre: resultado['nombre'],
        descripcion: resultado['descripcion'],
        descripcionVip: resultado['descripcionVip'],
        horario: resultado['horario'],
        telefono: resultado['telefono'],
        whatsapp: resultado['whatsapp'],
        provincia: resultado['provincia'],
        municipio: resultado['municipio'],
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
        await _cargarEstadisticas();
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

  Future<void> _borrarNegocio(Map<String, dynamic> negocio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('¿Borrar negocio?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se eliminará permanentemente:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              '"${negocio['nombre'] ?? 'Sin nombre'}"',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
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
                  Icon(Icons.warning_amber, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción NO se puede deshacer. También se borrarán todos sus comentarios.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Borrar definitivamente'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _accionEnProceso = negocio['id']);

    try {
      await ApiService.adminBorrarNegocio(
        adminUsername: widget.adminUsername,
        negocioId: negocio['id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Negocio eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
        await _cargarEstadisticas();
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

  // ⭐ CORREGIDO: Bottom sheet con SafeArea y scroll
  Future<void> _cambiarEstadoVip(Map<String, dynamic> negocio) async {
    final esVip = negocio['esVip'] == true;

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
              Text(
                'Gestionar VIP: ${negocio['nombre']}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (esVip) ...[
                Text(
                  'Estado actual: VIP (${negocio['tipoVip'] ?? 'desconocido'})',
                  style: TextStyle(color: Colors.green.shade700),
                ),
                Text(
                  'Propietario: @${negocio['propietarioUsername'] ?? 'desconocido'}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                if (negocio['esNegocioPrueba'] == true)
                  Text(
                    '⚠️ Este es un negocio de prueba',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ] else
                Text(
                  'Estado actual: Normal',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              const SizedBox(height: 16),
              if (esVip) ...[
                _buildAccionItem(
                  icon: Icons.swap_horiz,
                  color: Colors.purple,
                  titulo: 'Cambiar tipo de VIP',
                  descripcion: 'Cambiar entre Bronce, Plata, Oro, etc.',
                  onTap: () => Navigator.pop(context, 'cambiar-tipo'),
                ),
                const SizedBox(height: 8),
                _buildAccionItem(
                  icon: Icons.access_time,
                  color: Colors.blue,
                  titulo: 'Extender VIP',
                  descripcion: 'Extender la fecha de expiración',
                  onTap: () => Navigator.pop(context, 'extender'),
                ),
                const SizedBox(height: 8),
                _buildAccionItem(
                  icon: Icons.link_off,
                  color: Colors.red,
                  titulo: 'Liberar negocio',
                  descripcion: 'Quitar VIP y propietario',
                  onTap: () => Navigator.pop(context, 'liberar'),
                ),
              ] else ...[
                _buildAccionItem(
                  icon: Icons.add_business,
                  color: Colors.green,
                  titulo: 'Reclamar para un usuario',
                  descripcion: 'Asignar VIP manualmente',
                  onTap: () => Navigator.pop(context, 'reclamar'),
                ),
              ],
              const SizedBox(height: 8),
              _buildAccionItem(
                icon: Icons.delete_forever,
                color: Colors.red.shade900,
                titulo: 'Borrar negocio',
                descripcion: 'Eliminar permanentemente',
                onTap: () => Navigator.pop(context, 'borrar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (accion == null) return;

    if (accion == 'liberar') {
      await _liberarNegocioAdmin(negocio);
    } else if (accion == 'extender') {
      await _extenderVipAdmin(negocio);
    } else if (accion == 'reclamar') {
      await _reclamarNegocioAdmin(negocio);
    } else if (accion == 'cambiar-tipo') {
      await _cambiarTipoVipAdmin(negocio);
    } else if (accion == 'borrar') {
      await _borrarNegocio(negocio);
    }
  }

  Widget _buildAccionItem({
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
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

  Future<void> _liberarNegocioAdmin(Map<String, dynamic> negocio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Liberar este negocio?'),
        content: Text(
          'Se quitará el estado VIP y el propietario del negocio "${negocio['nombre']}".',
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

    setState(() => _accionEnProceso = negocio['id']);

    try {
      await ApiService.adminCambiarVipStatus(
        adminUsername: widget.adminUsername,
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
        await _cargarEstadisticas();
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

  Future<void> _extenderVipAdmin(Map<String, dynamic> negocio) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Nueva fecha de expiración',
    );

    if (fecha == null) return;

    setState(() => _accionEnProceso = negocio['id']);

    try {
      await ApiService.adminCambiarVipStatus(
        adminUsername: widget.adminUsername,
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

  // ⭐ CORREGIDO: Diálogo de cambio de tipo VIP
  Future<void> _cambiarTipoVipAdmin(Map<String, dynamic> negocio) async {
    final tipoActual = (negocio['tipoVip'] as String?) ?? 'bronce';
    String tipoSeleccionado = tipoActual;

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.purple, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Cambiar tipo de VIP',
                  style: TextStyle(fontSize: 16),
                ),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tipo actual: ${tipoActual.toUpperCase()}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecciona el nuevo tipo:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildOpcionTipoVip(
                    setDialogState,
                    'prueba',
                    'Prueba',
                    'DEV',
                    Colors.purple,
                    tipoSeleccionado,
                    (v) => tipoSeleccionado = v,
                  ),
                  _buildOpcionTipoVip(
                    setDialogState,
                    'bronceplus',
                    'Bronce Plus',
                    'B+',
                    const Color(0xFFCD7F32),
                    tipoSeleccionado,
                    (v) => tipoSeleccionado = v,
                  ),
                  _buildOpcionTipoVip(
                    setDialogState,
                    'plataplus',
                    'Plata Plus',
                    'P+',
                    const Color(0xFF808080),
                    tipoSeleccionado,
                    (v) => tipoSeleccionado = v,
                  ),
                  _buildOpcionTipoVip(
                    setDialogState,
                    'oroplus',
                    'Oro Plus',
                    'O+',
                    const Color(0xFFFFD700),
                    tipoSeleccionado,
                    (v) => tipoSeleccionado = v,
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

    setState(() => _accionEnProceso = negocio['id']);

    try {
      await ApiService.adminCambiarVipStatus(
        adminUsername: widget.adminUsername,
        negocioId: negocio['id'],
        accion: 'cambiar-tipo',
        tipoVip: resultado,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tipo cambiado a ${resultado.toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
        await _cargarEstadisticas();
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

  // ⭐ CORREGIDO: Diálogo de reclamar sin overflow
  Future<void> _reclamarNegocioAdmin(Map<String, dynamic> negocio) async {
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
          title: Row(
            children: [
              const Icon(Icons.add_business, color: Colors.green, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Reclamar manualmente',
                  style: TextStyle(fontSize: 16),
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
                              const Text(
                                'Negocio de prueba',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                esNegocioPrueba
                                    ? 'Propietario: ${widget.adminUsername}_usuario_test'
                                    : 'Para testing',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
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
                      DropdownMenuItem(
                        value: 'prueba',
                        child: Text('Prueba'),
                      ),
                      DropdownMenuItem(
                        value: 'bronceplus',
                        child: Text('Bronce Plus'),
                      ),
                      DropdownMenuItem(
                        value: 'plataplus',
                        child: Text('Plata Plus'),
                      ),
                      DropdownMenuItem(
                        value: 'oroplus',
                        child: Text('Oro Plus'),
                      ),
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
                      ? '${widget.adminUsername}_usuario_test'
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

    setState(() => _accionEnProceso = negocio['id']);

    try {
      await ApiService.adminCambiarVipStatus(
        adminUsername: widget.adminUsername,
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
                  ? '✅ Negocio de prueba creado: ${widget.adminUsername}_usuario_test'
                  : '✅ Negocio reclamado manualmente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarNegocios();
        await _cargarEstadisticas();
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

  Future<void> _mostrarEstadisticas() async {
    if (_estadisticas == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cargando estadísticas...'),
          backgroundColor: Colors.orange,
        ),
      );
      await _cargarEstadisticas();
    }

    if (_estadisticas == null) return;

    final porCategoria =
        Map<String, dynamic>.from(_estadisticas!['porCategoria'] ?? {});
    final porPlan = Map<String, dynamic>.from(_estadisticas!['porPlan'] ?? {});

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.bar_chart, color: Colors.indigo, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Estadísticas del sistema')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Total negocios',
                    '${_estadisticas!['totalNegocios'] ?? 0}'),
                _buildStatRow(
                    'VIP vigentes', '${_estadisticas!['vipVigentes'] ?? 0}'),
                _buildStatRow(
                    'Negocios de prueba', '${_estadisticas!['pruebas'] ?? 0}'),
                const Divider(height: 24),
                const Text(
                  'Negocios por plan:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (porPlan.isEmpty)
                  Text('Sin negocios VIP',
                      style: TextStyle(color: Colors.grey.shade600))
                else
                  ...porPlan.entries.map((e) => _buildStatRow(
                        e.key.toString().toUpperCase(),
                        '${e.value}',
                        color: _obtenerColorPorPlan(e.key.toString()),
                      )),
                const Divider(height: 24),
                const Text(
                  'Negocios por categoría:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...porCategoria.entries.map((e) {
                  final categoria = buscarCategoriaPorId(e.key.toString());
                  return _buildStatRow(
                    categoria?.nombre ?? e.key.toString(),
                    '${e.value}',
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String valor, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color ?? Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: (color ?? Colors.indigo).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _obtenerColorPorPlan(String plan) {
    final t = plan.toLowerCase();
    if (t.contains('oro')) return const Color(0xFFFF8C00);
    if (t.contains('plata')) return const Color(0xFF808080);
    if (t.contains('bronce')) return const Color(0xFFCD7F32);
    if (t.contains('prueba')) return Colors.purple;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final totalVip = _negocios.where((n) => n['esVip'] == true).length;
    final totalPruebas =
        _negocios.where((n) => n['esNegocioPrueba'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings),
            const SizedBox(width: 8),
            const Expanded(child: Text('Panel Admin')),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // ⭐ NUEVO: Botón para enviar notificación global
          IconButton(
            icon: const Icon(Icons.campaign),
            onPressed: _enviarNotificacionGlobal,
            tooltip: 'Enviar notificación a todos',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _mostrarEstadisticas,
            tooltip: 'Estadísticas',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _cargarNegocios();
              await _cargarEstadisticas();
            },
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade700, Colors.indigo.shade900],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '@${widget.adminUsername}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatAdmin(
                            icon: Icons.business,
                            valor: '${_negocios.length}',
                            label: 'Total',
                          ),
                          _buildStatAdmin(
                            icon: Icons.star,
                            valor: '$totalVip',
                            label: 'VIP',
                          ),
                          _buildStatAdmin(
                            icon: Icons.bug_report,
                            valor: '$totalPruebas',
                            label: 'Pruebas',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Buscar por nombre, provincia, propietario...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _busqueda.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _busqueda = '';
                                      _aplicarFiltros();
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _busqueda = value;
                            _aplicarFiltros();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFiltroEstado(
                              'todos',
                              'Todos',
                              Icons.filter_list,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildFiltroEstado(
                              'vip',
                              'VIP',
                              Icons.star,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildFiltroEstado(
                              'pruebas',
                              'Test',
                              Icons.bug_report,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildChipGrupo(null, 'Todos'),
                            ...gruposCategorias.map((g) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _buildChipGrupo(g.id, g.nombre),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await _cargarNegocios();
                      await _cargarEstadisticas();
                    },
                    child: _negociosFiltrados.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No hay negocios que coincidan',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _negociosFiltrados.length,
                            itemBuilder: (context, index) {
                              final negocio = _negociosFiltrados[index];
                              return _buildNegocioAdminCard(negocio);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatAdmin({
    required IconData icon,
    required String valor,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroEstado(String valor, String label, IconData icono) {
    final activo = _filtroEstado == valor;
    return InkWell(
      onTap: () {
        setState(() {
          _filtroEstado = valor;
          _aplicarFiltros();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: activo ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 14,
              color: activo ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: activo ? Colors.white : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipGrupo(String? grupoId, String label) {
    final activo = _grupoFiltro == grupoId;
    return InkWell(
      onTap: () {
        setState(() {
          _grupoFiltro = grupoId;
          _aplicarFiltros();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activo ? Colors.indigo : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: activo ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildNegocioAdminCard(Map<String, dynamic> negocio) {
    final esVip = negocio['esVip'] == true;
    final esPrueba = negocio['esNegocioPrueba'] == true;
    final enProceso = _accionEnProceso == negocio['id'];

    final catId = negocio['categoriaPrincipal'] as String?;
    final categoria = buscarCategoriaPorId(catId);
    final grupo = buscarGrupoDeCategoria(catId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: esPrueba
              ? Colors.orange.shade700
              : (esVip ? Colors.amber.shade700 : Colors.grey.shade300),
          width: esPrueba || esVip ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: esPrueba
                        ? Colors.orange.withOpacity(0.1)
                        : (esVip ? Colors.amber : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    esPrueba
                        ? Icons.bug_report
                        : (esVip ? Icons.star : Icons.store),
                    color: esPrueba
                        ? Colors.orange.shade700
                        : (esVip ? Colors.amber.shade700 : Colors.grey),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        negocio['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${negocio['municipio'] ?? ''}, ${negocio['provincia'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (esPrueba)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'TEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (esVip)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (negocio['tipoVip'] ?? 'VIP').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (categoria != null && grupo != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    obtenerIcono(categoria.icono),
                    size: 14,
                    color: obtenerColorGrupo(grupo.colorHex),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      categoria.nombre,
                      style: TextStyle(
                        fontSize: 12,
                        color: obtenerColorGrupo(grupo.colorHex),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (esVip && negocio['propietarioUsername'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: esPrueba ? Colors.orange.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: esPrueba
                        ? Colors.orange.shade300
                        : Colors.blue.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      esPrueba ? Icons.bug_report : Icons.person,
                      size: 16,
                      color: esPrueba
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${negocio['propietarioUsername']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: esPrueba
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (esPrueba)
                            Text(
                              'Negocio de prueba (admin: ${negocio['creadoPorAdmin'] ?? 'desconocido'})',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (enProceso)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editarNegocio(negocio),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _cambiarEstadoVip(negocio),
                      icon: Icon(
                        esVip ? Icons.star_border : Icons.star,
                        size: 16,
                      ),
                      label: Text(esVip ? 'VIP' : 'Hacer VIP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: esPrueba
                            ? Colors.orange
                            : (esVip ? Colors.amber.shade700 : Colors.green),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
