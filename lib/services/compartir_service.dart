import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Menú de compartir propio de la app.
/// Evita el selector del sistema de Android, que crashea con
/// NullPointerException en ciertas ROMs (bug de ChooserActivity).
class CompartirService {
  static Future<void> mostrar({
    required BuildContext context,
    required String nombre,
    required String url,
  }) async {
    final texto = '🏪 Mira "$nombre" en Tranqui\n$url';

    // En web no hay selector: copiar directo
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: texto));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 Link copiado al portapapeles'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final accion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 12),
              Text(
                'Compartir "$nombre"',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _opcion(ctx, Icons.content_copy, Colors.blue, 'Copiar link',
                  'copiar'),
              _opcion(ctx, Icons.chat, const Color(0xFF25D366), 'WhatsApp',
                  'whatsapp'),
              _opcion(ctx, Icons.send, const Color(0xFF229ED9), 'Telegram',
                  'telegram'),
              _opcion(ctx, Icons.apps, Colors.grey.shade700, 'Otras apps...',
                  'otros'),
            ],
          ),
        ),
      ),
    );

    if (accion == null) return;

    switch (accion) {
      case 'copiar':
        await Clipboard.setData(ClipboardData(text: texto));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📋 Link copiado al portapapeles'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
      case 'whatsapp':
        await _launch('https://wa.me/?text=${Uri.encodeComponent(texto)}');
        break;
      case 'telegram':
        await _launch(
          'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent('🏪 Mira "$nombre" en Tranqui')}',
        );
        break;
      case 'otros':
        // Solo aquí se usa el selector del sistema (decisión del usuario)
        try {
          await Share.share(texto, subject: 'Negocio en Tranqui');
        } catch (_) {}
        break;
    }
  }

  static Widget _opcion(BuildContext ctx, IconData icono, Color color,
      String label, String valor) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icono, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => Navigator.pop(ctx, valor),
    );
  }

  static Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
