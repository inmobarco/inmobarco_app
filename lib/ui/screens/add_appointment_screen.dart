import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/appointment.dart';

/// Pantalla para crear o editar una cita.
/// 
/// Si se proporciona [appointment], se abrirá en modo edición.
class AddAppointmentScreen extends StatefulWidget {
  final DateTime initialDate;
  final Appointment? appointment;

  const AddAppointmentScreen({
    super.key,
    required this.initialDate,
    this.appointment,
  });

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _propertyAddressController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  Duration _duration = const Duration(hours: 1);
  AppointmentType _selectedType = AppointmentType.visit;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    
    if (_isEditing) {
      // Cargar datos de la cita existente
      final appointment = widget.appointment!;
      _titleController.text = appointment.title;
      _descriptionController.text = appointment.description ?? '';
      _clientNameController.text = appointment.clientName ?? '';
      _clientPhoneController.text = appointment.clientPhone ?? '';
      _propertyAddressController.text = appointment.propertyAddress ?? '';
      _notesController.text = appointment.notes ?? '';
      _selectedDate = appointment.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(appointment.dateTime);
      _duration = appointment.duration;
      _selectedType = appointment.type;
    } else {
      _selectedDate = widget.initialDate;
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _propertyAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Cita' : 'Nueva Cita'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveAppointment,
            child: const Text(
              'Guardar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tipo de cita
            _buildSectionTitle('Tipo de Cita'),
            _buildTypeSelector(),
            
            const SizedBox(height: 24),
            
            // Información básica
            _buildSectionTitle('Información de la Cita'),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration(
                'Título *',
                Icons.title,
                hint: 'Ej: Visita apartamento Centro',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es requerido';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration(
                'Descripción',
                Icons.description,
                hint: 'Detalles adicionales de la cita',
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 24),
            
            // Fecha y hora
            _buildSectionTitle('Fecha y Hora'),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildDateSelector(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeSelector(),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildDurationSelector(),
            
            const SizedBox(height: 24),
            
            // Información del cliente
            _buildSectionTitle('Cliente (Opcional)'),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _clientNameController,
              decoration: _inputDecoration(
                'Nombre del cliente',
                Icons.person,
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _clientPhoneController,
              decoration: _inputDecoration(
                'Teléfono',
                Icons.phone,
              ),
              keyboardType: TextInputType.phone,
            ),
            
            const SizedBox(height: 24),
            
            // Propiedad
            _buildSectionTitle('Propiedad (Opcional)'),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _propertyAddressController,
              decoration: _inputDecoration(
                'Dirección de la propiedad',
                Icons.location_on,
                hint: 'Ej: Calle Principal #123',
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Notas
            _buildSectionTitle('Notas Adicionales'),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _notesController,
              decoration: _inputDecoration(
                'Notas',
                Icons.note,
                hint: 'Recordatorios o información importante',
              ),
              maxLines: 4,
            ),
            
            const SizedBox(height: 32),
            
            // Botón guardar
            ElevatedButton(
              onPressed: _saveAppointment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.cardBorderRadius,
                ),
              ),
              child: Text(
                _isEditing ? 'Actualizar Cita' : 'Crear Cita',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textColor,
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: AppointmentType.values.map((type) {
          final isSelected = type == _selectedType;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(type.icon),
                  const SizedBox(width: 6),
                  Text(type.displayName),
                ],
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedType = type;
                });
              },
              selectedColor: AppColors.primaryColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primaryColor : AppColors.textColor2,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateSelector() {
    final dateFormat = DateFormat('EEE, d MMM yyyy', 'es_ES');
    
    return InkWell(
      onTap: _selectDate,
      borderRadius: AppTheme.cardBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textColor2.withValues(alpha: 0.3)),
          borderRadius: AppTheme.cardBorderRadius,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: AppColors.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fecha',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textColor2,
                    ),
                  ),
                  Text(
                    dateFormat.format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: _selectTime,
      borderRadius: AppTheme.cardBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textColor2.withValues(alpha: 0.3)),
          borderRadius: AppTheme.cardBorderRadius,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time,
              color: AppColors.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hora',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textColor2,
                    ),
                  ),
                  Text(
                    _selectedTime.format(context),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    final durations = [
      const Duration(minutes: 30),
      const Duration(hours: 1),
      const Duration(hours: 1, minutes: 30),
      const Duration(hours: 2),
      const Duration(hours: 3),
    ];

    String formatDuration(Duration d) {
      if (d.inMinutes < 60) {
        return '${d.inMinutes} min';
      } else if (d.inMinutes % 60 == 0) {
        return '${d.inHours} h';
      } else {
        return '${d.inHours} h ${d.inMinutes % 60} min';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duración',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textColor2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: durations.map((duration) {
            final isSelected = duration == _duration;
            return ChoiceChip(
              label: Text(formatDuration(duration)),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _duration = duration;
                });
              },
              selectedColor: AppColors.primaryColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primaryColor : AppColors.textColor2,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primaryColor),
      border: OutlineInputBorder(
        borderRadius: AppTheme.cardBorderRadius,
        borderSide: BorderSide(
          color: AppColors.textColor2.withValues(alpha: 0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppTheme.cardBorderRadius,
        borderSide: BorderSide(
          color: AppColors.textColor2.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppTheme.cardBorderRadius,
        borderSide: const BorderSide(
          color: AppColors.primaryColor,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveAppointment() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final appointment = Appointment(
      id: _isEditing 
          ? widget.appointment!.id 
          : DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      dateTime: dateTime,
      duration: _duration,
      type: _selectedType,
      status: _isEditing ? widget.appointment!.status : AppointmentStatus.pending,
      clientName: _clientNameController.text.trim().isNotEmpty
          ? _clientNameController.text.trim()
          : null,
      clientPhone: _clientPhoneController.text.trim().isNotEmpty
          ? _clientPhoneController.text.trim()
          : null,
      propertyAddress: _propertyAddressController.text.trim().isNotEmpty
          ? _propertyAddressController.text.trim()
          : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      createdAt: _isEditing ? widget.appointment!.createdAt : DateTime.now(),
      updatedAt: _isEditing ? DateTime.now() : null,
    );

    Navigator.pop(context, appointment);
  }
}
