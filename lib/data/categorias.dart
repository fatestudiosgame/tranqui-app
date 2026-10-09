import 'package:flutter/material.dart';

class GrupoCategoria {
  final String id;
  final String nombre;
  final String icono;
  final String colorHex;
  final List<CategoriaNegocio> categorias;

  const GrupoCategoria({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.colorHex,
    required this.categorias,
  });
}

class CategoriaNegocio {
  final String id;
  final String nombre;
  final String icono;

  const CategoriaNegocio({
    required this.id,
    required this.nombre,
    required this.icono,
  });
}

const List<GrupoCategoria> gruposCategorias = [
  GrupoCategoria(
    id: 'comida',
    nombre: 'Comida',
    icono: 'restaurant',
    colorHex: 'FFD84315',
    categorias: [
      CategoriaNegocio(
          id: 'restaurante',
          nombre: 'Restaurante/Paladar',
          icono: 'restaurant'),
      CategoriaNegocio(
          id: 'cafeteria', nombre: 'Cafetería/Pizzería', icono: 'local_cafe'),
      CategoriaNegocio(
          id: 'bar', nombre: 'Bar/Centro Nocturno', icono: 'local_bar'),
      CategoriaNegocio(
          id: 'reposteria', nombre: 'Dulcería/Heladería', icono: 'cake'),
      CategoriaNegocio(
          id: 'elaborador_alimentos',
          nombre: 'Elaborador de Alimentos',
          icono: 'set_meal'),
    ],
  ),
  GrupoCategoria(
    id: 'compras',
    nombre: 'Compras',
    icono: 'storefront',
    colorHex: 'FF1976D2',
    categorias: [
      CategoriaNegocio(
          id: 'mercado', nombre: 'Mercado/Bodega/Tienda', icono: 'storefront'),
      CategoriaNegocio(
          id: 'ropa_calzado',
          nombre: 'Tienda de Ropa y calzado',
          icono: 'checkroom'),
      CategoriaNegocio(
          id: 'ferreteria',
          nombre: 'Ferretería y Construcción',
          icono: 'construction'),
      CategoriaNegocio(
          id: 'farmacia', nombre: 'Farmacia/Óptica', icono: 'local_pharmacy'),
      CategoriaNegocio(
          id: 'electronica',
          nombre: 'Tienda de Celulares y Electrónica',
          icono: 'smartphone'),
      CategoriaNegocio(id: 'papeleria', nombre: 'Librería', icono: 'school'),
    ],
  ),
  GrupoCategoria(
    id: 'belleza',
    nombre: 'Belleza',
    icono: 'content_cut',
    colorHex: 'FFEC407A',
    categorias: [
      CategoriaNegocio(
          id: 'peluqueria',
          nombre: 'Peluquería / Barbería',
          icono: 'content_cut'),
      CategoriaNegocio(
          id: 'salon_belleza',
          nombre: 'Salón de belleza / Uñas / Spa',
          icono: 'face'),
      CategoriaNegocio(
          id: 'tatuajes', nombre: 'Tatuajes / Piercings', icono: 'brush'),
    ],
  ),
  GrupoCategoria(
    id: 'talleres',
    nombre: 'Taller',
    icono: 'build',
    colorHex: 'FF616161',
    categorias: [
      CategoriaNegocio(
          id: 'taller_electronica',
          nombre: 'Electrónica/Celulares',
          icono: 'memory'),
      CategoriaNegocio(
          id: 'taller_mecanico',
          nombre: 'Mecánico/Chapista',
          icono: 'directions_car'),
      CategoriaNegocio(
          id: 'costura',
          nombre: 'Costura/Zapatería/Cerrajería',
          icono: 'handyman'),
    ],
  ),
  GrupoCategoria(
    id: 'ocio',
    nombre: 'Ocio',
    icono: 'sports_esports',
    colorHex: 'FF7B1FA2',
    categorias: [
      CategoriaNegocio(
          id: 'sala_juegos',
          nombre: 'Sala de Juegos/ Cine 3D',
          icono: 'sports_esports'),
      CategoriaNegocio(id: 'billar', nombre: 'Billar/Bolos', icono: 'pool'),
      CategoriaNegocio(id: 'piscina', nombre: 'Piscina', icono: 'pool'),
      CategoriaNegocio(
          id: 'eventos', nombre: 'Eventos/Fiestas', icono: 'celebration'),
    ],
  ),
  GrupoCategoria(
    id: 'salud',
    nombre: 'Salud',
    icono: 'health_and_safety',
    colorHex: 'FF2E7D32',
    categorias: [
      CategoriaNegocio(
          id: 'consulta_medica',
          nombre: 'Clinica/Dentista',
          icono: 'medical_services'),
      CategoriaNegocio(id: 'veterinaria', nombre: 'Veterinaria', icono: 'pets'),
    ],
  ),
  GrupoCategoria(
    id: 'transporte',
    nombre: 'Transporte',
    icono: 'local_taxi',
    colorHex: 'FFF9A825',
    categorias: [
      CategoriaNegocio(id: 'taxi', nombre: 'Taxi', icono: 'local_taxi'),
      CategoriaNegocio(
          id: 'transporte_provincial',
          nombre: 'Transporte Interprovincial',
          icono: 'directions_bus'),
      CategoriaNegocio(
          id: 'alquiler_vehiculos',
          nombre: 'Alquiler de Vehículos',
          icono: 'pedal_bike'),
    ],
  ),
  GrupoCategoria(
    id: 'servicios',
    nombre: 'Servicios',
    icono: 'work',
    colorHex: 'FF00695C',
    categorias: [
      CategoriaNegocio(
          id: 'fotografia',
          nombre: 'Fotografía/Diseño/Audiovisuales',
          icono: 'camera_alt'),
      CategoriaNegocio(
          id: 'gestoria', nombre: 'Gestor/Contador', icono: 'account_balance'),
      CategoriaNegocio(
          id: 'tutorias', nombre: 'Tutorías/Academia', icono: 'menu_book'),
      CategoriaNegocio(
          id: 'recargas',
          nombre: 'Recargas/Transfermóvil',
          icono: 'currency_exchange'),
    ],
  ),
];

const CategoriaNegocio categoriaOtros = CategoriaNegocio(
  id: 'otros',
  nombre: 'Otros servicios',
  icono: 'category',
);

CategoriaNegocio? buscarCategoriaPorId(String? id) {
  if (id == null || id.isEmpty) return null;
  if (id == 'otros') return categoriaOtros;
  for (final grupo in gruposCategorias) {
    for (final cat in grupo.categorias) {
      if (cat.id == id) return cat;
    }
  }
  return null;
}

GrupoCategoria? buscarGrupoDeCategoria(String? categoriaId) {
  if (categoriaId == null) return null;
  for (final grupo in gruposCategorias) {
    for (final cat in grupo.categorias) {
      if (cat.id == categoriaId) return grupo;
    }
  }
  return null;
}

List<CategoriaNegocio> todasLasCategorias() {
  final lista = <CategoriaNegocio>[];
  for (final grupo in gruposCategorias) {
    lista.addAll(grupo.categorias);
  }
  lista.add(categoriaOtros);
  return lista;
}

Map<String, dynamic> validarCategorias({
  required String? categoriaPrincipal,
  List<String>? categoriasSecundarias,
}) {
  if (categoriaPrincipal == null || categoriaPrincipal.isEmpty) {
    return {'valido': false, 'error': 'La categoría principal es obligatoria'};
  }
  if (buscarCategoriaPorId(categoriaPrincipal) == null) {
    return {
      'valido': false,
      'error': 'La categoría principal no existe: $categoriaPrincipal'
    };
  }
  final secundarias = categoriasSecundarias ?? [];
  if (secundarias.length > 2) {
    return {'valido': false, 'error': 'Máximo 2 categorías secundarias'};
  }
  final sinDuplicados = secundarias.toSet();
  if (sinDuplicados.length != secundarias.length) {
    return {'valido': false, 'error': 'Categorías secundarias repetidas'};
  }
  if (secundarias.contains(categoriaPrincipal)) {
    return {
      'valido': false,
      'error': 'La categoría principal no puede repetirse en secundarias'
    };
  }
  for (final sec in secundarias) {
    if (buscarCategoriaPorId(sec) == null) {
      return {'valido': false, 'error': 'Categoría secundaria no existe: $sec'};
    }
  }
  return {'valido': true};
}

const Map<String, IconData> _iconosDisponibles = {
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'local_bar': Icons.local_bar,
  'cake': Icons.cake,
  'set_meal': Icons.set_meal,
  'storefront': Icons.storefront,
  'checkroom': Icons.checkroom,
  'construction': Icons.construction,
  'local_pharmacy': Icons.local_pharmacy,
  'smartphone': Icons.smartphone,
  'school': Icons.school,
  'content_cut': Icons.content_cut,
  'face': Icons.face,
  'brush': Icons.brush,
  'build': Icons.build,
  'memory': Icons.memory,
  'directions_car': Icons.directions_car,
  'handyman': Icons.handyman,
  'sports_esports': Icons.sports_esports,
  'pool': Icons.pool,
  'celebration': Icons.celebration,
  'health_and_safety': Icons.health_and_safety,
  'medical_services': Icons.medical_services,
  'pets': Icons.pets,
  'local_taxi': Icons.local_taxi,
  'directions_bus': Icons.directions_bus,
  'pedal_bike': Icons.pedal_bike,
  'work': Icons.work,
  'camera_alt': Icons.camera_alt,
  'account_balance': Icons.account_balance,
  'menu_book': Icons.menu_book,
  'currency_exchange': Icons.currency_exchange,
  'category': Icons.category,
};

IconData obtenerIcono(String nombreIcono) {
  return _iconosDisponibles[nombreIcono] ?? Icons.category;
}

Color obtenerColorGrupo(String colorHex) {
  return Color(int.parse(colorHex, radix: 16));
}
