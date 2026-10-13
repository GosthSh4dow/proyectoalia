import 'dart:convert'; // Para jsonEncode/jsonDecode
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class PrinterSettings extends StatefulWidget {
  final VoidCallback onClose;
  const PrinterSettings({Key? key, required this.onClose}) : super(key: key);

  @override
  _PrinterSettingsState createState() => _PrinterSettingsState();
}

class _PrinterSettingsState extends State<PrinterSettings> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _urlController = TextEditingController();
  String _printerType = 'epson';
  bool _enabled = true;
  bool _loading = false;
  bool _testLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Carga la configuración; si no existe, la guarda con los valores por defecto (solo una vez)
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('printerSettings')) {
      String? settingsJson = prefs.getString('printerSettings');
      if (settingsJson != null) {
        final settings = jsonDecode(settingsJson);
        setState(() {
          _urlController.text = settings['printerHost'] ?? "http://127.0.0.1:8009/";
          _printerType = settings['printerType'] ?? "epson";
          _enabled = settings['enabled'] ?? true;
        });
      }
        } else {
      // Guardar configuración por defecto (solo una vez)
      setState(() {
        _urlController.text = "http://127.0.0.1:8009/";
        _printerType = "epson";
        _enabled = true;
      });
      await prefs.setString('printerSettings', jsonEncode({
           'printerHost': "http://127.0.0.1:8009/",
           'printerType': "epson",
           'enabled': true,
      }));
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; });
    final prefs = await SharedPreferences.getInstance();
    final settings = {
       'printerHost': _urlController.text.trim(),
       'printerType': _printerType,
       'enabled': _enabled,
    };
    await prefs.setString('printerSettings', jsonEncode(settings));
    setState(() { _loading = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Configuración de impresora guardada correctamente"))
    );
    widget.onClose();
  }

  Future<void> _testPrint() async {
    setState(() { _testLoading = true; });
    final url = _urlController.text.trim();
    // Ejemplo de contenido de prueba
    String testContent = "\x1B\x40" +
      "PRUEBA DE IMPRESIÓN\n" +
      "---------------------\n" +
      "Fecha: ${DateTime.now().toLocal()}\n" +
      "---------------------\n\n";
    try {
      final response = await Dio().post(url, data: {'conteudo': testContent});
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Prueba de impresión enviada correctamente"))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error en la prueba de impresión"))
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de conexión: ${error.toString()}"))
      );
    } finally {
      setState(() { _testLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Configuración de Impresora"),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: widget.onClose,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: "URL de la Impresora",
                  hintText: "http://127.0.0.1:8009/",
                ),
                keyboardType: TextInputType.url,
                validator: (val) {
                  if (val == null || val.isEmpty) return "Ingrese la URL";
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _printerType,
                decoration: InputDecoration(labelText: "Tipo de Impresora"),
                items: [
                  DropdownMenuItem(child: Text("Epson"), value:"epson"),
                  DropdownMenuItem(child: Text("Impresora Térmica"), value:"thermal"),
                  DropdownMenuItem(child: Text("HP"), value:"hp"),
                  DropdownMenuItem(child: Text("Otra"), value:"other"),
                ],
                onChanged: (val) {
                  if (val != null) setState(() { _printerType = val; });
                },
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text("Impresión Habilitada"),
                value: _enabled,
                onChanged: (val) { setState(() { _enabled = val; }); },
              ),
              Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _testLoading ? null : _testPrint,
                    icon: Icon(Icons.print),
                    label: _testLoading ? Text("Probando...") : Text("Prueba de Impresión")
                  ),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _saveSettings,
                    icon: Icon(Icons.save),
                    label: _loading ? Text("Guardando...") : Text("Guardar")
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
