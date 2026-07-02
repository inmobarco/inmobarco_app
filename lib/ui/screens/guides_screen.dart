import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guías')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist, size: 80, color: AppColors.textColor2),
            SizedBox(height: 16),
            Text(
              'Guías',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textColor),
            ),
            SizedBox(height: 8),
            Text('Checklists de visita y captación', style: TextStyle(color: AppColors.textColor2)),
            SizedBox(height: 4),
            Text('Próximamente', style: TextStyle(color: AppColors.textColor2)),
          ],
        ),
      ),
    );
  }
}
