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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'OMR Sheet Generator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => OmrPdfService.generateAndPreview(config),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OmrCard(
              title: 'Branding & Info',
              icon: Icons.business,
              color: Colors.blue,
              child: _buildBrandingSection(config, notifier),
            ),
            const SizedBox(height: 20),
            _OmrCard(
              title: 'Configuration',
              icon: Icons.settings_outlined,
              color: Colors.purple,
              child: _buildConfigSection(config, notifier),
            ),
            const SizedBox(height: 20),
            _OmrCard(
              title: 'Extra Fields',
              icon: Icons.add_task_outlined,
              color: Colors.orange,
              child: Column(
                children: [
                  _ModernSwitch(
                    title: 'Include Roll Number Field',
                    value: config.includeRollNumber,
                    onChanged: notifier.toggleRollNumber,
                  ),
                  _ModernSwitch(
                    title: 'Include Section Field',
                    value: config.includeSection,
                    onChanged: notifier.toggleSection,
                  ),
                  _ModernSwitch(
                    title: 'Include Barcode/QR Code',
                    value: config.includeBarcode,
                    onChanged: notifier.toggleBarcode,
                  ),
                  if (config.includeBarcode)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        initialValue: config.barcodeData,
                        decoration: InputDecoration(
                          labelText: 'Barcode Data (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: notifier.updateBarcodeData,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => OmrPdfService.generateAndPreview(config),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text(
                  'Generate & Export PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingSection(OmrConfig config, OmrNotifier notifier) {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              notifier.updateSchoolLogo(image.path);
            }
          },
          child: Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: config.schoolLogo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(config.schoolLogo!), fit: BoxFit.cover),
                      )
                    : Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey[400]),
              ),
              if (config.schoolLogo != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: GestureDetector(
                    onTap: () => notifier.updateSchoolLogo(null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              TextFormField(
                initialValue: config.schoolName,
                decoration: InputDecoration(
                  labelText: 'School/Institute Name',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: notifier.updateSchoolName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: config.examName,
                decoration: InputDecoration(
                  labelText: 'Exam Name',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: notifier.updateExamName,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigSection(OmrConfig config, OmrNotifier notifier) {
    return Column(
      children: [
        DropdownButtonFormField<int>(
          value: config.questionCount,
          decoration: InputDecoration(
            labelText: 'Total Questions',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: [10, 20, 25, 30, 40, 50, 60, 75, 100, 150, 200, 300, 400, 500]
              .map((c) => DropdownMenuItem(value: c, child: Text('$c Questions')))
              .toList(),
          onChanged: (val) => notifier.updateQuestionCount(val!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<OmrOptionsCount>(
          value: config.optionsCount,
          decoration: InputDecoration(
            labelText: 'Options per Question',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: OmrOptionsCount.values
              .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('${c.name.toUpperCase()} ( ${config.optionsIntValue} )')))
              .toList(),
          onChanged: (val) => notifier.updateOptionsCount(val!),
        ),
      ],
    );
  }
}

class _OmrCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _OmrCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ModernSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ModernSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? Colors.blue.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? Colors.blue.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: value ? FontWeight.bold : FontWeight.w500,
            color: value ? Colors.blue[700] : Colors.black87,
          ),
        ),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
