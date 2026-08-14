class Anuncio {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String buttonText;
  final String onClickUrl;

  Anuncio({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onClickUrl,
  });

  // ⭐ Factory para crear desde JSON
  factory Anuncio.fromJson(Map<String, dynamic> json) {
    return Anuncio(
      id: json['id'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      buttonText: json['buttonText'] ?? 'Ver ahora',
      onClickUrl: json['onClickUrl'] ?? '',
    );
  }

  // ⭐ Para convertir a JSON (opcional, por si necesitas guardar)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'buttonText': buttonText,
      'onClickUrl': onClickUrl,
    };
  }
}
