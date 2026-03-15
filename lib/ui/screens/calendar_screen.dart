import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../widgets/appointment_details_sheet.dart';
import 'add_appointment_screen.dart';

/// Pantalla de calendario/agenda para gestionar citas.
/// 
/// Muestra un calendario interactivo con las citas programadas
/// y permite crear, editar y eliminar citas.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    
    // Cargar citas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentProvider>().loadAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryColor,
        onPressed: _createNewAppointment,
        tooltip: 'Nueva Cita',
        child: const Icon(Icons.add, color: AppColors.pureWhite),
      ),
      body: Consumer<AppointmentProvider>(
        builder: (context, provider, child) {
          final allDayAppointments = _selectedDay != null
              ? provider.getAppointmentsForDay(_selectedDay!)
              : <Appointment>[];
          final selectedDayAppointments = allDayAppointments
              .where((a) => a.status != AppointmentStatus.completed && a.status != AppointmentStatus.cancelled)
              .toList();
          final finishedAppointments = allDayAppointments
              .where((a) => a.status == AppointmentStatus.completed || a.status == AppointmentStatus.cancelled)
              .toList();

          return Column(
            children: [
              // Calendario
              _buildCalendar(provider),
              
              const Divider(height: 1),
              
              // Encabezado de citas del día
              _buildDayHeader(finishedAppointments),
              
              // Lista de citas del día seleccionado
              Expanded(
                child: selectedDayAppointments.isEmpty
                    ? _buildEmptyDayMessage()
                    : _buildAppointmentsList(selectedDayAppointments),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendar(AppointmentProvider provider) {
    return TableCalendar<Appointment>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      locale: 'es_ES',
      startingDayOfWeek: StartingDayOfWeek.monday,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) => provider.getAppointmentsForDay(day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      calendarStyle: CalendarStyle(
        // Día de hoy
        todayDecoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: AppColors.primaryColor,
          fontWeight: FontWeight.bold,
        ),
        // Día seleccionado
        selectedDecoration: const BoxDecoration(
          color: AppColors.primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: AppColors.pureWhite,
          fontWeight: FontWeight.bold,
        ),
        // Marcadores de eventos
        markerDecoration: const BoxDecoration(
          color: AppColors.secondaryColor,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
        markerSize: 6,
        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
        // Días del fin de semana
        weekendTextStyle: TextStyle(
          color: AppColors.textColor.withValues(alpha: 0.6),
        ),
        // Días fuera del mes
        outsideDaysVisible: false,
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonShowsNext: false,
        formatButtonDecoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.1),
          borderRadius: AppTheme.cardBorderRadius,
        ),
        formatButtonTextStyle: const TextStyle(
          color: AppColors.primaryColor,
          fontSize: 12,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppColors.textColor,
        ),
        leftChevronIcon: const Icon(
          Icons.chevron_left,
          color: AppColors.primaryColor,
        ),
        rightChevronIcon: const Icon(
          Icons.chevron_right,
          color: AppColors.primaryColor,
        ),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: AppColors.textColor2,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        weekendStyle: TextStyle(
          color: AppColors.textColor2,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDayHeader(List<Appointment> finishedAppointments) {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'es_ES');
    final dayString = _selectedDay != null
        ? dateFormat.format(_selectedDay!)
        : 'Selecciona un día';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.backgroundLevel2,
      child: Row(
        children: [
          if (finishedAppointments.isNotEmpty)
            GestureDetector(
              onTap: () => _showFinishedAppointmentsDialog(finishedAppointments),
              child: Container(
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.badgeBorderRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history,
                      color: AppColors.primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${finishedAppointments.length}',
                      style: const TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Icon(
            Icons.event,
            color: AppColors.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dayString,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),
          ),
          if (_selectedDay != null && isSameDay(_selectedDay, DateTime.now()))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: AppTheme.cardBorderRadius,
              ),
              child: const Text(
                'Hoy',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: AppColors.textColor2.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay citas programadas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textColor2,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _createNewAppointment,
            icon: const Icon(Icons.add),
            label: const Text('Crear nueva cita'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList(List<Appointment> appointments) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final timeFormat = DateFormat('HH:mm');
    final statusColor = Color(appointment.status.colorValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.cardBorderRadius,
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: AppTheme.cardBorderRadius,
        onTap: () => _showAppointmentDetails(appointment),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con tipo y estado
              Row(
                children: [
                  Text(
                    appointment.type.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: AppTheme.buttonBorderRadius,
                    ),
                    child: Text(
                      appointment.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Hora
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textColor2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${timeFormat.format(appointment.dateTime)} - ${timeFormat.format(appointment.endTime)}',
                    style: const TextStyle(
                      color: AppColors.textColor2,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              // Cliente (si existe)
              if (appointment.clientName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.textColor2,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        appointment.clientName!,
                        style: const TextStyle(
                          color: AppColors.textColor2,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              // Propiedad (si existe)
              if (appointment.propertyAddress != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.textColor2,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        appointment.propertyAddress!,
                        style: const TextStyle(
                          color: AppColors.textColor2,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFinishedAppointmentsDialog(List<Appointment> finishedAppointments) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'es_ES');
    final dayString = _selectedDay != null
        ? dateFormat.format(_selectedDay!)
        : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, color: AppColors.primaryColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Citas terminadas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    dayString,
                    style: const TextStyle(fontSize: 12, color: AppColors.textColor2, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: finishedAppointments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final appt = finishedAppointments[index];
              final statusColor = Color(appt.status.colorValue);
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                title: Text(
                  appt.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${appt.status.displayName}  •  ${timeFormat.format(appt.dateTime)} - ${timeFormat.format(appt.endTime)}',
                  style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
                ),
                leading: Icon(
                  appt.status == AppointmentStatus.completed ? Icons.check_circle : Icons.cancel,
                  color: statusColor,
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAppointmentDetails(appt);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _createNewAppointment() async {
    final result = await Navigator.push<Appointment>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAppointmentScreen(
          initialDate: _selectedDay ?? DateTime.now(),
        ),
      ),
    );

    if (result != null && mounted) {
      context.read<AppointmentProvider>().addAppointment(result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita creada exitosamente'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showAppointmentDetails(Appointment appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundLevel3,
      builder: (context) => AppointmentDetailsSheet(
        appointment: appointment,
        onEdit: () => _editAppointment(appointment),
        onDelete: () => _deleteAppointment(appointment),
        onStatusChange: (status) => _changeAppointmentStatus(appointment, status),
      ),
    );
  }

  void _editAppointment(Appointment appointment) async {
    Navigator.pop(context); // Cerrar el bottom sheet
    
    final result = await Navigator.push<Appointment>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAppointmentScreen(
          initialDate: appointment.dateTime,
          appointment: appointment,
        ),
      ),
    );

    if (result != null && mounted) {
      context.read<AppointmentProvider>().updateAppointment(result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita actualizada exitosamente'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _deleteAppointment(Appointment appointment) async {
    Navigator.pop(context); // Cerrar el bottom sheet
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cita'),
        content: Text('¿Estás seguro de que deseas eliminar "${appointment.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<AppointmentProvider>().deleteAppointment(appointment.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita eliminada'),
          backgroundColor: AppColors.textColor2,
        ),
      );
    }
  }

  void _changeAppointmentStatus(Appointment appointment, AppointmentStatus status) {
    Navigator.pop(context); // Cerrar el bottom sheet
    context.read<AppointmentProvider>().updateAppointmentStatus(appointment.id, status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Estado cambiado a: ${status.displayName}'),
        backgroundColor: Color(status.colorValue),
      ),
    );
  }
}
