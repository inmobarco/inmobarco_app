import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/client_provider.dart';

/// Formulario para crear un cliente CRM en WASI y asociarle la
/// propiedad dummy del asesor activo.
class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _cellPhone = TextEditingController();
  final _email = TextEditingController();
  final _query = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _cellPhone.dispose();
    _email.dispose();
    _query.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Faltan campos obligatorios por completar.');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<ClientProvider>().createClient(
            firstName: _firstName.text.trim(),
            cellPhone: _cellPhone.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim().toLowerCase(),
            query: _query.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error creando cliente: $e');
      if (mounted) {
        _showMessage(e.toString().contains('no tiene propiedad')
            ? 'El asesor no tiene propiedad CRM asignada. Contacte al administrador.'
            : 'No se pudo crear el cliente. Intente de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Apellido',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cellPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Celular *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el celular' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return null;
                return s.contains('@') && s.contains('.')
                    ? null
                    : 'Correo inválido';
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _query,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Consulta',
                hintText: '¿Qué busca el cliente?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.pureWhite),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
