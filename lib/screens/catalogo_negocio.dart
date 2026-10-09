import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class CatalogoNegocio extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  final String? propietarioUsername;
  final bool esVip;
  final String? tipoVip;

  const CatalogoNegocio({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    this.propietarioUsername,
    this.esVip = false,
    this.tipoVip,
  });

  @override
  State<CatalogoNegocio> createState() => _CatalogoNegocioState();
}

class _CatalogoNegocioState extends State<CatalogoNegocio> {
  Map<String, List<Map<String, dynamic>>> _catalogo = {};
  final Map<String, Map<String, dynamic>> _productosPorId = {};
  final Map<String, bool> _categoriasExpandidas = {};

  // ⭐ CARRITO
  final Map<String, int> _carrito = {};
  String? _whatsapp;
  bool _enviando = false;

  // ⭐ BUSCADOR
  final TextEditingController _busquedaController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();
  String _busqueda = '';

  bool _cargando = true;
  String? _error;

  @override
  void dispose() {
    _busquedaController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final catalogo = await ApiService.getCatalogoAgrupado(widget.negocioId);
      if (!mounted) return;
      final porId = <String, Map<String, dynamic>>{};
      catalogo.forEach((cat, list) {
        for (final p in list) {
          porId[p['id'].toString()] = p;
        }
      });
      setState(() {
        _catalogo = catalogo;
        _productosPorId.addAll(porId);
        _cargando = false;
        for (var c in catalogo.keys) {
          _categoriasExpandidas[c] = true;
        }
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
    }
    // WhatsApp del negocio (no bloquea el catálogo)
    try {
      final n = await ApiService.getNegocioPorId(widget.negocioId);
      if (mounted) {
        setState(() {
          _whatsapp = (n['whatsapp'] ?? n['telefono'] ?? '').toString();
        });
      }
    } catch (_) {}
  }

  // ================= CARRITO =================

  int _carritoCount() => _carrito.values.fold(0, (a, b) => a + b);

  // ⭐ FIX: Calcula el total agrupado por moneda
  Map<String, double> _calcularTotalesPorMoneda() {
    final Map<String, double> totales = {};
    _carrito.forEach((id, qty) {
      final p = _productosPorId[id];
      if (p != null) {
        final precio =
            (p['precio'] is num) ? (p['precio'] as num).toDouble() : 0.0;
        final moneda = (p['moneda'] ?? 'CUP').toString().toUpperCase();
        totales[moneda] = (totales[moneda] ?? 0.0) + (precio * qty);
      }
    });
    return totales;
  }

  // ⭐ FIX: Texto compacto para el botón flotante
  String _textoTotalFab() {
    final totales = _calcularTotalesPorMoneda();
    if (totales.isEmpty) return '';
    return totales.entries
        .map((e) => _formatearPrecio(e.value, e.key))
        .join(' | ');
  }

  void _agregar(String id) =>
      setState(() => _carrito[id] = (_carrito[id] ?? 0) + 1);

  void _quitarUno(String id) => setState(() {
        final q = (_carrito[id] ?? 0) - 1;
        if (q <= 0) {
          _carrito.remove(id);
        } else {
          _carrito[id] = q;
        }
      });

  // ⭐ Enviar pedido por WhatsApp
  Future<void> _enviarPedido() async {
    if (_carrito.isEmpty || _enviando) return;
    final numeroLimpio = (_whatsapp ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (numeroLimpio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Este negocio no tiene WhatsApp configurado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final sb = StringBuffer();
    sb.writeln('Hola, quiero hacer un pedido en ${widget.negocioNombre}:');
    sb.writeln();
    _carrito.forEach((id, qty) {
      final p = _productosPorId[id];
      if (p == null) return;
      final precio = (p['precio'] is num) ? (p['precio'] as num) : 0;
      final moneda = (p['moneda'] ?? 'CUP').toString();
      sb.writeln(
          '• ${qty}x ${p['nombre']} — ${_formatearPrecio(precio * qty, moneda)}');
    });
    sb.writeln();

    // ⭐ FIX: Totales separados por moneda en el mensaje
    final totales = _calcularTotalesPorMoneda();
    if (totales.length == 1) {
      final moneda = totales.keys.first;
      sb.writeln('💰 Total: ${_formatearPrecio(totales[moneda]!, moneda)}');
    } else {
      sb.writeln('💰 Totales:');
      totales.forEach((moneda, total) {
        sb.writeln('   • ${_formatearPrecio(total, moneda)}');
      });
    }

    final notas = _notasController.text.trim();
    if (notas.isNotEmpty) {
      sb.writeln();
      sb.writeln('📝 Notas: $notas');
    }
    sb.writeln();
    sb.writeln('_Pedido enviado desde Tranqui_');

    setState(() => _enviando = true);
    try {
      final url =
          'https://wa.me/$numeroLimpio?text=${Uri.encodeComponent(sb.toString())}';
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      setState(() {
        _carrito.clear();
        _notasController.clear();
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pedido enviado por WhatsApp'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se pudo abrir WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ⭐ Panel del carrito
  void _abrirCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void refresh() {
            setSheet(() {});
            setState(() {});
          }

          void add(String id) {
            _carrito[id] = (_carrito[id] ?? 0) + 1;
            refresh();
          }

          void dec(String id) {
            final q = (_carrito[id] ?? 0) - 1;
            if (q <= 0) {
              _carrito.remove(id);
            } else {
              _carrito[id] = q;
            }
            refresh();
          }

          final ids = _carrito.keys.toList();

          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('Tu pedido',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if (ids.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _carrito.clear();
                              refresh();
                            },
                            child: const Text('Vaciar',
                                style: TextStyle(color: Colors.red)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Items
                  Expanded(
                    child: ids.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_shopping_cart,
                                    size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('Tu carrito está vacío',
                                    style:
                                        TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: ids.length,
                            itemBuilder: (context, i) {
                              final id = ids[i];
                              final p = _productosPorId[id];
                              if (p == null) return const SizedBox.shrink();
                              final qty = _carrito[id] ?? 0;
                              final precio = (p['precio'] is num)
                                  ? (p['precio'] as num)
                                  : 0;
                              final moneda = (p['moneda'] ?? 'CUP').toString();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (p['nombre'] ?? '').toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_formatearPrecio(precio, moneda)} c/u',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Subtotal: ${_formatearPrecio(precio * qty, moneda)}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFE65100)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.orange,
                                                size: 22),
                                            onPressed: () => dec(id),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          Text('$qty',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.orange)),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.add_circle_outline,
                                                color: Colors.orange,
                                                size: 22),
                                            onPressed: () => add(id),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  // Footer: notas + total + enviar
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _notasController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Notas del pedido (opcional)',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ⭐ FIX: Muestra un Total por cada moneda diferente
                        ..._calcularTotalesPorMoneda().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total ${entry.key}:',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  _formatearPrecio(entry.value, entry.key),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFE65100)),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (ids.isEmpty || _enviando)
                                ? null
                                : _enviarPedido,
                            icon: _enviando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send, size: 18),
                            label: const Text('Enviar pedido por WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= BÚSQUEDA =================

  List<Map<String, dynamic>> _productosFiltrados() {
    if (_busqueda.isEmpty) return [];
    final q = _busqueda.toLowerCase().trim();
    final resultados = <Map<String, dynamic>>[];
    for (final entry in _catalogo.entries) {
      final categoria = entry.key;
      for (final p in entry.value) {
        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
        final desc = (p['descripcion'] ?? '').toString().toLowerCase();
        final cat = categoria.toLowerCase();
        if (nombre.contains(q) || desc.contains(q) || cat.contains(q)) {
          resultados.add({...p, '_categoria': categoria});
        }
      }
    }
    return resultados;
  }

  int _totalProductos() =>
      _catalogo.values.fold(0, (sum, list) => sum + list.length);

  void _verFotoFullScreen(String imageUrl, String productName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _VisorFotoProducto(imageUrl: imageUrl, productName: productName),
      ),
    );
  }

  Color _colorVip(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro')) return const Color(0xFFFFD700);
    if (t.contains('plata')) return const Color(0xFFC0C0C0);
    if (t.contains('bronce')) return const Color(0xFFCD7F32);
    if (t.contains('prueba')) return Colors.purple;
    return Colors.orange;
  }

  String _formatearPrecio(num precio, String? moneda) {
    if (precio == 0) return 'Consultar';
    final m = moneda ?? 'CUP';
    final partes = precio.toInt().toString().split('');
    final resultado = <String>[];
    for (var i = 0; i < partes.length; i++) {
      resultado.add(partes[i]);
      if ((partes.length - i - 1) % 3 == 0 && i != partes.length - 1) {
        resultado.add(' ');
      }
    }
    return '${resultado.join()} $m';
  }

  @override
  Widget build(BuildContext context) {
    final colorVip = _colorVip(widget.tipoVip);
    final esBusquedaActiva = _busqueda.isNotEmpty;
    final resultados = esBusquedaActiva ? _productosFiltrados() : [];
    final totalProductos = _totalProductos();
    final carritoCount = _carritoCount();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.negocioNombre),
        backgroundColor: widget.esVip ? colorVip : Colors.orange,
        foregroundColor: widget.esVip &&
                (widget.tipoVip?.toLowerCase().contains('oro') == true ||
                    widget.tipoVip?.toLowerCase().contains('plata') == true ||
                    widget.tipoVip?.toLowerCase().contains('bronce') == true)
            ? Colors.black87
            : Colors.white,
      ),
      // ⭐ FAB del carrito
      floatingActionButton: carritoCount > 0
          ? FloatingActionButton.extended(
              onPressed: _abrirCarrito,
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart),
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$carritoCount',
                        style: const TextStyle(
                            color: Color(0xFF25D366),
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              label: Text(_textoTotalFab()), // ⭐ FIX: Muestra totales separados
            )
          : null,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Error al cargar el catálogo'),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : totalProductos == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Este negocio aún no tiene productos',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // ⭐ BARRA DE BÚSQUEDA
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _busquedaController,
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar producto... (ej: leche, café, queso)',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              prefixIcon: const Icon(Icons.search,
                                  color: Colors.orange),
                              suffixIcon: esBusquedaActiva
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
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            onChanged: (v) => setState(() => _busqueda = v),
                          ),
                        ),
                        if (esBusquedaActiva)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color: Colors.grey.shade50,
                            child: Text(
                              resultados.isEmpty
                                  ? 'Sin resultados para "$_busqueda"'
                                  : '${resultados.length} resultado${resultados.length == 1 ? '' : 's'} para "$_busqueda"',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Expanded(
                          child: esBusquedaActiva
                              ? resultados.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search_off,
                                              size: 64,
                                              color: Colors.grey.shade400),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No encontramos "$_busqueda"',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Prueba con otra palabra o revisa la ortografía',
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: resultados.length,
                                      itemBuilder: (context, index) {
                                        final p = resultados[index];
                                        final id = p['id'].toString();
                                        final puedeAgregar =
                                            p['agotado'] != true &&
                                                (p['precio'] is num) &&
                                                (p['precio'] as num) > 0;
                                        return _ProductoItem(
                                          producto: p,
                                          categoriaLabel:
                                              p['_categoria'] as String?,
                                          cantidad: _carrito[id] ?? 0,
                                          puedeAgregar: puedeAgregar,
                                          onAdd: () => _agregar(id),
                                          onDec: () => _quitarUno(id),
                                          onVerFoto: _verFotoFullScreen,
                                          formatearPrecio: _formatearPrecio,
                                        );
                                      },
                                    )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _catalogo.length,
                                  itemBuilder: (context, index) {
                                    final categoria =
                                        _catalogo.keys.elementAt(index);
                                    final productos = _catalogo[categoria]!;
                                    final estaExpandida =
                                        _categoriasExpandidas[categoria] ??
                                            true;
                                    return _CategoriaColapsable(
                                      categoria: categoria,
                                      productos: productos,
                                      estaExpandida: estaExpandida,
                                      carrito: _carrito,
                                      onToggle: () {
                                        setState(() {
                                          _categoriasExpandidas[categoria] =
                                              !estaExpandida;
                                        });
                                      },
                                      onAdd: _agregar,
                                      onDec: _quitarUno,
                                      onVerFoto: _verFotoFullScreen,
                                      formatearPrecio: _formatearPrecio,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
    );
  }
}

// ⭐ Categoría colapsable
class _CategoriaColapsable extends StatelessWidget {
  final String categoria;
  final List<Map<String, dynamic>> productos;
  final bool estaExpandida;
  final Map<String, int> carrito;
  final VoidCallback onToggle;
  final void Function(String) onAdd;
  final void Function(String) onDec;
  final void Function(String, String) onVerFoto;
  final String Function(num, String?) formatearPrecio;

  const _CategoriaColapsable({
    required this.categoria,
    required this.productos,
    required this.estaExpandida,
    required this.carrito,
    required this.onToggle,
    required this.onAdd,
    required this.onDec,
    required this.onVerFoto,
    required this.formatearPrecio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade400,
                    Colors.orange.shade600,
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom:
                      estaExpandida ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      categoria.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${productos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: estaExpandida ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (estaExpandida)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: productos.map((producto) {
                  final id = producto['id'].toString();
                  final puedeAgregar = producto['agotado'] != true &&
                      (producto['precio'] is num) &&
                      (producto['precio'] as num) > 0;
                  return _ProductoItem(
                    producto: producto,
                    cantidad: carrito[id] ?? 0,
                    puedeAgregar: puedeAgregar,
                    onAdd: () => onAdd(id),
                    onDec: () => onDec(id),
                    onVerFoto: onVerFoto,
                    formatearPrecio: formatearPrecio,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ⭐ Imagen de red con loading y error
class _ImagenRed extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  const _ImagenRed({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stack) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: Icon(Icons.image, color: Colors.grey, size: iconSize),
      ),
    );
  }
}

// ⭐ Producto individual con botón de carrito
class _ProductoItem extends StatelessWidget {
  final Map<String, dynamic> producto;
  final String? categoriaLabel;
  final int cantidad;
  final bool puedeAgregar;
  final VoidCallback onAdd;
  final VoidCallback onDec;
  final void Function(String, String) onVerFoto;
  final String Function(num, String?) formatearPrecio;

  const _ProductoItem({
    required this.producto,
    this.categoriaLabel,
    required this.cantidad,
    required this.puedeAgregar,
    required this.onAdd,
    required this.onDec,
    required this.onVerFoto,
    required this.formatearPrecio,
  });

  @override
  Widget build(BuildContext context) {
    final agotado = producto['agotado'] == true;
    final nombre = (producto['nombre'] ?? '').toString();
    final desc = (producto['descripcion'] ?? '').toString().trim();
    final precio = (producto['precio'] is num) ? producto['precio'] as num : 0;
    final moneda = (producto['moneda'] ?? 'CUP').toString();
    final imgUrl = (producto['imagenUrl'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Opacity(
        opacity: agotado ? 0.55 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: imgUrl.isNotEmpty ? () => onVerFoto(imgUrl, nombre) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imgUrl.isNotEmpty
                    ? _ImagenRed(url: imgUrl, width: 80, height: 80)
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.inventory_2_outlined,
                            color: Colors.grey, size: 30),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (categoriaLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        categoriaLabel!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formatearPrecio(precio, moneda),
                          style: const TextStyle(
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (agotado) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE74C3C),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Agotado',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // ⭐ Control de carrito
            if (puedeAgregar)
              cantidad == 0
                  ? IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          size: 30, color: Colors.orange),
                      tooltip: 'Agregar al pedido',
                      onPressed: onAdd,
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 22, color: Colors.orange),
                            onPressed: onDec,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Text(
                            '$cantidad',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.orange),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                size: 22, color: Colors.orange),
                            onPressed: onAdd,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

// ⭐ Visor de foto a pantalla completa con zoom
class _VisorFotoProducto extends StatelessWidget {
  final String imageUrl;
  final String productName;

  const _VisorFotoProducto({
    required this.imageUrl,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          productName,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Cerrar',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stack) => const Icon(
              Icons.broken_image,
              size: 80,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
