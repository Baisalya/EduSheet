import 'package:flutter/material.dart';
import '../../../features/editor/presentation/screens/create_paper_screen.dart';
import '../../../features/omr/presentation/pages/omr_generator_page.dart';
import '../../../features/question_bank/presentation/screens/question_bank_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduSheet'),
        centerTitle: true,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(24),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _HomeCard(
            title: 'Create Question Paper',
            icon: Icons.note_add,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreatePaperScreen()),
            ),
          ),
          _HomeCard(
            title: 'OMR Sheet Generator',
            icon: Icons.grid_on,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OmrGeneratorPage()),
            ),
          ),
          _HomeCard(
            title: 'Question Bank',
            icon: Icons.account_balance,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QuestionBankScreen()),
            ),
          ),
          _HomeCard(
            title: 'Settings',
            icon: Icons.settings,
            color: Colors.grey,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
