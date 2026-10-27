import 'models.dart';

/// A date-only deadline is due at 00:00 local time on its specified day.
/// Completed tasks are never displayed as overdue.
bool isTaskOverdue(Task task, DateTime now) =>
    !task.done && task.dueDate != null && task.dueDate!.isBefore(now);

/// Calendar-day difference (not elapsed 24-hour periods, which vary with DST).
/// On the due date itself, a passed deadline simply reads "En retard".
String? overdueLabel(Task task, DateTime now) {
  if (!isTaskOverdue(task, now)) return null;
  final deadline = task.dueDate!.toLocal();
  final localNow = now.toLocal();
  final dueDay = DateTime.utc(deadline.year, deadline.month, deadline.day);
  final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final days = today.difference(dueDay).inDays;
  return days <= 0 ? 'En retard' : 'J+$days';
}
