import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';

class GestionFotosNegocio extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  final String username;
  final String tipoPlan;

  const GestionFotosNegocio({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    required this.username,
    required this.tipoPlan,
  });

  @override
  State<GestionFotosNegocio> createState() => _GestionFotosNegocioState();
}

class _GestionFotosNegocioState extends State<GestionFotosNegocio> {
  List<String> _fotos = [];
  bool _cargando = true;
  bool _subiendo = false;
  bool _guardando = false;

  int get _limite {
    final t = widget.tipoPlan.toLowerCase();
    if (t.contains('oro')) return 30;
    if (t.contains('plata')) return 10;
    if (t.contains('bronce')) return 3;
    if (t.contains('prueba')) return 30;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    _cargarFotos();
  }

  Future<void> _cargarFotos() async {
    try {
      final negocio = await ApiService.getNegocioPorId(widget.negocioId);
      if (mounted) {
        setState(() {
          _fotos = List<String>.from(negocio['fotos'] ?? []);
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error cargando fotos: $e')),
        );
      }
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ApiService.actualizarFotosNegocio(
        negocioId: widget.negocioId,
        username: widget.username,
        fotos: _fotos,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error guardando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarFoto() async {
    if (_fotos.length >= _limite) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '⚠️ Límite del plan ${widget.tipoPlan.toUpperCase()}: $_limite fotos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final archivo = await CloudinaryService.seleccionarImagen();
    if (archivo == null) return;

    setState(() => _subiendo = true);
    try {
      final url = await CloudinaryService.subirImagen(
        archivo: archivo,
        folder: CloudinaryService.folderGaleria(widget.negocioId),
      );
      setState(() => _fotos.add(url));
      await _guardar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Foto agregada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminarFoto(String url) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar foto?'),
        content: const Text('Se quitará de la galería del negocio.'),
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

    setState(() => _fotos.remove(url));
    await _guardar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.negocioNombre),
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_subiendo || _guardando) ? null : _agregarFoto,
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        icon: _subiendo
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo),
        label: Text(_subiendo ? 'Subiendo...' : 'Agregar foto'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.orange.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library,
                          size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        '${_fotos.length} / $_limite fotos '
                        '(plan ${widget.tipoPlan.toUpperCase()})',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _fotos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'Aún no hay fotos',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Toca "Agregar foto" para subir la primera',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _fotos.length,
                          itemBuilder: (context, i) {
                            final url = _fotos[i];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
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
                                    errorBuilder: (context, e, s) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image,
                                          color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => _eliminarFoto(url),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
