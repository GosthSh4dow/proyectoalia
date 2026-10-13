import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api.dart'; // Se utiliza API_BASE_URL

class ConvertedComponentScreen extends StatefulWidget {
  const ConvertedComponentScreen({Key? key}) : super(key: key);

  @override
  _ConvertedComponentScreenState createState() => _ConvertedComponentScreenState();
}

class _ConvertedComponentScreenState extends State<ConvertedComponentScreen> {
  // ...variables de estado y controladores...
  bool _isLoading = false;
  List<dynamic> _data = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Ejemplo de llamada al API similar a usuarios_pages.dart
  Future<void> _fetchData() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(Uri.parse('$API_BASE_URL/endpoint'));
      if (response.statusCode == 200) {
        setState(() {
          _data = json.decode(response.body);
        });
      } else {
        // Manejar error
        debugPrint('Error en la llamada al API: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Excepción en el API: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Converted Component"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _data.length,
              itemBuilder: (context, index) {
                // ...Diseño similar al de usuarios_pages.dart...
                final item = _data[index];
                return ListTile(
                  title: Text(item['title'] ?? 'Item'),
                  subtitle: Text(item['description'] ?? 'Descripción'),
                  onTap: () {
                    // ...acción cuando se selecciona el item...
                  },
                );
              },
            ),
    );
  }
}
