import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/maintenance_request.dart';

/// El backend envía UTC; se muestra en hora local (America/Bogota).
String formatMaintenanceDate(DateTime? date, {bool withYear = false}) {
  if (date == null) return '—';
  final pattern = withYear ? 'd MMM yyyy, HH:mm' : 'd MMM, HH:mm';
  return DateFormat(pattern, 'es_ES').format(date.toLocal());
}

Color maintenanceStatusColor(String status) {
  switch (status) {
    case MaintenanceStatus.recibida:
      return AppColors.info;
    case MaintenanceStatus.enRevision:
    case MaintenanceStatus.esperandoAprobacion:
      return AppColors.warning;
    case MaintenanceStatus.programada:
    case MaintenanceStatus.enEjecucion:
      return AppColors.primaryColor;
    case MaintenanceStatus.resuelta:
      return AppColors.success;
    case MaintenanceStatus.cancelada:
      return AppColors.error;
    default:
      return AppColors.textColor2;
  }
}

Color maintenancePriorityColor(String priority) {
  switch (priority) {
    case MaintenancePriority.urgente:
      return AppColors.error;
    case MaintenancePriority.alta:
      return AppColors.warning;
    case MaintenancePriority.media:
      return AppColors.info;
    default:
      return AppColors.textColor2;
  }
}

/// Etiqueta compacta de color (estado, prioridad, avisos).
class MaintenanceBadge extends StatelessWidget {
  const MaintenanceBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory MaintenanceBadge.status(String status) => MaintenanceBadge(
    label: MaintenanceStatus.label(status),
    color: maintenanceStatusColor(status),
  );

  factory MaintenanceBadge.priority(String priority) => MaintenanceBadge(
    label: MaintenancePriority.label(priority),
    color: maintenancePriorityColor(priority),
    icon: priority == MaintenancePriority.urgente ? Icons.priority_high : null,
  );

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
