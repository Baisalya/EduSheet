import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:edusheet/core/services/ocr_service.dart';
import 'dart:io';

class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});

  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  final ImagePicker _picker = ImagePicker();
  final OCRService _ocrService = OCRService();
  final TextEditingController _resultController = TextEditingController();
  
  bool _isLoading = false;
  bool _isHindi = false;
  File? _selectedImage;

  @override
  void dispose() {
    _ocrService.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Question',
          toolbarColor: Theme.of(context).colorScheme.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Question',
        ),
      ],
    );

    if (croppedFile == null) return;

    setState(() {
      _isLoading = true;
      _selectedImage = File(croppedFile.path);
    });

    final text = await _ocrService.recognizeText(croppedFile.path, isHindi: _isHindi);

    setState(() {
      _isLoading = false;
      _resultController.text = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Question'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickAndProcessImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Hindi (Devanagari) Support'),
              subtitle: const Text('Enable for Hindi text recognition'),
              value: _isHindi,
              onChanged: (val) => setState(() => _isHindi = val),
            ),
            const Divider(),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              const Text(
                'Recognized Text:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _resultController,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Recognized text will appear here...',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _resultController.text.isNotEmpty
                    ? () => Navigator.pop(context, _resultController.text)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Use This Text'),
              ),
            ],
            if (_selectedImage != null && !_isLoading) ...[
              const SizedBox(height: 24),
              const Text('Processed Image:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Image.file(_selectedImage!, height: 200, fit: BoxFit.contain),
            ],
          ],
        ),
      ),
    );
  }
}
