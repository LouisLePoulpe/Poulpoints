import 'models.dart';

// Advance one calendar occurrence, preserving local wall-clock time.
// Monthly dates are clamped to the last day of the following month.
Task completeTask(Task task, bool done) {
  final date = task.occurrenceAnchor ?? task.dueDate;
  if (!done || task.done || date == null || task.recurrence == 'none') {
    return task.copyWith(
      done: done,
      clearSnooze: done,
      attachmentCycle: done && !task.done
          ? task.attachmentCycle + 1
          : task.attachmentCycle,
    );
  }
  final DateTime next;
  if (task.recurrence == 'custom') {
    if (task.recurrenceRule == null) {
      return task.copyWith(
        done: done,
        clearSnooze: done,
        attachmentCycle: done && !task.done
            ? task.attachmentCycle + 1
            : task.attachmentCycle,
      );
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
    attachmentCycle: task.attachmentCycle + 1,
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

// Subtask order is the list order itself: it is what the JSON payload, the
// cloud signature and older clients already store, so no extra field exists.

/// Trimmed title, or null when blank (the caller keeps the previous title).
String? cleanSubtaskTitle(String raw) {
  final title = raw.trim();
  return title.isEmpty ? null : title;
}

/// Same id and completion state; returns [task] itself when nothing changes,
/// so an unchanged dialog does not bump `updatedAt` or trigger a sync push.
Task renameSubtask(Task task, String id, String title) {
  final index = task.subtasks.indexWhere((s) => s.id == id);
  final clean = cleanSubtaskTitle(title);
  if (index < 0 || clean == null || task.subtasks[index].title == clean) {
    return task;
  }
  final old = task.subtasks[index];
  return task.copyWith(
    subtasks: [...task.subtasks]
      ..[index] = Subtask(id: old.id, title: clean, done: old.done),
  );
}

/// Moves the subtask at [from] so that it ends at index [to].
/// Out-of-range or identical indices return [task] unchanged.
Task moveSubtask(Task task, int from, int to) {
  final length = task.subtasks.length;
  if (from < 0 || from >= length || to < 0 || to >= length || from == to) {
    return task;
  }
  final subtasks = [...task.subtasks];
  subtasks.insert(to, subtasks.removeAt(from));
  return task.copyWith(subtasks: subtasks);
}
