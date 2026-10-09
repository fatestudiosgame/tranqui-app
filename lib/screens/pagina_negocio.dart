import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../data/categorias.dart';
import 'catalogo_negocio.dart';
import 'comentarios_screen.dart';
import 'pantalla_vip.dart';
import '../services/compartir_service.dart';
import 'mapa_negocios.dart';

class PaginaNegocio extends StatefulWidget {
  final String negocioId;

  const PaginaNegocio({super.key, required this.negocioId});

  @override
  State<PaginaNegocio> createState() => _PaginaNegocioState();
}

class _PaginaNegocioState extends State<PaginaNegocio> {
  Map<String, dynamic>? _negocio;
  List<Map<String, dynamic>> _comentarios = [];
  bool _cargandoNegocio = true;
  bool _cargandoComentarios = true;
  bool _errorNegocio = false;

  final PageController _fotosController = PageController();
  int _fotoActualIndex = 0;

  @override
  void dispose() {
    _fotosController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarNegocio();
    _cargarComentarios();
  }

  Future<void> _cargarNegocio() async {
    try {
      final locales = await LocalStorageService.obtenerNegocios();
      final cached = locales.firstWhere(
        (n) => n['id'] == widget.negocioId,
        orElse: () => <String, dynamic>{},
      );
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _negocio = Map<String, dynamic>.from(cached);
          _cargandoNegocio = false;
        });
      }
    } catch (_) {}

    try {
      final negocio = await ApiService.getNegocioPorId(widget.negocioId);
      if (mounted) {
        setState(() {
          _negocio = negocio;
          _cargandoNegocio = false;
        });
      }
    } catch (e) {
      if (mounted && _negocio == null) {
        setState(() {
          _errorNegocio = true;
          _cargandoNegocio = false;
        });
      }
    }
  }

  Future<void> _cargarComentarios() async {
    try {
      final comentarios = await ApiService.getComentarios(widget.negocioId);
      if (mounted) {
        setState(() {
          _comentarios = comentarios.take(5).toList();
          _cargandoComentarios = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoComentarios = false;
        });
      }
    }
  }

  Color _colorVip(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro')) return const Color(0xFFFFD700);
    if (t.contains('plata')) return const Color(0xFFC0C0C0);
    if (t.contains('bronce')) return const Color(0xFFCD7F32);
    if (t.contains('prueba')) return Colors.purple;
    return Colors.orange;
  }

  LinearGradient _gradienteVip(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro'))
      return const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    if (t.contains('plata'))
      return const LinearGradient(
        colors: [Color(0xFFE8E8E8), Color(0xFFA0A0A0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    if (t.contains('bronce'))
      return const LinearGradient(
        colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    if (t.contains('prueba'))
      return const LinearGradient(
        colors: [Colors.purple, Color(0xFF6A1B9A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    return const LinearGradient(
      colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _colorTextoVip(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro') || t.contains('plata') || t.contains('bronce')) {
      return Colors.black87;
    }
    return Colors.white;
  }

  String _badgeVip(String? tipoVip) {
    final t = tipoVip?.toLowerCase() ?? '';
    if (t.contains('oro')) return '⭐ VIP ORO';
    if (t.contains('plata')) return '🥈 VIP PLATA';
    if (t.contains('bronce')) return '🥉 VIP BRONCE';
    if (t.contains('prueba')) return '🧪 DEV';
    return '⭐ VIP';
  }

  void _compartir() {
    if (_negocio == null) return;
    final nombre = _negocio!['nombre'] ?? 'Negocio';
    final url =
        'https://fatestudiosgame.github.io/tranqui-web/p/${widget.negocioId}/';
    CompartirService.mostrar(
      context: context,
      nombre: nombre,
      url: url,
    );
  }

  void _llamar() async {
    final telefono = _negocio?['telefono'] as String?;
    if (telefono == null || telefono.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: telefono));
    } catch (_) {}
  }

  void _whatsapp() async {
    final whatsapp = _negocio?['whatsapp'] as String?;
    if (whatsapp == null || whatsapp.isEmpty) return;
    final numero = whatsapp.replaceAll(RegExp(r'[^\d]'), '');
    try {
      await launchUrl(Uri.parse('https://wa.me/$numero'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _verFotoFullScreen(List<String> fotos, int indexInicial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _VisorFotosFullScreen(
          fotos: fotos,
          indexInicial: indexInicial,
        ),
      ),
    );
  }

  // ⭐ Widget reutilizable para la fila de ubicación + categoría (SIN overflow)
  Widget _buildInfoChipRow(
      String municipio, String provincia, dynamic categoria) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (municipio.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$municipio, $provincia',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (categoria != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(obtenerIcono(categoria.icono),
                  size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  categoria.nombre,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCarruselFotos(List<String> fotos, String nombreNegocio) {
    if (fotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          PageView.builder(
            controller: _fotosController,
            itemCount: fotos.length,
            onPageChanged: (index) {
              setState(() => _fotoActualIndex = index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _verFotoFullScreen(fotos, index),
                child: Image.network(
                  fotos[index],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 64, color: Colors.grey),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.orange,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          if (fotos.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${_fotoActualIndex + 1}/${fotos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (fotos.length > 1 && _fotoActualIndex == 0)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Desliza',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Toca para ampliar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorNegocio) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFFF9800),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Negocio no encontrado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Este negocio puede haber sido eliminado.',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                icon: const Icon(Icons.map),
                label: const Text('Ir al mapa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_cargandoNegocio || _negocio == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: Color(0xFFFF9800),
              flexibleSpace: FlexibleSpaceBar(
                background: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 24,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF9800)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final negocio = _negocio!;
    final nombre = negocio['nombre'] ?? 'Negocio';
    final desc = negocio['descripcion'] ?? '';
    final descVip = negocio['descripcionVip'] ?? '';
    final horario = negocio['horario'] ?? '';
    final provincia = negocio['provincia'] ?? '';
    final municipio = negocio['municipio'] ?? '';
    final telefono = negocio['telefono'] as String?;
    final whatsapp = negocio['whatsapp'] as String?;
    final tipoVip = negocio['tipoVip'] as String?;
    final lat = negocio['latitud'] as double?;
    final lon = negocio['longitud'] as double?;
    final promedio = (negocio['promedioPuntuacion'] as num?)?.toDouble();
    final totalVotos = negocio['totalPuntuaciones'] as int? ?? 0;
    final propietario = negocio['propietarioUsername'] as String?;

    final fotos = (negocio['fotos'] as List?)?.cast<String>() ?? [];
    final tieneFotos = fotos.isNotEmpty;

    final categoriaId = negocio['categoriaPrincipal'] as String?;
    final categoria = buscarCategoriaPorId(categoriaId);

    final colorVip = _colorVip(tipoVip);
    final gradiente = _gradienteVip(tipoVip);
    final colorTexto = _colorTextoVip(tipoVip);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: tieneFotos ? 280 : 220,
            pinned: true,
            backgroundColor: colorVip,
            foregroundColor: colorTexto,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _compartir,
                tooltip: 'Compartir',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: tieneFotos
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildCarruselFotos(fotos, nombre),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _badgeVip(tipoVip),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 8, color: Colors.black54),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _buildInfoChipRow(
                                  municipio, provincia, categoria),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(gradient: gradiente),
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: 60,
                            left: 20,
                            right: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _badgeVip(tipoVip),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  nombre,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 8, color: Colors.black38),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                _buildInfoChipRow(
                                    municipio, provincia, categoria),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (promedio != null && totalVotos > 0)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                (index + 1) <= promedio.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: const Color(0xFFFF9800),
                                size: 28,
                              );
                            }),
                            const SizedBox(width: 12),
                            Text(promedio.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF9800))),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                  '($totalVotos ${totalVotos == 1 ? 'reseña' : 'reseñas'})',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (descVip.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorVip.withOpacity(0.15),
                            colorVip.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorVip.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.star, color: colorVip, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              descVip,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (descVip.isNotEmpty) const SizedBox(height: 16),
                  if (desc.isNotEmpty) ...[
                    const Text('Sobre nosotros',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(desc,
                        style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            height: 1.5)),
                    const SizedBox(height: 16),
                  ],
                  if (horario.isNotEmpty) ...[
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.schedule,
                            color: Color(0xFFFF9800), size: 28),
                        title: const Text('Horario',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(horario),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Contactar',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (telefono != null && telefono.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _llamar,
                            icon: const Icon(Icons.phone, size: 20),
                            label: const Text('Llamar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      if (telefono != null &&
                          telefono.isNotEmpty &&
                          whatsapp != null &&
                          whatsapp.isNotEmpty)
                        const SizedBox(width: 12),
                      if (whatsapp != null && whatsapp.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _whatsapp,
                            icon: const Icon(Icons.chat, size: 20),
                            label: const Text('WhatsApp'),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CatalogoNegocio(
                              negocioId: widget.negocioId,
                              negocioNombre: nombre,
                              propietarioUsername: propietario,
                              esVip: true,
                              tipoVip: tipoVip,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book, size: 20),
                      label: const Text('Ver Catálogo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorVip,
                        foregroundColor: colorTexto,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (lat != null && lon != null) ...[
                    const Text('Ubicación',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(lat, lon),
                            initialZoom: 16,
                            interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=cb1_2djt_1_2314ecd586b7898a72a20685',
                              subdomains: const ['a', 'b', 'c', 'd'],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: LatLng(lat, lon),
                                  child: Icon(Icons.location_pin,
                                      color: colorVip, size: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          // ⭐ FIX: Devolver coordenadas al mapa para centrarse
                          // en este negocio sin causar loop infinito
                          if (lat != null && lon != null) {
                            Navigator.pop(context, LatLng(lat, lon));
                          } else {
                            Navigator.pop(context, true);
                          }
                        },
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('Ver en el mapa completo'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text('Comentarios recientes',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_cargandoComentarios)
                    ...List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    )
                  else if (_comentarios.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text('Aún no hay comentarios',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ),
                    )
                  else
                    ..._comentarios.map((c) => Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFFFF9800)
                                          .withOpacity(0.2),
                                      child: Text(
                                        (c['autor'] ?? 'A')[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFFFF9800),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c['autor'] ?? 'Anónimo',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (c['puntuacion'] != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            i < (c['puntuacion'] as int)
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 14,
                                            color: const Color(0xFFFF9800),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(c['texto'] ?? '',
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ComentariosScreen(
                              negocioId: widget.negocioId,
                              negocioNombre: nombre,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.comment, size: 18),
                      label: const Text('Ver todos los comentarios'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '¿Quieres una página así para tu negocio?',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hazte VIP y destaca en Tranqui con tu propia página, catálogo y más.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PantallaVip(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFFF5722),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25)),
                          ),
                          child: const Text('¡Quiero ser VIP!',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        Text('Página creada con Tranqui',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/');
                          },
                          child: const Text(
                            '🏪 Descubrir más negocios en Tranqui',
                            style: TextStyle(
                                color: Color(0xFFFF9800),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisorFotosFullScreen extends StatefulWidget {
  final List<String> fotos;
  final int indexInicial;

  const _VisorFotosFullScreen({
    required this.fotos,
    required this.indexInicial,
  });

  @override
  State<_VisorFotosFullScreen> createState() => _VisorFotosFullScreenState();
}

class _VisorFotosFullScreenState extends State<_VisorFotosFullScreen> {
  late PageController _controller;
  late int _indexActual;

  @override
  void initState() {
    super.initState();
    _indexActual = widget.indexInicial;
    _controller = PageController(initialPage: widget.indexInicial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_indexActual + 1} / ${widget.fotos.length}',
          style: const TextStyle(fontSize: 16),
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
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.fotos.length,
        onPageChanged: (index) {
          setState(() => _indexActual = index);
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.network(
                widget.fotos[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image,
                      size: 80, color: Colors.grey);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
