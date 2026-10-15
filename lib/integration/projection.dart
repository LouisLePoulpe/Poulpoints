import '../models.dart';

Map<String, dynamic> projectTasks(List<Task> tasks) {
  final active = tasks.where((t) => !t.done).toList()
    ..sort((a, b) {
      final priority = (b.priority ? 1 : 0).compareTo(a.priority ? 1 : 0);
      if (priority != 0) return priority;
      final due = (a.dueDate?.millisecondsSinceEpoch ?? 8640000000000000)
          .compareTo(b.dueDate?.millisecondsSinceEpoch ?? 8640000000000000);
      return due != 0 ? due : a.id.compareTo(b.id);
    });
  return {
    'version': 1,
    'publishedAt': DateTime.now().millisecondsSinceEpoch,
    'tasks': [
      for (final t in active)
        {
          'id': t.id,
          'title': t.title,
          'list': t.list,
          'revision': t.updatedAt.toString(),
          'due': t.dueDate?.millisecondsSinceEpoch,
          'remindAts': {
            if (t.dueDate != null && t.hasDueTime)
              for (final minutes in t.reminders)
                t.dueDate!
                    .subtract(Duration(minutes: minutes))
                    .millisecondsSinceEpoch,
            if (t.snoozedUntil != null) t.snoozedUntil!.millisecondsSinceEpoch,
          }.toList()..sort(),
          'remindAt':
              t.dueDate != null && t.hasDueTime && t.reminders.isNotEmpty
              ? t.dueDate!
                    .subtract(Duration(minutes: t.reminders.first))
                    .millisecondsSinceEpoch
              : t.snoozedUntil?.millisecondsSinceEpoch,
        },
    ],
  };
}
