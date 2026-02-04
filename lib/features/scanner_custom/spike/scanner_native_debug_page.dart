// ═══════════════════════════════════════════════════════════════════════════
// SPIKE DEBUG - flutter_doc_scanner (scanner nativo actual)
// ═══════════════════════════════════════════════════════════════════════════
// Objetivo: Ver QUÉ retorna exactamente cada método
// Sin especulación - solo datos reales
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

class ScannerNativeDebugPage extends StatefulWidget {
  const ScannerNativeDebugPage({super.key});

  @override
  State<ScannerNativeDebugPage> createState() => _ScannerNativeDebugPageState();
}

class _ScannerNativeDebugPageState extends State<ScannerNativeDebugPage> {
  final _scanner = FlutterDocScanner();
  String _debugOutput = 'Toca un botón para probar...';
  bool _isScanning = false;

  Future<void> _testGenericMethod() async {
    setState(() {
      _isScanning = true;
      _debugOutput = '🔄 Probando getScanDocuments()...\n';
    });

    try {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🧪 TEST: getScanDocuments(page: 1)');
      debugPrint('═══════════════════════════════════════════════════');

      final result = await _scanner.getScanDocuments(page: 1);

      await _processResult(result, 'getScanDocuments()');
    } catch (e, stack) {
      debugPrint('❌ ERROR: $e');
      debugPrint('StackTrace: $stack');

      setState(() {
        _debugOutput = '❌ ERROR:\n\n$e\n\nStackTrace:\n$stack';
        _isScanning = false;
      });
    }
  }

  Future<void> _testImagesMethod() async {
    setState(() {
      _isScanning = true;
      _debugOutput = '🔄 Probando getScannedDocumentAsImages()...\n';
    });

    try {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🧪 TEST: getScannedDocumentAsImages(page: 1)');
      debugPrint('═══════════════════════════════════════════════════');

      final result = await _scanner.getScannedDocumentAsImages(page: 1);

      await _processResult(result, 'getScannedDocumentAsImages()');
    } catch (e, stack) {
      debugPrint('❌ ERROR: $e');
      debugPrint('StackTrace: $stack');

      setState(() {
        _debugOutput = '❌ ERROR:\n\n$e\n\nStackTrace:\n$stack';
        _isScanning = false;
      });
    }
  }

  Future<void> _testImagesDeepAnalysis() async {
    setState(() {
      _isScanning = true;
      _debugOutput = '🔄 Análisis profundo de JPG...\n';
    });

    try {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🧪 TEST: Análisis Profundo de JPG');
      debugPrint('═══════════════════════════════════════════════════');

      final result = await _scanner.getScannedDocumentAsImages(page: 1);

      if (result == null) {
        debugPrint('⚠️ Resultado NULL');
        setState(() {
          _debugOutput = '⚠️ Usuario canceló o error';
          _isScanning = false;
        });
        return;
      }

      // Buscar la lista de imágenes
      List<dynamic>? imageUris;
      if (result is Map) {
        imageUris = result['images'] as List<dynamic>?;
        imageUris ??= result['Uri'] as List<dynamic>?;
      }

      if (imageUris == null || imageUris.isEmpty) {
        debugPrint('❌ No se encontraron imágenes en el resultado');
        setState(() {
          _debugOutput = '❌ No se encontraron imágenes';
          _isScanning = false;
        });
        return;
      }

      final imageUri = imageUris.first.toString();

      print('\n');
      print('═══════════════════════════════════════════════════');
      print('ANÁLISIS PROFUNDO JPG - COPIAR DESDE AQUÍ');
      print('═══════════════════════════════════════════════════');
      print('');
      print('📸 URI Original: $imageUri');
      debugPrint('📸 URI Original: $imageUri');

      String output = '📸 ANÁLISIS PROFUNDO JPG\n';
      output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
      output += 'URI Original:\n$imageUri\n\n';

      // Intentar parsear el URI
      File imageFile;
      String filePath = '';
      bool exists = false;

      // Método 1: Quitar prefijo file://
      if (imageUri.startsWith('file://')) {
        filePath = imageUri.substring(7); // Quitar "file://"
        imageFile = File(filePath);
        print('📂 Path (sin file://): $filePath');
        debugPrint('📂 Path (sin file://): $filePath');
        output += 'Path (sin file://):\n$filePath\n\n';
      } else {
        imageFile = File(imageUri);
        filePath = imageUri;
        print('📂 Path directo: $filePath');
        debugPrint('📂 Path directo: $filePath');
        output += 'Path directo:\n$filePath\n\n';
      }

      // Verificar existencia
      exists = await imageFile.exists();
      print('✅ ¿Archivo existe?: $exists');
      debugPrint('✅ ¿Archivo existe?: $exists');
      output += '¿Existe?: $exists\n\n';

      if (!exists) {
        // Intentar método alternativo con Uri.parse
        try {
          final uri = Uri.parse(imageUri);
          final alternativePath = uri.toFilePath();
          final alternativeFile = File(alternativePath);
          final alternativeExists = await alternativeFile.exists();

          print('🔄 Path alternativo (Uri.toFilePath): $alternativePath');
          print('✅ ¿Existe (alternativo)?: $alternativeExists');
          debugPrint('🔄 Intento alternativo: $alternativePath');
          debugPrint('✅ ¿Existe (alternativo)?: $alternativeExists');

          output += 'Path alternativo:\n$alternativePath\n';
          output += '¿Existe (alternativo)?: $alternativeExists\n\n';

          if (alternativeExists) {
            imageFile = alternativeFile;
            filePath = alternativePath;
            exists = true;
          }
        } catch (e) {
          print('⚠️ Error parseando URI: $e');
          debugPrint('⚠️ Error parseando URI: $e');
          output += '⚠️ Error parseando URI: $e\n\n';
        }
      }

      // Si el archivo existe, analizar
      if (exists) {
        final size = await imageFile.length();
        final sizeMB = (size / 1024 / 1024).toStringAsFixed(2);
        final sizeKB = (size / 1024).toStringAsFixed(2);

        print('');
        print('📊 INFORMACIÓN DEL ARCHIVO:');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Tamaño: $sizeMB MB ($sizeKB KB)');
        print('Bytes: $size');
        debugPrint('📊 Tamaño: $sizeMB MB');
        debugPrint('📊 Bytes: $size');

        output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
        output += 'ARCHIVO ENCONTRADO ✅\n';
        output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
        output += 'Tamaño: $sizeMB MB ($sizeKB KB)\n';
        output += 'Bytes: $size\n\n';

        // Leer primeros bytes para verificar tipo
        final bytes = await imageFile.readAsBytes();
        final firstBytes = bytes.take(10).toList();
        final hexBytes = firstBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

        print('Primeros 10 bytes (hex): $hexBytes');
        debugPrint('📊 Primeros bytes: $hexBytes');
        output += 'Primeros 10 bytes (hex):\n$hexBytes\n\n';

        // Verificar signature JPG (FF D8 FF)
        if (firstBytes.length >= 3 &&
            firstBytes[0] == 0xFF &&
            firstBytes[1] == 0xD8 &&
            firstBytes[2] == 0xFF) {
          print('✅ CONFIRMADO: Es un archivo JPG válido');
          debugPrint('✅ CONFIRMADO: JPG válido');
          output += '✅ CONFIRMADO: JPG VÁLIDO\n\n';
        } else {
          print('⚠️ Advertencia: Firma de JPG no detectada');
          debugPrint('⚠️ Firma JPG no detectada');
          output += '⚠️ Firma JPG no detectada\n\n';
        }

        // Conclusión para OCR
        print('');
        print('🎯 CONCLUSIÓN PARA OCR:');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        if (size > 500000) { // > 500KB
          print('✅ Tamaño adecuado para OCR de alta calidad');
          output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
          output += '🎯 CONCLUSIÓN:\n';
          output += '✅ Tamaño adecuado para OCR\n';
          output += '✅ Archivo accesible\n';
          output += '✅ Listo para ML Kit OCR\n';
        } else {
          print('⚠️ Tamaño pequeño - verificar calidad');
          output += '⚠️ Tamaño pequeño - verificar calidad\n';
        }
        print('✅ Archivo accesible para procesamiento');
        print('✅ Listo para usar con ML Kit OCR');
      } else {
        print('');
        print('❌ ARCHIVO NO ENCONTRADO');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('El archivo puede ser temporal y fue eliminado');
        debugPrint('❌ Archivo no encontrado después de intentos');

        output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
        output += '❌ ARCHIVO NO ENCONTRADO\n';
        output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
        output += 'Puede ser temporal y fue eliminado\n';
      }

      print('');
      print('═══════════════════════════════════════════════════');
      print('FIN ANÁLISIS - COPIAR HASTA AQUÍ');
      print('═══════════════════════════════════════════════════');
      print('\n');

      setState(() {
        _debugOutput = output;
        _isScanning = false;
      });
    } catch (e, stack) {
      debugPrint('❌ ERROR: $e');
      debugPrint('StackTrace: $stack');
      print('❌ ERROR: $e');

      setState(() {
        _debugOutput = '❌ ERROR:\n\n$e\n\nStackTrace:\n$stack';
        _isScanning = false;
      });
    }
  }

  Future<void> _processResult(dynamic result, String methodName) async {
    try {

      // Print para copiar fácilmente
      print('\n');
      print('═══════════════════════════════════════════════════');
      print('RESULTADO $methodName - COPIAR DESDE AQUÍ');
      print('═══════════════════════════════════════════════════');
      print('');

      debugPrint('✅ Scanner cerrado, procesando resultado...');
      debugPrint('');
      debugPrint('📊 ANÁLISIS DEL RESULTADO:');
      debugPrint('─────────────────────────────────────────────────');
      debugPrint('Tipo: ${result.runtimeType}');
      debugPrint('Null: ${result == null}');
      debugPrint('Contenido toString(): ${result.toString()}');
      debugPrint('');

      // Print para copiar
      print('Tipo: ${result.runtimeType}');
      print('Es null: ${result == null}');
      print('');

      String output = '✅ $methodName completado\n\n';
      output += '📊 RESULTADO:\n';
      output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
      output += 'Tipo: ${result.runtimeType}\n';
      output += 'Es null: ${result == null}\n\n';

      if (result == null) {
        debugPrint('⚠️ Resultado es NULL (usuario canceló o error)');
        print('⚠️ NULL (cancelado o error)');
        output += '⚠️ NULL (cancelado o error)\n';
      } else if (result is Map) {
        debugPrint('📦 Es un Map:');
        debugPrint('Keys: ${result.keys.toList()}');
        debugPrint('');

        // Print para copiar
        print('📦 Es un Map');
        print('Keys: ${result.keys.toList()}');
        print('');

        output += '📦 Es un Map\n';
        output += 'Keys: ${result.keys.toList()}\n\n';

        for (var key in result.keys) {
          final value = result[key];
          debugPrint('  [$key]:');
          debugPrint('    - Tipo: ${value.runtimeType}');
          debugPrint('    - Valor: $value');

          // Print para copiar
          print('[$key]:');
          print('  Tipo: ${value.runtimeType}');
          print('  Valor: $value');

          output += '[$key]:\n';
          output += '  Tipo: ${value.runtimeType}\n';
          output += '  Valor: $value\n\n';

          if (value is List) {
            debugPrint('    - Lista con ${value.length} elementos');
            print('  Lista con ${value.length} elementos:');
            for (var i = 0; i < value.length; i++) {
              debugPrint('      [$i]: ${value[i]}');
              print('    [$i]: ${value[i]}');
              output += '  [$i]: ${value[i]}\n';
            }
          }
          debugPrint('');
          print('');
        }

        // Verificar si hay archivos
        await _checkFiles(result);
      } else if (result is List) {
        debugPrint('📦 Es una Lista:');
        debugPrint('Longitud: ${result.length}');
        debugPrint('');

        // Print para copiar
        print('📦 Es una Lista');
        print('Longitud: ${result.length}');
        print('');

        output += '📦 Es una Lista\n';
        output += 'Longitud: ${result.length}\n\n';

        for (var i = 0; i < result.length; i++) {
          debugPrint('  [$i]: ${result[i]} (${result[i].runtimeType})');
          print('[$i]: ${result[i]} (${result[i].runtimeType})');
          output += '[$i]: ${result[i]}\n';

          // Si es un path, verificar archivo
          if (result[i] is String &&
              (result[i].contains('/') || result[i].contains('\\'))) {
            final file = File(result[i]);
            final exists = await file.exists();
            if (exists) {
              final size = await file.length();
              final sizeMB = (size / 1024 / 1024).toStringAsFixed(2);
              debugPrint('     ¿Existe?: $exists, Tamaño: $sizeMB MB');
              print('     ¿Existe?: $exists, Tamaño: $sizeMB MB');
              output += '     ¿Existe?: $exists, Tamaño: $sizeMB MB\n';
            }
          }
        }
      } else if (result is String) {
        debugPrint('📦 Es un String:');
        debugPrint('Contenido: $result');
        debugPrint('');

        // Print para copiar
        print('📦 Es un String');
        print('Contenido: $result');

        output += '📦 Es un String\n';
        output += 'Contenido: $result\n';

        // Si es un path, verificar archivo
        if (result.contains('/') || result.contains('\\')) {
          final file = File(result);
          final exists = await file.exists();
          debugPrint('¿Archivo existe?: $exists');
          print('¿Archivo existe?: $exists');
          output += '¿Archivo existe?: $exists\n';

          if (exists) {
            final size = await file.length();
            final sizeMB = (size / 1024 / 1024).toStringAsFixed(2);
            debugPrint('Tamaño: $sizeMB MB');
            print('Tamaño: $sizeMB MB');
            output += 'Tamaño: $sizeMB MB\n';
          }
        }
      } else {
        debugPrint('📦 Tipo desconocido');
        print('📦 Tipo desconocido');
        output += '📦 Tipo desconocido\n';
      }

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('');

      // Footer del print para copiar
      print('');
      print('═══════════════════════════════════════════════════');
      print('FIN RESULTADO - COPIAR HASTA AQUÍ');
      print('═══════════════════════════════════════════════════');
      print('\n');

      setState(() {
        _debugOutput = output;
        _isScanning = false;
      });
    } catch (e, stack) {
      debugPrint('❌ ERROR: $e');
      debugPrint('StackTrace: $stack');

      setState(() {
        _debugOutput = '❌ ERROR:\n\n$e\n\nStackTrace:\n$stack';
        _isScanning = false;
      });
    }
  }

  Future<void> _checkFiles(Map result) async {
    // Buscar paths de archivos en el resultado
    for (var key in result.keys) {
      final value = result[key];

      if (value is String && (value.contains('/') || value.contains('\\'))) {
        debugPrint('🔍 Verificando archivo: $value');
        final file = File(value);
        final exists = await file.exists();
        debugPrint('   ¿Existe?: $exists');

        if (exists) {
          final size = await file.length();
          debugPrint('   Tamaño: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');

          // Detectar tipo por extensión
          final extension = value.split('.').last.toLowerCase();
          debugPrint('   Extensión: $extension');
        }
      }

      if (value is List) {
        for (var item in value) {
          if (item is String && (item.contains('/') || item.contains('\\'))) {
            debugPrint('🔍 Verificando archivo en lista: $item');
            final file = File(item);
            final exists = await file.exists();
            debugPrint('   ¿Existe?: $exists');

            if (exists) {
              final size = await file.length();
              debugPrint('   Tamaño: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');

              final extension = item.split('.').last.toLowerCase();
              debugPrint('   Extensión: $extension');
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('🧪 DEBUG: flutter_doc_scanner'),
        backgroundColor: Colors.blue[900],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue[800],
              child: const Text(
                'Objetivo: Ver QUÉ retorna cada método\nResultados en consola listos para copiar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Botones de test
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _testGenericMethod,
                      icon: const Icon(Icons.science),
                      label: const Text(
                        'TEST 1: getScanDocuments()',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _testImagesMethod,
                      icon: const Icon(Icons.image),
                      label: const Text(
                        'TEST 2: getScannedDocumentAsImages()',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _testImagesDeepAnalysis,
                      icon: const Icon(Icons.analytics),
                      label: const Text(
                        'TEST 3: Análisis Profundo JPG 🎯',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'TEST 3 = Análisis completo para OCR',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Debug output
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[700]!),
                ),
                child: SingleChildScrollView(
                  child: _isScanning
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.blue),
                              SizedBox(height: 16),
                              Text(
                                'Escaneando...\nRevisa los logs en consola',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Text(
                          _debugOutput,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.greenAccent,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
