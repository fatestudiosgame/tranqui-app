import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';

class GestionarCatalogo extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  final String? adminUsername;
  final String? propietarioUsername;

  const GestionarCatalogo({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    this.adminUsername,
    this.propietarioUsername,
  });

  @override
  State<GestionarCatalogo> createState() => _GestionarCatalogoState();
}

class _GestionarCatalogoState extends State<GestionarCatalogo> {
  bool _cargando = true;
  List<Map<String, dynamic>> _productos = [];
  String? _error;

  // ⭐ Buscador y categorías colapsables
  final TextEditingController _busquedaController = TextEditingController();
  String _busqueda = '';
  final Map<String, bool> _categoriasExpandidas = {};

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final response = await ApiService.getCatalogoLista(widget.negocioId);
      if (mounted) {
        setState(() {
          _productos = response;
          _cargando = false;
          // ⭐ Inicializar todas las categorías como expandidas
          _categoriasExpandidas.clear();
          final categorias = <String>{};
          for (final p in _productos) {
            categorias.add(p['categoria'] ?? 'General');
          }
          for (final cat in categorias) {
            _categoriasExpandidas[cat] = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  // ⭐ Filtrar productos según búsqueda
  List<Map<String, dynamic>> _filtrarProductos(
      List<Map<String, dynamic>> productos) {
    if (_busqueda.isEmpty) return productos;
    final q = _busqueda.toLowerCase().trim();
    return productos.where((p) {
      final nombre = (p['nombre'] ?? '').toString().toLowerCase();
      final desc = (p['descripcion'] ?? '').toString().toLowerCase();
      return nombre.contains(q) || desc.contains(q);
    }).toList();
  }

  Future<void> _mostrarDialogoProducto({Map<String, dynamic>? producto}) async {
    final esEdicion = producto != null;

    final nombreController =
        TextEditingController(text: producto?['nombre'] ?? '');
    final descripcionController =
        TextEditingController(text: producto?['descripcion'] ?? '');
    final precioController = TextEditingController(
        text: producto?['precio'] != null && producto!['precio'] > 0
            ? producto['precio'].toString()
            : '');
    final imagenController =
        TextEditingController(text: producto?['imagenUrl'] ?? '');
    final categoriaController =
        TextEditingController(text: producto?['categoria'] ?? '');

    String monedaSeleccionada = producto?['moneda'] ?? 'CUP';
    bool agotado = producto?['agotado'] == true;
    bool _subiendoImagen = false;
    XFile? _imagenSeleccionada;

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                esEdicion ? Icons.edit : Icons.add_box,
                color: Colors.teal,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  esEdicion ? 'Editar producto' : 'Agregar producto',
                  style: const TextStyle(fontSize: 18),
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
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto *',
                      hintText: 'Ej: Pizza Hawaiana',
                      prefixIcon: Icon(Icons.local_offer),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Con jamón y piña',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: precioController,
                          decoration: const InputDecoration(
                            labelText: 'Precio',
                            hintText: 'Ej: 850',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: monedaSeleccionada,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Moneda',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'CUP', child: Text('CUP')),
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                            DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              monedaSeleccionada = value ?? 'CUP';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoriaController,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      hintText: 'Ej: Platos principales',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: agotado
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: agotado
                            ? Colors.orange.shade300
                            : Colors.green.shade300,
                      ),
                    ),
                    child: SwitchListTile(
                      value: agotado,
                      activeColor: Colors.orange,
                      onChanged: (v) {
                        setDialogState(() {
                          agotado = v;
                        });
                      },
                      title: Text(
                        'Agotado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: agotado
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                      subtitle: Text(
                        agotado
                            ? 'Se muestra en el catálogo pero no se puede pedir'
                            : 'Disponible para pedir',
                        style: const TextStyle(fontSize: 11),
                      ),
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.photo_camera,
                                color: Colors.teal, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Foto del producto',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (imagenController.text.isNotEmpty ||
                                _imagenSeleccionada != null)
                              TextButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    imagenController.clear();
                                    _imagenSeleccionada = null;
                                  });
                                },
                                icon: const Icon(Icons.delete, size: 16),
                                label: const Text('Quitar'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_imagenSeleccionada != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: Image.file(
                                File(_imagenSeleccionada!.path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey, size: 40),
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        else if (imagenController.text.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: Image.network(
                                imagenController.text,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey, size: 40),
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      color: Colors.grey, size: 40),
                                  SizedBox(height: 8),
                                  Text(
                                    'Sin foto',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _subiendoImagen
                                ? null
                                : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final imagen = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1024,
                                        maxHeight: 1024,
                                        imageQuality: 85,
                                      );

                                      if (imagen != null) {
                                        setDialogState(() {
                                          _subiendoImagen = true;
                                        });

                                        final url =
                                            await CloudinaryService.subirImagen(
                                          archivo: imagen,
                                          folder:
                                              'tranqui/negocios/${widget.negocioId}/catalogo',
                                        );

                                        if (mounted) {
                                          setDialogState(() {
                                            imagenController.text = url;
                                            _imagenSeleccionada = null;
                                            _subiendoImagen = false;
                                          });
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  '✅ Foto subida correctamente'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        _subiendoImagen = false;
                                      });
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '❌ ${e.toString().replaceFirst('Exception: ', '')}'),
                                            backgroundColor: Colors.red,
                                            duration:
                                                const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: _subiendoImagen
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.photo_library),
                            label: Text(_subiendoImagen
                                ? 'Subiendo...'
                                : 'Seleccionar de galería'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal),
                            ),
                          ),
                        ),
                      ],
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
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre es obligatorio'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                double precio = 0;
                if (precioController.text.isNotEmpty) {
                  precio = double.tryParse(precioController.text) ?? 0;
                }

                Navigator.pop(context, {
                  'nombre': nombre,
                  'descripcion': descripcionController.text.trim(),
                  'precio': precio,
                  'moneda': monedaSeleccionada,
                  'categoria': categoriaController.text.trim().isEmpty
                      ? 'General'
                      : categoriaController.text.trim(),
                  'imagenUrl': imagenController.text.trim(),
                  'agotado': agotado,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text(esEdicion ? 'Guardar' : 'Agregar'),
            ),
          ],
        ),
      ),
    );

    if (resultado == null) return;

    try {
      if (esEdicion) {
        await ApiService.actualizarProductoCatalogo(
          negocioId: widget.negocioId,
          productoId: producto['id'],
          adminUsername: widget.adminUsername,
          propietarioUsername: widget.propietarioUsername,
          nombre: resultado['nombre'],
          descripcion: resultado['descripcion'],
          precio: resultado['precio'],
          moneda: resultado['moneda'],
          categoria: resultado['categoria'],
          imagenUrl: resultado['imagenUrl'],
          agotado: resultado['agotado'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Producto actualizado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await ApiService.agregarProductoCatalogo(
          negocioId: widget.negocioId,
          adminUsername: widget.adminUsername,
          propietarioUsername: widget.propietarioUsername,
          nombre: resultado['nombre'],
          descripcion: resultado['descripcion'],
          precio: resultado['precio'],
          moneda: resultado['moneda'],
          categoria: resultado['categoria'],
          imagenUrl: resultado['imagenUrl'],
          agotado: resultado['agotado'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Producto agregado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      await _cargarProductos();
    } catch (e) {
      if (mounted) {
        _mostrarErrorAmigable(e.toString());
      }
    }
  }

  void _mostrarErrorAmigable(String error) {
    final esVipExpirado = error.toLowerCase().contains('expirado') ||
        error.toLowerCase().contains('vip') ||
        error.toLowerCase().contains('licencia');
    final esDueno =
        widget.propietarioUsername != null && widget.adminUsername == null;

    if (esVipExpirado && esDueno) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Licencia VIP expirada',
                    style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: const Text(
            'Tu licencia VIP ha expirado. Para seguir editando el catálogo necesitas renovarla.\n\nLa página pública de tu negocio sigue visible para los clientes, pero no puedes hacer cambios hasta renovar.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: const Text('Renovar VIP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${error.replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleAgotado(Map<String, dynamic> producto) async {
    final nuevo = !(producto['agotado'] == true);
    try {
      await ApiService.actualizarProductoCatalogo(
        negocioId: widget.negocioId,
        productoId: producto['id'],
        adminUsername: widget.adminUsername,
        propietarioUsername: widget.propietarioUsername,
        agotado: nuevo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nuevo
                ? '🚫 "${producto['nombre']}" marcado como AGOTADO'
                : '✅ "${producto['nombre']}" marcado como DISPONIBLE'),
            backgroundColor: nuevo ? Colors.orange : Colors.green,
          ),
        );
        await _cargarProductos();
      }
    } catch (e) {
      if (mounted) {
        _mostrarErrorAmigable(e.toString());
      }
    }
  }

  Future<void> _eliminarProducto(Map<String, dynamic> producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('¿Eliminar producto?')),
          ],
        ),
        content: Text(
          'Se eliminará "${producto['nombre']}" del catálogo. Esta acción no se puede deshacer.',
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ApiService.eliminarProductoCatalogo(
        negocioId: widget.negocioId,
        productoId: producto['id'],
        adminUsername: widget.adminUsername,
        propietarioUsername: widget.propietarioUsername,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Producto eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarProductos();
      }
    } catch (e) {
      if (mounted) {
        _mostrarErrorAmigable(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productosPorCategoria = <String, List<Map<String, dynamic>>>{};
    for (final producto in _productos) {
      final categoria = producto['categoria'] ?? 'General';
      productosPorCategoria.putIfAbsent(categoria, () => []).add(producto);
    }

    // ⭐ Filtrar productos según búsqueda
    final productosFiltradosPorCategoria =
        <String, List<Map<String, dynamic>>>{};
    for (final entry in productosPorCategoria.entries) {
      final filtrados = _filtrarProductos(entry.value);
      if (filtrados.isNotEmpty) {
        productosFiltradosPorCategoria[entry.key] = filtrados;
      }
    }

    final categorias = productosFiltradosPorCategoria.keys.toList();
    final esAdmin = widget.adminUsername != null;
    final colorPrincipal = esAdmin ? Colors.teal : Colors.blue.shade700;
    final hayBusqueda = _busqueda.isNotEmpty;
    final totalFiltrados = productosFiltradosPorCategoria.values
        .fold(0, (sum, list) => sum + list.length);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: colorPrincipal,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.negocioNombre,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${esAdmin ? 'Admin' : 'Mi catálogo'} • ${_productos.length} productos',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarProductos,
            tooltip: 'Recargar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoProducto(),
        backgroundColor: colorPrincipal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Error al cargar productos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _cargarProductos,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrincipal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _productos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay productos en el catálogo',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Toca el botón + para agregar el primero',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // ⭐ Buscador
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          color: Colors.white,
                          child: TextField(
                            controller: _busquedaController,
                            decoration: InputDecoration(
                              hintText: 'Buscar producto... (ej: pizza, café)',
                              prefixIcon:
                                  Icon(Icons.search, color: colorPrincipal),
                              suffixIcon: hayBusqueda
                                  ? IconButton(
                                      icon: const Icon(Icons.clear,
                                          color: Colors.grey),
                                      onPressed: () {
                                        _busquedaController.clear();
                                        setState(() => _busqueda = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide.none),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onChanged: (v) => setState(() => _busqueda = v),
                          ),
                        ),
                        // ⭐ Contador de resultados
                        if (hayBusqueda)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color: colorPrincipal.withOpacity(0.05),
                            child: Text(
                              totalFiltrados == 0
                                  ? 'Sin resultados para "$_busqueda"'
                                  : '$totalFiltrados resultado(s) para "$_busqueda"',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorPrincipal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        // ⭐ Lista de productos
                        Expanded(
                          child: categorias.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off,
                                          size: 64,
                                          color: Colors.grey.shade300),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No se encontraron productos',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _cargarProductos,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: categorias.length,
                                    itemBuilder: (context, index) {
                                      final categoria = categorias[index];
                                      final productosCategoria =
                                          productosFiltradosPorCategoria[
                                              categoria]!;
                                      final estaExpandida =
                                          _categoriasExpandidas[categoria] ??
                                              true;

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                        ),
                                        child: Column(
                                          children: [
                                            // ⭐ Header de categoría colapsable
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _categoriasExpandidas[
                                                          categoria] =
                                                      !estaExpandida;
                                                });
                                              },
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                                bottom: Radius.circular(0),
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      colorPrincipal
                                                          .withOpacity(0.9),
                                                      colorPrincipal,
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                    top: const Radius.circular(
                                                        12),
                                                    bottom: estaExpandida
                                                        ? Radius.zero
                                                        : const Radius.circular(
                                                            12),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: const Icon(
                                                        Icons.category,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        categoria.toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.25),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Text(
                                                        '${productosCategoria.length}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      estaExpandida
                                                          ? Icons
                                                              .keyboard_arrow_up
                                                          : Icons
                                                              .keyboard_arrow_down,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // ⭐ Productos (solo si está expandida)
                                            if (estaExpandida)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                child: Column(
                                                  children: productosCategoria
                                                      .map((producto) =>
                                                          _buildProductoCardAdmin(
                                                              producto))
                                                      .toList(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildProductoCardAdmin(Map<String, dynamic> producto) {
    final nombre = producto['nombre'] ?? 'Sin nombre';
    final descripcion = producto['descripcion'] ?? '';
    final precio = producto['precio'] ?? 0;
    final moneda = producto['moneda'] ?? 'CUP';
    final imagenUrl = producto['imagenUrl'] ?? '';
    final agotado = producto['agotado'] == true;
    final esAdmin = widget.adminUsername != null;
    final colorPrincipal = esAdmin ? Colors.teal : Colors.blue.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagenUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: Image.network(
                    imagenUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: colorPrincipal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_offer,
                  color: colorPrincipal,
                  size: 28,
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (agotado) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade400),
                          ),
                          child: Text(
                            'AGOTADO',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (descripcion.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    precio > 0 ? '$precio $moneda' : 'Sin precio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: precio > 0 ? colorPrincipal : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: () => _toggleAgotado(producto),
                  icon: Icon(
                    agotado ? Icons.check_circle_outline : Icons.block,
                    size: 20,
                  ),
                  color: agotado ? Colors.green : Colors.orange,
                  tooltip: agotado
                      ? 'Marcar como disponible'
                      : 'Marcar como agotado',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () => _mostrarDialogoProducto(producto: producto),
                  icon: const Icon(Icons.edit, size: 20),
                  color: Colors.blue,
                  tooltip: 'Editar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () => _eliminarProducto(producto),
                  icon: const Icon(Icons.delete, size: 20),
                  color: Colors.red,
                  tooltip: 'Eliminar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
