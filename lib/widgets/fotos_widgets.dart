import 'dart:async';
import 'package:flutter/material.dart';

/// Circulito que rota automáticamente entre las fotos del negocio.
/// Si no hay fotos, muestra un icono de respaldo.
class AvatarRotadorFotos extends StatefulWidget {
  final List<String> fotos;
  final VoidCallback? onTap;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;
  final Duration intervalo;

  const AvatarRotadorFotos({
    super.key,
    required this.fotos,
    this.onTap,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 56,
    this.intervalo = const Duration(seconds: 3),
  });

  @override
  State<AvatarRotadorFotos> createState() => _AvatarRotadorFotosState();
}

class _AvatarRotadorFotosState extends State<AvatarRotadorFotos> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.fotos.length > 1) {
      _timer = Timer.periodic(widget.intervalo, (_) {
        if (mounted) {
          setState(() {
            _index = (_index + 1) % widget.fotos.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sin fotos: círculo con icono de categoría
    if (widget.fotos.isEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.fallbackColor.withOpacity(0.15),
          border: Border.all(
              color: widget.fallbackColor.withOpacity(0.4), width: 2),
        ),
        child: Icon(widget.fallbackIcon,
            color: widget.fallbackColor, size: widget.size * 0.45),
      );
    }

    // Con fotos: círculo que rota con fundido suave
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Image.network(
                  widget.fotos[_index],
                  key: ValueKey(widget.fotos[_index]),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: widget.fallbackColor.withOpacity(0.15),
                    child:
                        Icon(widget.fallbackIcon, color: widget.fallbackColor),
                  ),
                ),
              ),
              // Mini-contador de fotos en la esquina
              if (widget.fotos.length > 1)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius:
                          const BorderRadius.only(topLeft: Radius.circular(8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library,
                            color: Colors.white, size: 9),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.fotos.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visor de fotos a pantalla completa con zoom y swipe.
class VisorFotosFullScreen extends StatefulWidget {
  final List<String> fotos;
  final int indexInicial;

  const VisorFotosFullScreen({
    super.key,
    required this.fotos,
    this.indexInicial = 0,
  });

  @override
  State<VisorFotosFullScreen> createState() => _VisorFotosFullScreenState();
}

class _VisorFotosFullScreenState extends State<VisorFotosFullScreen> {
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
        title: Text('${_indexActual + 1} / ${widget.fotos.length}',
            style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Cerrar'),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.fotos.length,
        onPageChanged: (index) => setState(() => _indexActual = index),
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.network(
                widget.fotos[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                    size: 80, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}
