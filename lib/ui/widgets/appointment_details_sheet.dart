import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/appointment.dart';

/// Bottom sheet para mostrar detalles de una cita.
class AppointmentDetailsSheet extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(AppointmentStatus) onStatusChange;

  const AppointmentDetailsSheet({
    super.key,
    required this.appointment,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'es_ES');
    final timeFormat = DateFormat('HH:mm');
    final statusColor = Color(appointment.status.colorValue);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundLevel1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título y tipo
                Row(
                  children: [
                    Text(
                      appointment.type.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            appointment.type.displayName,
                            style: const TextStyle(
                              color: AppColors.textColor2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Estado actual
                _buildDetailRow(
                  Icons.flag,
                  'Estado',
                  appointment.status.displayName,
                  valueColor: statusColor,
                ),

                // Fecha y hora
                _buildDetailRow(
                  Icons.calendar_today,
                  'Fecha',
                  dateFormat.format(appointment.dateTime),
                ),

                _buildDetailRow(
                  Icons.access_time,
                  'Hora',
                  '${timeFormat.format(appointment.dateTime)} - ${timeFormat.format(appointment.endTime)}',
                ),

                // Cliente
                if (appointment.clientName != null)
                  _buildDetailRow(
                    Icons.person,
                    'Cliente',
                    appointment.clientName!,
                  ),

                // Teléfono
                if (appointment.clientPhone != null)
                  _buildDetailRow(
                    Icons.phone,
                    'Teléfono',
                    appointment.clientPhone!,
                  ),

                // Descripción
                if (appointment.description != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor2,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.description!,
                    style: const TextStyle(
                      color: AppColors.textColor,
                      fontSize: 14,
                    ),
                  ),
                ],

                // Resultado/Seguimiento
                if (appointment.outcome != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Seguimiento',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor2,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.outcome!,
                    style: const TextStyle(
                      color: AppColors.textColor,
                      fontSize: 14,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Cambiar estado
                const Text(
                  'Cambiar estado:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor2,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppointmentStatus.values.map((status) {
                    final isSelected = status == appointment.status;
                    final color = Color(status.colorValue);
                    return ChoiceChip(
                      label: Text(status.displayName),
                      selected: isSelected,
                      onSelected:
                          isSelected ? null : (_) => onStatusChange(status),
                      selectedColor: color.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? color : AppColors.textColor2,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          side:
                              const BorderSide(color: AppColors.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete),
                        label: const Text('Eliminar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Espacio para safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textColor2),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textColor2,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textColor,
                fontWeight:
                    valueColor != null ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
