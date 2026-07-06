import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/client_provider.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.dashboard, size: 80, color: AppColors.textColor2),
                const SizedBox(height: 16),
                const Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textColor),
                ),
                const SizedBox(height: 8),
                const Text('Inicia sesión para ver tu resumen', style: TextStyle(color: AppColors.textColor2)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Iniciar Sesión'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryColor,
                      child: Text(
                        auth.user?.firstName.isNotEmpty == true
                            ? auth.user!.firstName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.fullName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '@${auth.user?.username ?? ''}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textColor2),
                          ),
                          if (auth.user?.phone.isNotEmpty == true)
                            Text(
                              auth.user!.phone,
                              style: const TextStyle(fontSize: 13, color: AppColors.textColor2),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<ClientProvider>().clear();
                        auth.logout();
                      },
                      child: const Text('Salir', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                Icon(Icons.bar_chart, size: 64, color: AppColors.textColor2.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                const Text('Métricas del asesor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textColor)),
                const SizedBox(height: 4),
                const Text('Próximamente', style: TextStyle(color: AppColors.textColor2)),
              ],
            ),
          ],
        );
      },
    );
  }
}
