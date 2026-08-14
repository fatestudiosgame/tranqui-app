import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/anuncio.dart';
import '../data/anuncios.dart' as localAds;

class AdService {
  // ⭐ CAMBIA ESTA URL por la de tu archivo ads.json en Dropbox (con ?dl=1)
  static const String adUrl =
      'https://www.dropbox.com/scl/fi/vj9vnawv85ap490klc7qr/ads.json?rlkey=mwgp51bjgcbjlnjyill5o0trj&dl=1';
  static const Duration timeout = Duration(seconds: 5);

  static Future<List<Anuncio>> loadAds() async {
    // 1. Verificar conectividad
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('📡 Sin internet - No se muestran anuncios');
      return []; // ⬅️ Devuelve lista vacía si no hay internet
    }

    try {
      print('📡 Cargando anuncios desde: $adUrl');

      final response = await http.get(Uri.parse(adUrl)).timeout(timeout);

      if (response.statusCode == 200) {
        final String jsonString = utf8.decode(response.bodyBytes);
        final List data = jsonDecode(jsonString);
        final ads = data.map((e) => Anuncio.fromJson(e)).toList();
        print('✅ Anuncios cargados desde red: ${ads.length}');
        return ads;
      } else {
        print('⚠️ Error al descargar anuncios: ${response.statusCode}');
        return []; // ⬅️ Si falla, no mostrar nada
      }
    } on TimeoutException {
      print('⏰ Tiempo de espera agotado al cargar anuncios');
      return [];
    } catch (e) {
      print('❌ Error cargando anuncios: $e');
      return [];
    }
  }
}
