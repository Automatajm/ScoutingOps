import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pote_model.dart';

class PoteService {
  final String baseUrl;

  PoteService({required this.baseUrl});

  // Obtener todos los potes
  Future<List<Pote>> getPotes({
    String? busqueda,
    String? estatus,
    String? contenedor,
  }) async {
    final Map<String, String> queryParams = {};

    if (busqueda != null) queryParams['busqueda'] = busqueda;
    if (estatus != null) queryParams['estatus'] = estatus;
    if (contenedor != null) queryParams['contenedor'] = contenedor;

    final uri = Uri.parse('$baseUrl/api/potes')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Pote.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar potes: ${response.statusCode}');
    }
  }

  // Obtener un pote por ID
  Future<Pote> getPoteById(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/potes/$id'),
    );

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);
      return Pote.fromJson(data);
    } else {
      throw Exception('Error al cargar el pote: ${response.statusCode}');
    }
  }

  // Crear un nuevo pote
  Future<int> createPote(Pote pote) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/potes'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(pote.toJson()),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al crear pote: ${response.statusCode}');
    }
  }

  // Actualizar un pote existente
  Future<bool> updatePote(Pote pote) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/potes/${pote.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(pote.toJson()),
    );

    return response.statusCode == 200;
  }

  // Eliminar un pote
  Future<bool> deletePote(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/potes/$id'),
    );

    return response.statusCode == 200;
  }
}
