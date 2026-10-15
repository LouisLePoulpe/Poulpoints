import 'models.dart';

// Advance one calendar occurrence, preserving local wall-clock time.
// Monthly dates are clamped to the last day of the following month.
Task completeTask(Task task, bool done) {
  final date = task.occurrenceAnchor ?? task.dueDate;
  if (!done || task.done || date == null || task.recurrence == 'none') {
    return task.copyWith(done: done, clearSnooze: done);
  }
  final DateTime next;
  if (task.recurrence == 'custom') {
    if (task.recurrenceRule == null) {
      return task.copyWith(done: done, clearSnooze: done);
    }
    next = task.recurrenceRule!.next(date.toLocal());
  } else if (task.recurrence == 'monthly') {
    final lastDay = DateTime(date.year, date.month + 2, 0).day;
    next = DateTime(
      date.year,
      date.month + 1,
      date.day > lastDay ? lastDay : date.day,
      date.hour,
      date.minute,
    );
  } else {
    next = DateTime(
      date.year,
      date.month,
      date.day + (task.recurrence == 'weekly' ? 7 : 1),
      date.hour,
      date.minute,
    );
  }
  return task.copyWith(
    done: false,
    clearOccurrenceAnchor: true,
    clearSnooze: true,
    dueDate: next,
    subtasks: [
      for (final sub in task.subtasks) Subtask(id: sub.id, title: sub.title),
    ],
  );
}

// Only this occurrence moves; the original date anchors the following one.
Task moveOccurrence(Task task, DateTime date) => task.copyWith(
  dueDate: date,
  occurrenceAnchor: task.occurrenceAnchor ?? task.dueDate,
  clearSnooze: true,
);
