import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/cache_service.dart';

/// AppBar personalizada de Inmobarco con funcionalidades de usuario y caché.
/// 
/// Este widget encapsula toda la lógica de la barra superior incluyendo:
/// - Botón de usuario (Entrar/Nombre)
/// - Título de la app
/// - Botón de información de caché
class InmobarcoAppBar extends StatefulWidget implements PreferredSizeWidget {
  const InmobarcoAppBar({super.key});

  @override
  State<InmobarcoAppBar> createState() => _InmobarcoAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _InmobarcoAppBarState extends State<InmobarcoAppBar> {
  String? _userFirstName;
  String? _userLastName;
  String? _userPhone;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final data = await CacheService.loadUserProfile();
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _userFirstName = _normalizeProfileValue(data['first_name']);
        _userLastName = _normalizeProfileValue(data['last_name']);
        _userPhone = _normalizeProfileValue(data['phone']);
      });
    }
  }

  String? _normalizeProfileValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Inmobarco'),
      actions: [
        // Botón de usuario a la derecha
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: _showUserDialog,
            child: Text(
              _userFirstName != null && _userFirstName!.trim().isNotEmpty
                  ? _userFirstName!.trim()
                  : 'Entrar',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showUserDialog() async {
    final formKey = GlobalKey<FormState>();
    String firstName = _userFirstName ?? '';
    String lastName = _userLastName ?? '';
    String phoneNumber = _userPhone ?? '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Identifícate'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: firstName,
                  onChanged: (value) => firstName = value,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.words,
                  validator: (_) => null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: lastName,
                  onChanged: (value) => lastName = value,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                  textCapitalization: TextCapitalization.words,
                  validator: (_) => null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: phoneNumber,
                  onChanged: (value) => phoneNumber = value,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final digits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
                    if (digits.replaceAll('+', '').length < 7) return 'Teléfono inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final formState = formKey.currentState;
                if (formState != null && !formState.validate()) return;
                final profile = <String, String>{};

                final trimmedFirst = firstName.trim();
                if (trimmedFirst.isNotEmpty) {
                  profile['first_name'] = trimmedFirst;
                }

                final trimmedLast = lastName.trim();
                if (trimmedLast.isNotEmpty) {
                  profile['last_name'] = trimmedLast;
                }

                final trimmedPhone = phoneNumber.trim();
                if (trimmedPhone.isNotEmpty) {
                  profile['phone'] = trimmedPhone;
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(profile);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (result == null) {
      return;
    }

    if (result.isEmpty) {
      await CacheService.clearUserProfile();
      if (!mounted) return;
      setState(() {
        _userFirstName = null;
        _userLastName = null;
        _userPhone = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil eliminado')),
      );
      return;
    }

    await CacheService.saveUserProfile(result);
    if (!mounted) return;
    setState(() {
      _userFirstName = result['first_name'];
      _userLastName = result['last_name'];
      _userPhone = result['phone'];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil guardado correctamente')),
    );
  }
}
