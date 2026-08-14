import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ComentariosScreen extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;

  const ComentariosScreen({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
  });

  @override
  State<ComentariosScreen> createState() => _ComentariosScreenState();
}

class _ComentariosScreenState extends State<ComentariosScreen> {
  List<Map<String, dynamic>> comentarios = [];
  bool cargando = true;
  bool error = false;

  final TextEditingController _textoController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();
  final FocusNode _textoFocus = FocusNode();

  int? _puntuacionSeleccionada;

  @override
  void initState() {
    super.initState();
    _cargarComentarios();
  }

  @override
  void dispose() {
    _textoController.dispose();
    _autorController.dispose();
    _textoFocus.dispose();
    super.dispose();
  }

  Future<void> _cargarComentarios() async {
    setState(() {
      cargando = true;
      error = false;
    });

    try {
      final data = await ApiService.getComentarios(widget.negocioId);
      setState(() {
        comentarios = data;
        cargando = false;
      });
    } catch (e) {
      setState(() {
        error = true;
        cargando = false;
      });
      print('❌ Error cargando comentarios: $e');
    }
  }

  Future<void> _agregarComentario() async {
    final texto = _textoController.text.trim();

    if (_puntuacionSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⭐ Debes seleccionar una puntuación'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe un comentario'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final autor = _autorController.text.trim().isEmpty
        ? 'Anónimo'
        : _autorController.text.trim();

    try {
      await ApiService.agregarComentario(
        negocioId: widget.negocioId,
        texto: texto,
        autor: autor,
        puntuacion: _puntuacionSeleccionada,
      );

      _textoController.clear();
      setState(() {
        _puntuacionSeleccionada = null;
      });
      _textoFocus.unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comentario agregado ✅'),
          backgroundColor: Colors.green,
        ),
      );

      await _cargarComentarios();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    }
  }

  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (timestamp is num) {
        final milliseconds =
            timestamp > 1e12 ? timestamp.toInt() : (timestamp.toInt() * 1000);
        final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
        return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (timestamp is Map) {
        if (timestamp.containsKey('_seconds')) {
          final seconds = timestamp['_seconds'] as int?;
          if (seconds != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          }
        }
      }
    } catch (e) {
      print('Error parseando fecha: $e');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text('Comentarios de ${widget.negocioNombre}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarComentarios,
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: cargando
                  ? const Center(child: CircularProgressIndicator())
                  : error
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 60, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text('Error al cargar comentarios'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _cargarComentarios,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : comentarios.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay comentarios. ¡Sé el primero!',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: comentarios.length,
                              padding: const EdgeInsets.only(bottom: 8),
                              itemBuilder: (context, index) {
                                final c = comentarios[index];
                                final autor = c['autor'] ?? 'Anónimo';
                                final texto = c['texto'] ?? '';
                                final puntuacion = c['puntuacion'] as int?;
                                final timestamp = c['timestamp'];
                                final fecha = _formatearFecha(timestamp);

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  child: ListTile(
                                    title: Text(texto),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (puntuacion != null) ...[
                                          Row(
                                            children: List.generate(5, (i) {
                                              return Icon(
                                                i < puntuacion
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: Colors.orange,
                                                size: 16,
                                              );
                                            }),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          '$autor${fecha.isNotEmpty ? ' • $fecha' : ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange.shade100,
                                      child: Text(
                                        autor.isNotEmpty
                                            ? autor[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            // --- FORMULARIO PARA AGREGAR COMENTARIO ---
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + bottomPadding,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ⭐ FILA 1: Título y estrellas (centrado)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '⭐ Puntuación:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(5, (index) {
                        final starIndex = index + 1;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_puntuacionSeleccionada == starIndex) {
                                _puntuacionSeleccionada = null;
                              } else {
                                _puntuacionSeleccionada = starIndex;
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              _puntuacionSeleccionada != null &&
                                      _puntuacionSeleccionada! >= starIndex
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.orange,
                              size: 28,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  // ⭐ FILA 2: Mensaje de advertencia o botón quitar (centrado)
                  if (_puntuacionSeleccionada == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Center(
                        child: Text(
                          '⚠️ Debes seleccionar una puntuación',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _puntuacionSeleccionada = null;
                            });
                          },
                          child: const Text(
                            'Quitar puntuación',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Campos de texto
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _autorController,
                          decoration: const InputDecoration(
                            hintText: 'Nombre',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _textoController,
                          focusNode: _textoFocus,
                          decoration: const InputDecoration(
                            hintText: 'Escribe un comentario...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: (_) => _agregarComentario(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _agregarComentario,
                        icon: const Icon(Icons.send, color: Colors.orange),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.orange.shade50,
                        ),
                      ),
                    ],
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
