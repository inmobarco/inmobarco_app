import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 80, color: AppColors.textColor2),
          SizedBox(height: 16),
          Text(
            'Clientes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textColor),
          ),
          SizedBox(height: 8),
          Text('Próximamente', style: TextStyle(color: AppColors.textColor2)),
        ],
      ),
    );
  }
}
