import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/config/flavor_config.dart';

class ConfigurationScreen extends StatefulWidget {
  final ApiConfig apiConfig;
  final VoidCallback onConfigSuccess;

  const ConfigurationScreen({
    Key? key,
    required this.apiConfig,
    required this.onConfigSuccess,
  }) : super(key: key);

  @override
  _ConfigurationScreenState createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  final _dio = Dio();

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.apiConfig.apiUrl.replaceAll('/api', '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final customUrl = _urlController.text.trim();

      // Asegurarse de que la URL tenga el formato correcto
      String baseUrl = customUrl;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        baseUrl = 'http://$baseUrl';
      }

      // Intentar obtener la configuración del servidor
      final response = await _dio.get(
        '$baseUrl/api/config',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Actualizar la URL en la configuración
        String apiUrlBase = response.data['apiUrl'] ?? baseUrl;
        if (!apiUrlBase.endsWith('/api')) {
          apiUrlBase = '$apiUrlBase/api';
        }

        await widget.apiConfig.updateApiUrl(apiUrlBase);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conexión exitosa')),
        );

        widget.onConfigSuccess();
      } else {
        setState(() {
          _errorMessage = 'El servidor no respondió correctamente';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            _errorMessage =
                'Tiempo de espera agotado al conectar con el servidor';
          } else if (e.type == DioExceptionType.connectionError) {
            _errorMessage =
                'No se pudo conectar al servidor. Verifica la URL e inténtalo de nuevo.';
          } else {
            _errorMessage = 'Error de conexión: ${e.message}';
          }
        } else {
          _errorMessage = 'Error inesperado: $e';
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del servidor'),
        backgroundColor: const Color(0xFF49B8E2),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo de la aplicación
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png', // Asegúrate que este archivo exista
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Costa Analytics',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF49B8E2),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Configuración de conexión al servidor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              const Text(
                'Ingresa la dirección del servidor para conectar la aplicación:',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL del servidor',
                  hintText: 'https://tu-servidor.com',
                  prefixIcon: const Icon(Icons.link, color: Color(0xFF49B8E2)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF49B8E2)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa una URL';
                  }

                  // Validación básica de URL
                  String url = value;
                  if (!url.startsWith('http://') &&
                      !url.startsWith('https://')) {
                    url = 'http://$url';
                  }

                  try {
                    Uri.parse(url);
                    return null;
                  } catch (e) {
                    return 'URL inválida';
                  }
                },
              ),

              const SizedBox(height: 16),

              // Mensaje de error
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red.shade900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // Botón de prueba
              ElevatedButton(
                onPressed: _isLoading ? null : _testConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF49B8E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Probar y guardar configuración',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // Instrucciones adicionales
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instrucciones:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Ingresa la URL completa del servidor incluyendo http:// o https://',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '2. Si estás conectado a WiFi local, puedes usar la IP local del servidor.',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '3. Para conexiones remotas, usa la URL pública del servidor.',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '4. Presiona "Probar y guardar" para verificar la conexión.',
                        style: TextStyle(fontSize: 14),
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
