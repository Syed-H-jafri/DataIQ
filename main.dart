import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  runApp(MyApp());
}

void startBackend() async {
  try {
    await Process.start('api.exe', []);
    print("✅ Backend started");
  } catch (e) {
    print("❌ Backend error: $e");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          primary: const Color(0xFF0F766E),
          secondary: const Color(0xFFF59E0B),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5EFE4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF1F2937),
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
            letterSpacing: 0.3,
          ),
        ),
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? file1Path;
  String? file2Path;
  String status = "";
  String originalIdCol = "";
  String originalDescCol = "";
  String targetDescCol = "";
  bool isUploadNoticeVisible = false;
  bool isReady = false;
  @override
void initState() {
  super.initState();
  
  try {
    Process.start(
      '${Directory.current.path}\\api.exe',
      [],
      mode: ProcessStartMode.detached,
      );
    Future.delayed(Duration(seconds: 12), () {
      if (mounted) setState(() => isReady = true);
    });
  } catch (e) {
    print("API start error: $e");
  }
}


  InputDecoration buildOptionalFieldDecoration(
    String label,
    Color focusColor,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      floatingLabelStyle: TextStyle(
        fontSize: 12,
        color: focusColor,
      ),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD1D5DB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD1D5DB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: focusColor,
          width: 1.4,
        ),
      ),
    );
  }

  // 🔹 PICK FILE
  Future<void> pickFirstFile() async {
    var path = await pickFile();
    setState(() {
      file1Path = path;
    });
  }

  Future<void> pickSecondFile() async {
    var path = await pickFile();
    setState(() {
      file2Path = path;
    });
  }

  Future<String?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      return result.files.single.path;
    } else {
      return null;
    }
  }

  String fileNameFromPath(String? path) {
    if (path == null || path.isEmpty) {
      return 'No file selected';
    }

    return path.split(RegExp(r'[\\/]')).last;
  }

  Future<void> confirmUpload() async {
    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm upload'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to upload these files?'),
              const SizedBox(height: 12),
              Text('Original: ${fileNameFromPath(file1Path)}'),
              const SizedBox(height: 6),
              Text('Target: ${fileNameFromPath(file2Path)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );

    if (shouldUpload == true) {
      isUploadNoticeVisible = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const AlertDialog(
            content: Text(
              'Uploading now. This may take a few moments depending on file size.',
            ),
          );
        },
      );

      await uploadFiles();

      if (mounted && isUploadNoticeVisible && Navigator.of(context).canPop()) {
        isUploadNoticeVisible = false;
        Navigator.of(context).pop();
      }
    }
  }

  // 🔹 UPLOAD FILES TO API
  Future<void> uploadFiles() async {
    await Future.delayed(Duration(seconds: 2));
    if (file1Path == null || file2Path == null) {
      setState(() {
        status = "❌ Please select both files";
      });
      return;
    }

    setState(() {
      status = "⏳ Uploading...";
    });

    try {
      var uri = Uri.parse('http://127.0.0.1:8000/match-files/');

      var request = http.MultipartRequest('POST', uri);

      request.fields['original_id_col'] = originalIdCol;
      request.fields['original_desc_col'] = originalDescCol;
      request.fields['target_desc_col'] = targetDescCol;

      request.files.add(
        await http.MultipartFile.fromPath('original', file1Path!),
      );

      request.files.add(
        await http.MultipartFile.fromPath('target', file2Path!),
      );

      if (originalIdCol.trim().isNotEmpty) {
        request.fields['originalIdCol'] = originalIdCol.trim();
      }

      if (originalDescCol.trim().isNotEmpty) {
        request.fields['originalDescCol'] = originalDescCol.trim();
      }

      if (targetDescCol.trim().isNotEmpty) {
        request.fields['targetDescCol'] = targetDescCol.trim();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        final bytes = response.bodyBytes;
        final isExcelResponse =
            contentType.contains('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') ||
            contentType.contains('application/vnd.ms-excel') ||
            (bytes.length >= 4 &&
                bytes[0] == 0x50 &&
                bytes[1] == 0x4B &&
                bytes[2] == 0x03 &&
                bytes[3] == 0x04);

        if (!isExcelResponse) {
          final message = response.body.trim().isNotEmpty
              ? response.body.trim()
              : 'Server returned a non-Excel response';
          print('Invalid file response: $contentType ${response.body}');
          setState(() {
            status = "❌ $message";
          });
          return;
        }

        print('Success: ${response.statusCode}');
        if (mounted && isUploadNoticeVisible && Navigator.of(context).canPop()) {
          isUploadNoticeVisible = false;
          Navigator.of(context).pop();
        }

        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save matched file',
          fileName: 'matched_output.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (outputPath == null) {
          setState(() {
            status = "Save cancelled";
          });
          return;
        }

        final savePath = outputPath.toLowerCase().endsWith('.xlsx')
            ? outputPath
            : '$outputPath.xlsx';

        await File(savePath).writeAsBytes(bytes);

        setState(() {
          file1Path = null;
          file2Path = null;
          status = "";
        });

        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Done'),
                content: Text(
                  'Saved file to:\n$savePath\n\nPlease go to this path and use the saved file.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
        return;

        setState(() {
          status = "✅ Success! File received (${bytes.length} bytes)";
        });

      } else {
        print('Error: ${response.statusCode}');
        setState(() {
          status = "❌ Failed: ${response.statusCode}";
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        status = "❌ Error: $e";
      });
    }
  }

  // 🔹 UI
  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Starting DataIQ Engine...")
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFBF5),
                  Color(0xFFF5E6C8),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Card(
              elevation: 0,
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Match your files",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "This application extracts and compares product data across different files, including PDF, XLSX, XLS, and CSV formats, regardless of column name variations.\nIt identifies and maps the most relevant matches, linking records such as serial numbers with high-confidence results.",
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF).withOpacity(0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Original File",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: pickFirstFile,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: const Color(0xFF0F766E),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            child: const Text("Choose file"),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD1D5DB),
                              ),
                            ),
                            child: Text(
                              file1Path ?? "No file selected",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4B5563),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (value) => originalIdCol = value,
                            style: const TextStyle(fontSize: 13),
                            decoration: buildOptionalFieldDecoration(
                              "Optional Unique ID column name",
                              const Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (value) => originalDescCol = value,
                            style: const TextStyle(fontSize: 13),
                            decoration: buildOptionalFieldDecoration(
                              "Optional Description column name",
                              const Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF).withOpacity(0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Comparison File",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: pickSecondFile,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: const Color(0xFF1D4ED8),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            child: const Text("Choose file"),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD1D5DB),
                              ),
                            ),
                            child: Text(
                              file2Path ?? "No file selected",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4B5563),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (value) => targetDescCol = value,
                            style: const TextStyle(fontSize: 13),
                            decoration: buildOptionalFieldDecoration(
                              "Optional Description column name",
                              const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: confirmUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF111827),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text("Upload & Match"),
                      ),
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF).withOpacity(0.72),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
