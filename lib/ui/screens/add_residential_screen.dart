import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/global_data_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/api_service.dart';
import '../../data/services/wasi_api_service.dart';
import '../../domain/models/geo_location.dart';
import 'map_picker_screen.dart';

/// Formulario para crear o editar un residencial.
///
/// Si [complex] es null, crea (POST). Si no, edita (PUT) con los campos
/// nombre/dirección/ciudad/barrio bloqueados.
class AddResidentialScreen extends StatefulWidget {
  final Map<String, dynamic>? complex;

  const AddResidentialScreen({super.key, this.complex});

  @override
  State<AddResidentialScreen> createState() => _AddResidentialScreenState();
}

class _AddResidentialScreenState extends State<AddResidentialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _adminPhone = TextEditingController();
  final _adminEmail = TextEditingController();
  final _frontDeskPhone = TextEditingController();

  String? _selectedCityId;
  String? _selectedZoneId;
  String _stratum = '3';
  List<Map<String, dynamic>> _zones = [];
  bool _loadingZones = false;
  double? _lat;
  double? _lng;
  bool _saving = false;

  bool get _isEdit => widget.complex != null;

  @override
  void initState() {
    super.initState();
    final c = widget.complex;
    if (c == null) return;
    _name.text = c['name']?.toString() ?? '';
    _address.text = c['address']?.toString() ?? '';
    _adminPhone.text = c['admin_phone']?.toString() ?? '';
    _adminEmail.text = c['admin_email']?.toString() ?? '';
    _frontDeskPhone.text = c['front_desk_phone']?.toString() ?? '';
    _selectedCityId = c['id_city']?.toString();
    _selectedZoneId = c['id_zone']?.toString();
    _stratum = c['stratum']?.toString() ?? '3';
    _lat = _toDouble(c['latitude']);
    _lng = _toDouble(c['longitude']);
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _adminPhone.dispose();
    _adminEmail.dispose();
    _frontDeskPhone.dispose();
    super.dispose();
  }

  Future<void> _loadZones(String cityId) async {
    if (cityId.isEmpty) return;
    setState(() {
      _loadingZones = true;
      _zones = [];
      _selectedZoneId = null;
    });
    try {
      final api = WasiApiService(
        apiToken: AppConstants.wasiApiToken,
        companyId: AppConstants.wasiApiId,
      );
      final zones = await api.getZonesByCity(cityId);
      if (mounted) setState(() => _zones = zones);
    } catch (e) {
      debugPrint('Error cargando zonas: $e');
    } finally {
      if (mounted) setState(() => _loadingZones = false);
    }
  }

  Future<void> _openMapPicker() async {
    final cityCoords = _selectedCityId != null
        ? AppConstants.cityCenterCoordinates[_selectedCityId]
        : null;
    final initialLat = cityCoords?[0] ?? AppConstants.defaultLatitude;
    final initialLng = cityCoords?[1] ?? AppConstants.defaultLongitude;

    final result = await Navigator.push<GeoLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          currentLocation: _lat != null && _lng != null
              ? GeoLocation(latitude: _lat!, longitude: _lng!)
              : null,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _lat = result.latitude;
      _lng = result.longitude;
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Faltan campos obligatorios por completar.');
      return;
    }
    if (_selectedCityId == null) {
      _showMessage('Seleccione una ciudad');
      return;
    }
    if (_selectedZoneId == null) {
      _showMessage('Seleccione un barrio');
      return;
    }

    final adminPhone = digitsOnly(_adminPhone.text);
    final adminEmail = _adminEmail.text.trim().toLowerCase();
    final frontDesk = digitsOnly(_frontDeskPhone.text);
    final globalData = context.read<GlobalDataService>();

    setState(() => _saving = true);
    try {
      Map<String, dynamic> result;
      if (_isEdit) {
        // Solo campos editables; null para limpiar.
        final body = <String, dynamic>{
          'admin_phone': adminPhone.isEmpty ? null : adminPhone,
          'admin_email': adminEmail.isEmpty ? null : adminEmail,
          'front_desk_phone': frontDesk.isEmpty ? null : frontDesk,
          'stratum': int.parse(_stratum),
          'latitude': _lat,
          'longitude': _lng,
        };
        await ApiService.updateResidentialComplex(
            widget.complex!['id'] as int, body);
        result = widget.complex!;
      } else {
        final body = <String, dynamic>{
          'name': _name.text.trim().toUpperCase(),
          'address': _address.text.trim().toUpperCase(),
          'id_city': int.parse(_selectedCityId!),
          'id_zone': int.parse(_selectedZoneId!),
          'stratum': int.parse(_stratum),
          if (adminPhone.isNotEmpty) 'admin_phone': adminPhone,
          if (adminEmail.isNotEmpty) 'admin_email': adminEmail,
          if (frontDesk.isNotEmpty) 'front_desk_phone': frontDesk,
          if (_lat != null) 'latitude': _lat,
          if (_lng != null) 'longitude': _lng,
        };
        result = await ApiService.createResidentialComplex(body);
      }
      // Refresca los residenciales para el dropdown y la lista.
      await globalData.reloadResidentials();
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      debugPrint('Error guardando residencial: $e');
      if (mounted) {
        _showMessage(_isEdit
            ? 'No se pudo actualizar el residencial. Intente de nuevo.'
            : 'No se pudo crear el residencial. Intente de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _lockedField(String label, String value) {
    return TextFormField(
      readOnly: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.gray,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final globalData = context.read<GlobalDataService>();
    final cities = globalData.cities;
    final hasLocation = _lat != null && _lng != null;

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Editar residencial' : 'Nuevo residencial')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              readOnly: _isEdit,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre *',
                border: const OutlineInputBorder(),
                filled: _isEdit,
                fillColor: AppColors.gray,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              readOnly: _isEdit,
              decoration: InputDecoration(
                labelText: 'Dirección *',
                border: const OutlineInputBorder(),
                filled: _isEdit,
                fillColor: AppColors.gray,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese la dirección' : null,
            ),
            const SizedBox(height: 16),
            if (_isEdit) ...[
              _lockedField('Ciudad',
                  lookupNameById(cities, _selectedCityId) ?? '—'),
              const SizedBox(height: 16),
              _lockedField('Barrio',
                  lookupNameById(globalData.zones, _selectedZoneId) ?? '—'),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedCityId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ciudad *',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Seleccione una ciudad'),
                items: cities
                    .map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['name'] as String),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null || value == _selectedCityId) return;
                  setState(() => _selectedCityId = value);
                  _loadZones(value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedZoneId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Barrio *',
                  border: const OutlineInputBorder(),
                  suffixIcon: _loadingZones
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                hint: Text(_selectedCityId == null
                    ? 'Seleccione una ciudad primero'
                    : 'Seleccione un barrio'),
                items: _zones
                    .map((z) => DropdownMenuItem(
                          value: z['id'] as String,
                          child: Text(z['name'] as String),
                        ))
                    .toList(),
                onChanged: (_loadingZones || _zones.isEmpty)
                    ? null
                    : (value) => setState(() => _selectedZoneId = value),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _stratum,
              decoration: const InputDecoration(
                labelText: 'Estrato *',
                border: OutlineInputBorder(),
              ),
              items: List.generate(6, (i) {
                final value = (i + 1).toString();
                return DropdownMenuItem(value: value, child: Text(value));
              }),
              onChanged: (value) {
                if (value != null) setState(() => _stratum = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adminPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Teléfono administración',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adminEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo administración',
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
              controller: _frontDeskPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Teléfono portería',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openMapPicker,
              icon: const Icon(Icons.map),
              label: Text(hasLocation
                  ? 'Ubicación: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                  : 'Seleccionar ubicación en el mapa'),
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
