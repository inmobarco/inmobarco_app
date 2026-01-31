import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// AppBar personalizada de Inmobarco con funcionalidades de usuario y caché.
/// 
/// Este widget encapsula toda la lógica de la barra superior incluyendo:
/// - Nombre del usuario si está logueado
/// - Título de la app
class InmobarcoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const InmobarcoAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Inmobarco'),
      actions: [
        // Mostrar nombre del usuario si está logueado
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            if (!authProvider.isLoggedIn) {
              return const SizedBox.shrink();
            }
            
            return Padding(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      authProvider.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
