import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart'; // For extracting .zip files
import 'package:qr_flutter/qr_flutter.dart'; // For generating QR Code
import 'package:shared_preferences/shared_preferences.dart'; // For shared preferences

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Malinlink Pass Wallet',
      theme: ThemeData(
        primaryColor: const Color(0xFF2A306C),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF2A306C),
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2A306C),
          foregroundColor: Colors.white,
        ),
        buttonTheme: const ButtonThemeData(buttonColor: Color(0xFF2A306C)),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PassbookScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A306C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/malin_logo.png', height: 200, width: 200),
            const SizedBox(height: 20),
            const Text(
              'MalinLink Pass Wallet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Built with love in Oman',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PassbookScreen extends StatefulWidget {
  const PassbookScreen({super.key});

  @override
  _PassbookScreenState createState() => _PassbookScreenState();
}

class _PassbookScreenState extends State<PassbookScreen> {
  List<Map<String, dynamic>> passes = [];

  @override
  void initState() {
    super.initState();
    _loadPassesFromSharedPreferences();
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      await _extractPass(file);
    }
  }

  Future<void> _extractPass(File zipFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = tempDir.path;

      List<int> bytes = await zipFile.readAsBytes();
      Archive archive = ZipDecoder().decodeBytes(bytes);

      String? passJsonString;
      List<int>? logoImageData;
      List<int>? thumbnailImageData;

      for (var file in archive) {
        if (file.name.endsWith('pass.json')) {
          passJsonString = String.fromCharCodes(file.content);
        } else if (file.name.endsWith('logo.png')) {
          logoImageData = file.content;
        } else if (file.name.endsWith('thumbnail.png')) {
          thumbnailImageData = file.content;
        }
      }

      if (passJsonString != null) {
        Map<String, dynamic> passData = json.decode(passJsonString);

        String? logoImageBase64 =
            logoImageData != null ? base64Encode(logoImageData) : null;
        String? thumbnailImageBase64 =
            thumbnailImageData != null
                ? base64Encode(thumbnailImageData)
                : null;

        setState(() {
          passes.add({
            'passData': passData,
            'logoImageBase64': logoImageBase64,
            'thumbnailImageBase64': thumbnailImageBase64,
          });
        });

        _savePassesToSharedPreferences();
      } else {
        _showError('No pass.json found in the .zip file');
      }
    } catch (e) {
      _showError('Failed to extract the .zip file: $e');
    }
  }

  Future<void> _savePassesToSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> serializedPasses =
        passes.map((passData) {
          try {
            return json.encode(passData);
          } catch (e) {
            return '';
          }
        }).toList();

    await prefs.setStringList('passes', serializedPasses);
  }

  Future<void> _loadPassesFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? serializedPasses = prefs.getStringList('passes');

    if (serializedPasses != null) {
      setState(() {
        passes =
            serializedPasses.map((passJson) {
              return json.decode(passJson) as Map<String, dynamic>;
            }).toList();
      });
    }
  }

  void removePass(int index) {
    setState(() {
      passes.removeAt(index);
    });
    _savePassesToSharedPreferences();
  }

  Widget buildPassCard(Map<String, dynamic> passData) {
    final pass = passData['passData'];
    final logoImageBase64 = passData['logoImageBase64'];
    final thumbnailImageBase64 = passData['thumbnailImageBase64'];

    List<int>? logoImageData;
    List<int>? thumbnailImageData;

    if (logoImageBase64 != null) logoImageData = base64Decode(logoImageBase64);
    if (thumbnailImageBase64 != null) {
      thumbnailImageData = base64Decode(thumbnailImageBase64);
    }

    Color backgroundColor = _parseColor(pass['backgroundColor']);
    Color foregroundColor = _parseColor(pass['foregroundColor']);

    String barcodeMessage =
        pass['barcodes']?.isNotEmpty == true
            ? pass['barcodes'][0]['message']
            : '';

    final serialNumber = pass['serialNumber'] ?? 'unknown_serial_number';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                if (logoImageData != null)
                  Image.memory(
                    Uint8List.fromList(logoImageData),
                    height: 30,
                    width: 30,
                  ),
                const SizedBox(width: 8),
                Text(
                  pass['organizationName'] ?? 'Unknown Organization',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: foregroundColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => removePass(passes.indexOf(passData)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${pass['generic']['primaryFields'][0]['value'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: foregroundColor,
                        ),
                      ),
                      Text(
                        'Position: ${pass['generic']['secondaryFields'][0]['value'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14, color: foregroundColor),
                      ),
                    ],
                  ),
                ),
                if (thumbnailImageData != null)
                  Image.memory(
                    Uint8List.fromList(thumbnailImageData),
                    height: 120,
                    width: 120,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email: ${pass['generic']['auxiliaryFields'][0]['value'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14, color: foregroundColor),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Mobile: ${pass['generic']['secondaryFields'][1]['value'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14, color: foregroundColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (barcodeMessage.isNotEmpty)
              QrImageView(
                data: barcodeMessage,
                version: QrVersions.auto,
                size: 150,
                backgroundColor: Colors.transparent,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.white,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? color) {
    if (color != null && color.startsWith('rgb')) {
      final regex = RegExp(r'rgba?\((\d+), (\d+), (\d+)(?:, (\d+))?\)');
      final match = regex.firstMatch(color);
      if (match != null) {
        return Color.fromARGB(
          match.group(4) != null ? int.parse(match.group(4)!) : 255,
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        );
      }
    }
    return Colors.white;
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MalinLink Pass Wallet')),
      body:
          passes.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 80,
                        color: Color(0xFF2A306C),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'To add a pass, tap the "+" button below and select an archive in .zip format.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'For support, contact: info@oktaio.com',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2A306C),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : ListView.builder(
                itemCount: passes.length,
                itemBuilder: (context, index) {
                  return buildPassCard(passes[index]);
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickFile,
        tooltip: 'Add Pass',
        child: const Icon(Icons.add),
      ),
    );
  }
}
