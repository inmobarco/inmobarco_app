import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/client.dart';
import '../providers/client_provider.dart';

/// Formulario para crear o editar un cliente CRM.
///
/// Si [client] es null, crea (POST a WASI + asociación de la propiedad del
/// asesor, estado bloqueado en "Nuevo"). Si no, edita (PUT a WASI) con el
/// celular bloqueado y el estado editable.
class AddClientScreen extends StatefulWidget {
  final Client? client;

  const AddClientScreen({super.key, this.client});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  static const Map<int, String> _statuses = {
    1: 'Nuevo',
    2: 'En Proceso',
    3: 'Convertido',
    4: 'Recuperado',
    5: 'Perdido',
  };

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _cellPhone = TextEditingController();
  final _email = TextEditingController();
  final _query = TextEditingController();
  int _statusId = 1;
  bool _saving = false;

  bool get _isEdit => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    if (c == null) return;
    _firstName.text = c.firstName;
    _lastName.text = c.lastName;
    _cellPhone.text = c.cellPhone ?? '';
    _email.text = c.email ?? '';
    _query.text = c.query ?? '';
    _statusId = c.idClientStatus ?? 1;
  }

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
      final provider = context.read<ClientProvider>();
      if (_isEdit) {
        await provider.updateClient(
          widget.client!.idClientWasi,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim().toLowerCase(),
          query: _query.text.trim(),
          idClientStatus: _statusId,
        );
      } else {
        await provider.createClient(
          firstName: _firstName.text.trim(),
          cellPhone: _cellPhone.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim().toLowerCase(),
          query: _query.text.trim(),
        );
      }
      // 'queued' cuando no había red y la operación quedó pendiente.
      if (mounted) {
        Navigator.pop(context, provider.lastOperationQueued ? 'queued' : 'ok');
      }
    } catch (e) {
      debugPrint('Error guardando cliente: $e');
      if (mounted) {
        if (!_isEdit && e.toString().contains('no tiene propiedad')) {
          _showMessage(
              'El asesor no tiene propiedad CRM asignada. Contacte al administrador.');
        } else {
          _showMessage(_isEdit
              ? 'No se pudo actualizar el cliente. Intente de nuevo.'
              : 'No se pudo crear el cliente. Intente de nuevo.');
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editar cliente' : 'Nuevo cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEdit) ...[
              Text(
                'Cliente #${widget.client!.idClientWasi}',
                style: const TextStyle(color: AppColors.textColor2, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
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
              readOnly: _isEdit,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Celular *',
                border: const OutlineInputBorder(),
                filled: _isEdit,
                fillColor: AppColors.gray,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el celular' : null,
            ),
            const SizedBox(height: 16),
            // Estado: bloqueado en "Nuevo" al crear; editable al editar
            DropdownButtonFormField<int>(
              initialValue: _statusId,
              decoration: InputDecoration(
                labelText: 'Estado',
                border: const OutlineInputBorder(),
                filled: !_isEdit,
                fillColor: AppColors.gray,
              ),
              items: _statuses.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: _isEdit
                  ? (v) {
                      if (v != null) setState(() => _statusId = v);
                    }
                  : null,
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
