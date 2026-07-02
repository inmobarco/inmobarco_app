import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: AppColors.textColor2),
            SizedBox(height: 16),
            Text(
              'Notificaciones',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textColor),
            ),
            SizedBox(height: 8),
            Text('Sin notificaciones por ahora', style: TextStyle(color: AppColors.textColor2)),
          ],
        ),
      ),
    );
  }
}
