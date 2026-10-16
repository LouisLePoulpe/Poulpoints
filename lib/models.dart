import 'recurrence.dart';

const recurrenceLabels = {
  'none': 'Aucune',
  'daily': 'Tous les jours',
  'weekly': 'Toutes les semaines',
  'monthly': 'Tous les mois',
  'custom': 'Personnalisée…',
};

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.list,
    this.done = false,
    this.priority = false,
    this.dueDate,
    this.notes = '',
    this.location = '',
    this.recurrence = 'none',
    this.recurrenceRule,
    this.hasDueTime = false,
    this.subtasks = const [],
    this.updatedAt = 0,
    this.reminderMinutes,
    this.reminderOffsets,
    this.tags = const [],
    this.occurrenceAnchor,
    this.snoozedUntil,
    this.attachmentCycle = 0,
  });

  final String id;
  final String title;
  final String list;
  final bool done;
  final bool priority;
  final DateTime? dueDate;
  final String notes;
  final String location;
  final String recurrence;
  final RecurrenceRule? recurrenceRule;
  final bool hasDueTime;
  final List<Subtask> subtasks;
  final int updatedAt;
  final int? reminderMinutes;
  final List<int>? reminderOffsets;
  final List<String> tags;
  final DateTime? occurrenceAnchor;
  final DateTime? snoozedUntil;
  final int attachmentCycle;
  List<int> get reminders =>
      (reminderOffsets ??
              (reminderMinutes == null ? <int>[] : [reminderMinutes!]))
          .toSet()
          .toList()
        ..sort();

  Task copyWith({
    String? title,
    String? list,
    bool? done,
    bool? priority,
    String? location,
    String? recurrence,
    RecurrenceRule? recurrenceRule,
    bool? hasDueTime,
    DateTime? dueDate,
    bool removeDueDate = false,
    int? reminderMinutes,
    bool removeReminder = false,
    List<int>? reminderOffsets,
    List<String>? tags,
    DateTime? occurrenceAnchor,
    bool clearOccurrenceAnchor = false,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
    int? attachmentCycle,
    String? notes,
    List<Subtask>? subtasks,
  }) => Task(
    id: id,
    attachmentCycle: attachmentCycle ?? this.attachmentCycle,
    title: title ?? this.title,
    list: list ?? this.list,
    done: done ?? this.done,
    priority: priority ?? this.priority,
    dueDate: removeDueDate ? null : (dueDate ?? this.dueDate),
    reminderMinutes: removeReminder || removeDueDate
        ? null
        : (reminderMinutes ?? this.reminderMinutes),
    reminderOffsets: removeReminder || removeDueDate
        ? []
        : reminderOffsets ??
              (reminderMinutes == null
                  ? this.reminderOffsets
                  : [reminderMinutes]),
    tags: tags ?? this.tags,
    occurrenceAnchor: clearOccurrenceAnchor
        ? null
        : occurrenceAnchor ?? this.occurrenceAnchor,
    snoozedUntil: clearSnooze || removeDueDate
        ? null
        : snoozedUntil ?? this.snoozedUntil,
    location: location ?? this.location,
    recurrence: recurrence ?? this.recurrence,
    recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    hasDueTime: removeDueDate ? false : (hasDueTime ?? this.hasDueTime),
    notes: notes ?? this.notes,
    subtasks: subtasks ?? this.subtasks,
    updatedAt: DateTime.now().toUtc().microsecondsSinceEpoch,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (attachmentCycle > 0) 'attachmentCycle': attachmentCycle,
    'title': title,
    'list': list,
    'done': done,
    'priority': priority,
    'dueDate': dueDate?.toIso8601String(),
    'notes': notes,
    'subtasks': subtasks.map((s) => s.toJson()).toList(),
    'updatedAt': updatedAt,
    'location': location,
    'recurrence': recurrence,
    'recurrenceRule': recurrenceRule?.toJson(),
    'hasDueTime': hasDueTime,
    if (reminders.isNotEmpty) 'reminderMinutes': reminders.first,
    if (reminderOffsets != null) 'reminderOffsets': reminders,
    if (tags.isNotEmpty) 'tags': tags,
    if (occurrenceAnchor != null)
      'occurrenceAnchor': occurrenceAnchor!.toIso8601String(),
    if (snoozedUntil != null) 'snoozedUntil': snoozedUntil!.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> data) => Task(
    attachmentCycle: (data['attachmentCycle'] as num?)?.toInt() ?? 0,
    reminderMinutes: data['reminderMinutes'] as int?,
    reminderOffsets: (data['reminderOffsets'] as List?)?.cast<int>(),
    tags: (data['tags'] as List?)?.cast<String>() ?? const [],
    occurrenceAnchor: DateTime.tryParse(
      data['occurrenceAnchor'] as String? ?? '',
    ),
    snoozedUntil: DateTime.tryParse(data['snoozedUntil'] as String? ?? ''),
    id: data['id'] as String,
    title: data['title'] as String,
    list: data['list'] as String? ?? 'Personnel',
    done: data['done'] as bool? ?? false,
    priority: data['priority'] as bool? ?? false,
    dueDate: DateTime.tryParse(data['dueDate'] as String? ?? ''),
    updatedAt: (data['updatedAt'] as num?)?.toInt() ?? 0,
    location: data['location'] as String? ?? '',
    recurrence: recurrenceLabels.containsKey(data['recurrence'])
        ? data['recurrence'] as String
        : 'none',
    recurrenceRule: data['recurrenceRule'] == null
        ? null
        : RecurrenceRule.fromJson(
            data['recurrenceRule'] as Map<String, dynamic>,
          ),
    hasDueTime: data['hasDueTime'] as bool? ?? false,
    notes: data['notes'] as String? ?? '',
    subtasks: ((data['subtasks'] as List<dynamic>?) ?? [])
        .map((s) => Subtask.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

class Subtask {
  const Subtask({required this.id, required this.title, this.done = false});
  final String id;
  final String title;
  final bool done;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
    id: json['id'] as String,
    title: json['title'] as String,
    done: json['done'] as bool? ?? false,
  );
}
