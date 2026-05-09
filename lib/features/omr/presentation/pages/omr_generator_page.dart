import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/omr_provider.dart';
import '../../domain/models/omr_config.dart';
import '../../services/omr_pdf_service.dart';

class OmrGeneratorPage extends ConsumerWidget {
  const OmrGeneratorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(omrProvider);
    final notifier = ref.read(omrProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OMR Sheet Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => OmrPdfService.generateAndPreview(config),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(title: 'Branding & Info'),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      notifier.updateSchoolLogo(image.path);
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: config.schoolLogo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(config.schoolLogo!), fit: BoxFit.cover),
                          )
                        : const Icon(Icons.add_a_photo, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: config.schoolName,
                        decoration: const InputDecoration(labelText: 'School/Institute Name'),
                        onChanged: notifier.updateSchoolName,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: config.examName,
                        decoration: const InputDecoration(labelText: 'Exam Name'),
                        onChanged: notifier.updateExamName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Configuration'),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: config.questionCount,
                    decoration: const InputDecoration(labelText: 'Total Questions'),
                    items: [10, 20, 25, 30, 40, 50, 60, 75, 100, 150, 200, 300, 400, 500]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.toString())))
                        .toList(),
                    onChanged: (val) => notifier.updateQuestionCount(val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<OmrOptionsCount>(
                    initialValue: config.optionsCount,
                    decoration: const InputDecoration(labelText: 'Options per Question'),
                    items: OmrOptionsCount.values
                        .map((c) => DropdownMenuItem(value: c, child: Text('${c.name.toUpperCase()} ( ${config.optionsIntValue} )')))
                        .toList(),
                    onChanged: (val) => notifier.updateOptionsCount(val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Include Roll Number Field'),
              value: config.includeRollNumber,
              onChanged: notifier.toggleRollNumber,
            ),
            SwitchListTile(
              title: const Text('Include Section Field'),
              value: config.includeSection,
              onChanged: notifier.toggleSection,
            ),
            SwitchListTile(
              title: const Text('Include Barcode/QR Code'),
              value: config.includeBarcode,
              onChanged: notifier.toggleBarcode,
            ),
            if (config.includeBarcode)
              TextFormField(
                initialValue: config.barcodeData,
                decoration: const InputDecoration(labelText: 'Barcode Data (Optional)'),
                onChanged: notifier.updateBarcodeData,
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => OmrPdfService.generateAndPreview(config),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate & Export PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
