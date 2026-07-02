import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CalculatorsScreen extends StatelessWidget {
  const CalculatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadoras')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate, size: 80, color: AppColors.textColor2),
            SizedBox(height: 16),
            Text(
              'Calculadoras',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textColor),
            ),
            SizedBox(height: 8),
            Text('Primer canon, pago propietario, comisiones', style: TextStyle(color: AppColors.textColor2)),
            SizedBox(height: 4),
            Text('Próximamente', style: TextStyle(color: AppColors.textColor2)),
          ],
        ),
      ),
    );
  }
}
