import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {
  final String versionName;
  final List<String> releaseNotes;
  final String downloadUrl;

  const UpdateDialog({
    super.key,
    required this.versionName,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  Future<void> _download() async {
    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update_alt, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            // ⬅️ Solución al overflow
            child: Text(
              'Nueva versión $versionName',
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novedades:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...releaseNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      // ⬅️ También en las notas para evitar overflow
                      child: Text(note),
                    ),
                  ],
                ),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Después'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            _download();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.download),
          label: const Text('Descargar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
