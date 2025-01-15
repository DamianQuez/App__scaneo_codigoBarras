import 'package:flutter/material.dart';
import 'package:dynamsoft_capture_vision_flutter/dynamsoft_capture_vision_flutter.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  const String licenseKey = 't0085pwAAALJbGVyNjR71Zrnu30IDAFzSUq9wXrKJ0tjp6b2F+vsRSkLHP5punoPaG4rKZeAdzfbNSrVoHgflTc488n+iXcrUq5jH8v7xR5tF66YHKbkhvA==;t0088pwAAAGJXjPOQOm/S0+h2nmo86bRgqTrcw5u02Lpl3ETwjnUCYIWYnld/9BUEl4AKlSjMW9dcYQFu5I1vqwZvT5US6NXtRF9N6jyW74+/tJrXZnoALjQhvA==';
  try {
    await DCVBarcodeReader.initLicense(licenseKey);
  } catch (e) {
    print("Error al inicializar la licencia: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lector de Códigos de Barras',
      theme: ThemeData(
        primaryColor: const Color(0xFF4CA2E4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CA2E4),
        ),
      ),
      home: const HomePage(),
    );
  }
}

//Pantalla de Inicio
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
      ),
      body: Container(
        color: const Color(0xFF4CA2E4), 
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Logo
              Image.asset(
                'assets/logo_inventarios.png',
                width: 120,
                height: 120,
              ),

              const SizedBox(height: 20),

              
              Text(
                'Inventario Automático',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 5.0,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // comenzar_escaneo
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4CA2E4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 30,
                  ),
                  elevation: 10,
                  shadowColor: Colors.black45,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScanPage()),
                  );
                },
                child: const Text(
                  'Comenzar Escaneo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              // Revisar Inventario
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4CA2E4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 30,
                  ),
                  elevation: 10,
                  shadowColor: Colors.black45,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PaginaListaInventarios(),
                    ),
                  );
                },
                child: const Text(
                  'Revisar Inventario',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  Pantalla de Escaneo
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final DCVBarcodeReader _barcodeReader;
  late final DCVCameraEnhancer _cameraEnhancer;
  final DCVCameraView _cameraView = DCVCameraView();
  List<Map<String, String>> _decodeResults = [];

  @override
  void initState() {
    super.initState();
    _configDBR();
  }

  @override
  void dispose() {
    _cameraEnhancer.close();
    _barcodeReader.stopScanning();
    super.dispose();
  }

  Set<String> _scannedCodes = {}; // evitar duplicados

  Future<void> _configDBR() async {
    _barcodeReader = await DCVBarcodeReader.createInstance();
    _cameraEnhancer = await DCVCameraEnhancer.createInstance();
    _cameraView.overlayVisible = true;

    // formatos de código de barras
    DBRRuntimeSettings settings = await _barcodeReader.getRuntimeSettings();
    settings.barcodeFormatIds = EnumBarcodeFormat.BF_ALL;
    await _barcodeReader.updateRuntimeSettings(settings);

    _barcodeReader.receiveResultStream().listen((List<BarcodeResult>? res) async {
      if (res != null && res.isNotEmpty) {
        for (var result in res) {
          if (result.barcodeText != null) {
            String barcode = result.barcodeText!;

            // Veerificar codigo escaneado
            if (!_scannedCodes.contains(barcode)) {
              _scannedCodes.add(barcode); 

              
              var productInfo = await _fetchProductInfo(barcode);
              setState(() {
                _decodeResults.add({
                  'format': result.barcodeFormatString ?? 'Desconocido',
                  'barcode': barcode,
                  'product': productInfo?['title'] ?? 'Desconocido',
                  'brand': productInfo?['brand'] ?? 'Desconocido',
                });
              });
            }
          }
        }
      }
    });

    await _cameraEnhancer.open();
    _barcodeReader.startScanning();
  }




  

  Future<Map<String, dynamic>?> _fetchProductInfo(String barcode) async {
    try {
      // 1️⃣ Primera consulta: UPCitemdb
      final upcItemDbUrl = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
      final upcResponse = await http.get(upcItemDbUrl);

      if (upcResponse.statusCode == 200) {
        var upcData = jsonDecode(upcResponse.body);
        if (upcData['items'] != null && upcData['items'].isNotEmpty) {
          return {
            'title': upcData['items'][0]['title'] ?? 'Desconocido',
            'brand': upcData['items'][0]['brand'] ?? 'Desconocida',
          };
        }
      }

      
      final goUpcUrl = Uri.parse('https://go-upc.com/api/v1/code/$barcode');
      final goUpcResponse = await http.get(
        goUpcUrl,
        headers: {
          'Authorization': 'Bearer 744155a8e5ba55dc47eb31bbc066591e0767c63f063b6c2765fb88e670d34f62', // Reemplaza TU_API_KEY con tu clave de API de Go-UPC
        },
      );

      if (goUpcResponse.statusCode == 200) {
        var goUpcData = jsonDecode(goUpcResponse.body);
        if (goUpcData['product'] != null) {
          return {
            'title': goUpcData['product']['name'] ?? 'Desconocido',
            'brand': goUpcData['product']['brand'] ?? 'Desconocida',
          };
        }
      }

      return {'title': 'Producto no encontrado', 'brand': 'N/A'};

    } catch (e) {
    
      return {'title': 'Error al buscar producto', 'brand': 'N/A'};
    }
  }






  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escaneo en Tiempo Real'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _cameraView,
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            bottom: 80,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: ListView.builder(
                itemCount: _decodeResults.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      _decodeResults[index]['format'] ?? 'Formato desconocido',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _decodeResults[index]['barcode'] ?? 'Código no disponible',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultsPage(results: _decodeResults),
                  ),
                );
              },
              child: const Text('Mostrar Resultados'),
            ),
          ),
        ],
      ),
    );
  }
}

//Pantalla de Inventarios Creados
class PaginaListaInventarios extends StatefulWidget {
  const PaginaListaInventarios({super.key});

  @override
  _PaginaListaInventariosState createState() => _PaginaListaInventariosState();
}

class _PaginaListaInventariosState extends State<PaginaListaInventarios> {
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    var directory = await getApplicationDocumentsDirectory();
    var files = Directory(directory.path).listSync().where((file) {
      return file.path.endsWith('.xlsx');
    }).toList();

    setState(() {
      _files = files;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivos de Inventario'),
      ),
      body: _files.isEmpty
          ? const Center(
              child: Text('No se encontraron archivos de inventario.'),
            )
          : ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                String fileName = _files[index].path.split('/').last;
                return ListTile(
                  title: Text(fileName),
                  onTap: () async {
                    await OpenFilex.open(_files[index].path);
                  },
                );
              },
            ),
    );
  }
}


// Pantalla de Resultados Escaneados
class ResultsPage extends StatefulWidget {
  final List<Map<String, String>> results;

  const ResultsPage({super.key, required this.results});

  @override
  _ResultsPageState createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  
  final Map<String, int> _quantities = {};

  Future<void> _exportToNewExcel(BuildContext context) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      
      sheetObject.appendRow(['Formato', 'Código', 'Producto', 'Marca', 'Cantidad']);

      for (var result in widget.results) {
        int quantity = _quantities[result['barcode']] ?? 0;
        sheetObject.appendRow([
          result['format'],
          result['barcode'],
          result['product'] ?? 'Desconocido',
          result['brand'] ?? 'Desconocida',
          quantity,
        ]);
      }

      
      final fileName = await _getFileName();
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = "${directory.path}/$fileName";

      // Guardar archivo
      File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo guardado en: $outputPath')),
      );

      await OpenFilex.open(outputPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el archivo: $e')),
      );
    }
  }


  Future<void> _addToExistingExcel(BuildContext context) async {
    final directory = await getApplicationDocumentsDirectory();
    final files = Directory(directory.path).listSync().where((file) {
      return file.path.endsWith('.xlsx');
    }).toList();

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron archivos existentes.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecciona un archivo'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                String fileName = files[index].path.split('/').last;
                return ListTile(
                  title: Text(fileName),
                  onTap: () async {
                    File file = File(files[index].path);
                    var bytes = file.readAsBytesSync();
                    var excel = Excel.decodeBytes(bytes);

                    Sheet sheetObject = excel['Sheet1'];
                    Set<String> existingCodes = {};

                    // Leer los códigos existentes en el archivo
                    for (var row in sheetObject.rows) {
                      if (row.isNotEmpty && row[1] != null) {
                        existingCodes.add(row[1]!.value.toString());
                      }
                    }

                    int initialRowCount = sheetObject.rows.length;

                    // Agregar los nuevos resultados junto con la cantidad
                    for (var result in widget.results) {
                      if (!existingCodes.contains(result['barcode'])) {
                        int quantity = _quantities[result['barcode']] ?? 0;
                        sheetObject.appendRow([
                          result['format'],
                          result['barcode'],
                          result['product'] ?? 'Desconocido',
                          result['brand'] ?? 'Desconocida',
                          quantity,
                        ]);
                        existingCodes.add(result['barcode']!);
                      }
                    }

                    // Guardar el archivo solo si hay cambios
                    if (sheetObject.rows.length > initialRowCount) {
                      file
                        ..createSync(recursive: true)
                        ..writeAsBytesSync(excel.encode()!);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Datos agregados a: $fileName')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No se agregaron nuevos datos, todos ya existen.')),
                      );
                    }

                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados Escaneados'),
      ),
      body: ListView.builder(
        itemCount: widget.results.length,
        itemBuilder: (context, index) {
          var result = widget.results[index];
          String barcode = result['barcode'] ?? 'No disponible';

          return ListTile(
            title: Text(result['product'] ?? 'Producto desconocido'),
            subtitle: Text(
              'Marca: ${result['brand'] ?? 'Desconocida'}\nCódigo: $barcode',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showQuantityDialog(barcode);
              },
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _exportToNewExcel(context),
            label: const Text('Exportar a Nuevo Archivo'),
            icon: const Icon(Icons.save),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: () => _addToExistingExcel(context),
            label: const Text('Agregar al Archivo Existente'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  
  void _showQuantityDialog(String barcode) {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Ingresar cantidad para $barcode'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              hintText: 'Ingresa un número',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                int? quantity = int.tryParse(controller.text);
                if (quantity != null) {
                  setState(() {
                    _quantities[barcode] = quantity;
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  // Método para generar el nombre dinámico del archivo
  Future<String> _getFileName() async {
    final directory = await getApplicationDocumentsDirectory();
    final existingFiles = Directory(directory.path).listSync().where((file) {
      return file.path.endsWith('.xlsx');
    }).toList();

    int highestNumber = 0;
    for (var file in existingFiles) {
      final fileName = file.path.split('/').last;
      final match = RegExp(r'Inventario (\d+)').firstMatch(fileName);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (number > highestNumber) {
          highestNumber = number;
        }
      }
    }

    final nextNumber = highestNumber + 1;
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);

    return 'Inventario $nextNumber $formattedDate.xlsx';
  }
}
