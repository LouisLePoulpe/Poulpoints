import 'calendar_localizations.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'recurrence.dart';
export 'task_actions.dart' show completeTask;

String formatDeadline(DateTime date, bool withTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}'
      '${withTime ? ' à ${two(date.hour)}:${two(date.minute)}' : ''}';
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    this.existing,
    required this.lists,
    required this.initialList,
    this.fullScreen = false,
  });
  final bool fullScreen;
  final Task? existing;
  final List<String> lists;
  final String initialList;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController location;
  late final TextEditingController notes;
  final subs = <({String id, bool done, TextEditingController text})>[];
  final retired = <TextEditingController>[];
  late String list;
  late String recurrence;
  late bool priority;
  late bool hasTime;
  int? reminderMinutes;
  final Set<int> extraReminders = {};
  late final TextEditingController tags;
  DateTime? due;
  int sequence = 0;
  late final TextEditingController intervalController;
  String unit = 'daily';
  Set<int> selectedDays = {1};
  String monthMode = 'date';
  int monthDay = 1;
  int ordinal = 1;
  int weekday = 6;
  RecurrenceRule get rule => RecurrenceRule(
    unit: unit,
    interval: (int.tryParse(intervalController.text) ?? 1).clamp(1, 999),
    days: (selectedDays.isEmpty ? [1] : selectedDays.toList())..sort(),
    monthMode: monthMode,
    monthDay: monthDay,
    ordinal: ordinal,
    weekday: weekday,
  );

  @override
  void initState() {
    super.initState();
    final task = widget.existing;
    title = TextEditingController(text: task?.title ?? '');
    location = TextEditingController(text: task?.location ?? '');
    tags = TextEditingController(text: task?.tags.join(', ') ?? '');
    extraReminders.addAll(task?.reminders ?? []);
    notes = TextEditingController(text: task?.notes ?? '');
    list = task?.list ?? widget.initialList;
    recurrence = task?.recurrence ?? 'none';
    priority = task?.priority ?? false;
    hasTime = task?.hasDueTime ?? false;
    reminderMinutes = task?.reminderMinutes;
    due = task?.dueDate?.toLocal();
    final saved = task?.recurrenceRule;
    intervalController = TextEditingController(text: '${saved?.interval ?? 1}');
    unit = saved?.unit ?? 'daily';
    selectedDays = (saved?.days ?? [due?.weekday ?? 1]).toSet();
    monthMode = saved?.monthMode ?? 'date';
    monthDay = saved?.monthDay ?? due?.day ?? 1;
    ordinal = saved?.ordinal ?? 1;
    weekday = saved?.weekday ?? 6;
    for (final sub in task?.subtasks ?? <Subtask>[]) {
      subs.add((
        id: sub.id,
        done: sub.done,
        text: TextEditingController(text: sub.title),
      ));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      tags,
      intervalController,
      location,
      notes,
      ...subs.map((s) => s.text),
      ...retired,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) return;
    Navigator.pop(
      context,
      Task(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.text.trim(),
        list: list,
        done: widget.existing?.done ?? false,
        priority: priority,
        dueDate: recurrence == 'custom' && due != null
            ? rule.next(due!, inclusive: true)
            : due,
        hasDueTime: due != null && hasTime,
        reminderMinutes: due != null && hasTime ? reminderMinutes : null,
        reminderOffsets: due != null && hasTime
            ? ({
                ...?(reminderMinutes == null ? null : [reminderMinutes!]),
                ...extraReminders,
              }.toList()..sort())
            : [],
        tags: tags.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList(),
        occurrenceAnchor: widget.existing?.occurrenceAnchor,
        snoozedUntil: widget.existing?.snoozedUntil,
        location: location.text.trim(),
        notes: notes.text,
        recurrence: recurrence,
        recurrenceRule: recurrence == 'custom' ? rule : null,
        subtasks: [
          for (final sub in subs)
            Subtask(id: sub.id, title: sub.text.text.trim(), done: sub.done),
        ],
      ),
    );
  }

  Future<void> pickDate() async {
    final current = due ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year < 2000 ? current.year : 2000),
      lastDate: DateTime(current.year > 2100 ? current.year : 2100, 12, 31),
    );
    if (!mounted || selected == null) return;
    setState(
      () => due = DateTime(
        selected.year,
        selected.month,
        selected.day,
        hasTime ? current.hour : 0,
        hasTime ? current.minute : 0,
      ),
    );
  }

  Future<void> pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(due!),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      due = DateTime(
        due!.year,
        due!.month,
        due!.day,
        selected.hour,
        selected.minute,
      );
      hasTime = true;
    });
  }

  Future<void> _showRecurrenceHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 10),
            Expanded(child: Text('Répétition personnalisée')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'La date choisie sert de point de départ à la répétition. '
            'La première échéance est ajustée au prochain jour correspondant.\n\n'
            'Pour les répétitions mensuelles fixées au 29, 30 ou 31, '
            'les mois plus courts utilisent leur dernier jour.\n\n'
            'Terminer une tâche récurrente fait avancer son échéance '
            'à la prochaine occurrence et réinitialise ses sous-tâches.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Widget _buildFields(BuildContext context) => Form(
    key: form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: title,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Que faut-il faire ?'),
          validator: (value) =>
              value!.trim().isEmpty ? 'Saisissez un titre.' : null,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: list,
          decoration: const InputDecoration(labelText: 'Liste'),
          items: [
            for (final name in widget.lists)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (value) => setState(() => list = value!),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<bool>(
          isExpanded: true,
          initialValue: priority,
          decoration: const InputDecoration(labelText: 'Priorité'),
          items: const [
            DropdownMenuItem(value: false, child: Text('Normale')),
            DropdownMenuItem(value: true, child: Text('Importante')),
          ],
          onChanged: (value) => setState(() => priority = value!),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: recurrence,
          decoration: const InputDecoration(
            labelText: 'Répétition / périodicité',
          ),
          items: [
            for (final entry in recurrenceLabels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) => setState(() => recurrence = value!),
          validator: (_) => recurrence != 'none' && due == null
              ? 'Choisissez une date pour la répétition.'
              : null,
        ),
        if (recurrence == 'custom') ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Text('Répétition personnalisée')),
              IconButton(
                tooltip: 'Informations sur la répétition personnalisée',
                icon: const Icon(Icons.info_outline),
                onPressed: _showRecurrenceHelp,
              ),
            ],
          ),
          TextFormField(
            controller: intervalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Intervalle (1 à 999)',
            ),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              final n = int.tryParse(value ?? '');
              return n == null || n < 1 || n > 999
                  ? 'Entrez un nombre de 1 à 999.'
                  : null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: unit,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unité'),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Jours')),
              DropdownMenuItem(value: 'weekly', child: Text('Semaines')),
              DropdownMenuItem(value: 'monthly', child: Text('Mois')),
            ],
            onChanged: (value) => setState(() => unit = value!),
          ),
          if (unit == 'weekly')
            FormField<Set<int>>(
              validator: (_) =>
                  selectedDays.isEmpty ? 'Choisissez au moins un jour.' : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(weekdays[day - 1]),
                          selected: selectedDays.contains(day),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          }),
                        ),
                    ],
                  ),
                  if (field.hasError)
                    Text(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          if (unit == 'monthly') ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: monthMode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Règle mensuelle'),
              items: const [
                DropdownMenuItem(value: 'date', child: Text('Jour du mois')),
                DropdownMenuItem(
                  value: 'ordinal',
                  child: Text('Jour de la semaine'),
                ),
              ],
              onChanged: (value) => setState(() => monthMode = value!),
            ),
            const SizedBox(height: 14),
            if (monthMode == 'date')
              DropdownButtonFormField<int>(
                initialValue: monthDay,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jour du mois'),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (value) => setState(() => monthDay = value!),
              ),
            if (monthMode == 'ordinal') ...[
              DropdownButtonFormField<int>(
                initialValue: ordinal,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Position dans le mois',
                ),
                items: [
                  for (final entry in ordinals.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => ordinal = value!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: weekday,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Jour de la semaine',
                ),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(value: d, child: Text(weekdays[d - 1])),
                ],
                onChanged: (value) => setState(() => weekday = value!),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Text(rule.label),
          if (due != null && selectedDays.isNotEmpty)
            Text(
              'Première échéance : ${formatDeadline(rule.next(due!, inclusive: true), hasTime)}',
            ),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(
            due == null ? 'Définir une échéance' : formatDeadline(due!, false),
          ),
          onTap: pickDate,
          trailing: due == null
              ? null
              : IconButton(
                  tooltip: 'Effacer l’échéance',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    due = null;
                    hasTime = false;
                  }),
                ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(
            hasTime && due != null
                ? 'Heure : ${due!.hour.toString().padLeft(2, '0')}:${due!.minute.toString().padLeft(2, '0')}'
                : 'Définir une heure',
          ),
          subtitle: due == null
              ? const Text('Choisissez d’abord une date.')
              : null,
          onTap: due == null ? null : pickTime,
          trailing: !hasTime
              ? null
              : IconButton(
                  tooltip: 'Effacer l’heure',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    due = DateTime(due!.year, due!.month, due!.day);
                    hasTime = false;
                  }),
                ),
        ),
        const SizedBox(height: 16),
        const Text('Rappels'),
        const SizedBox(height: 8),
        if (due != null && hasTime) ...[
          for (final minutes in (extraReminders.toList()..sort()))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('reminder-row-$minutes'),
                      initialValue: minutes,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.notifications_outlined),
                      ),
                      items: [
                        for (final value in ({
                          0,
                          5,
                          15,
                          30,
                          60,
                          1440,
                          minutes,
                        }.toList()..sort()))
                          if (value == minutes ||
                              !extraReminders.contains(value))
                            DropdownMenuItem(
                              value: value,
                              child: Text(reminderLabel(value)),
                            ),
                      ],
                      onChanged: (value) => setState(() {
                        if (value != null) {
                          extraReminders.remove(minutes);
                          extraReminders.add(value);
                        }
                        reminderMinutes = null;
                      }),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Supprimer ce rappel',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      extraReminders.remove(minutes);
                      reminderMinutes = null;
                    }),
                  ),
                ],
              ),
            ),
          if ({0, 5, 15, 30, 60, 1440}.difference(extraReminders).isNotEmpty)
            DropdownButtonFormField<int>(
              key: ValueKey('add-reminder-${extraReminders.join(',')}'),
              hint: const Text('Ajouter un rappel'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.add_alarm),
              ),
              items: [
                for (final value in [0, 5, 15, 30, 60, 1440])
                  if (!extraReminders.contains(value))
                    DropdownMenuItem(
                      value: value,
                      child: Text(reminderLabel(value)),
                    ),
              ],
              onChanged: (value) => setState(() {
                if (value != null) extraReminders.add(value);
                reminderMinutes = null;
              }),
            ),
        ] else
          const Text(
            'Choisissez une date et une heure pour ajouter un rappel.',
          ),
        const SizedBox(height: 24),
        TextFormField(
          controller: tags,
          decoration: const InputDecoration(
            labelText: 'Étiquettes',
            hintText: 'maison, courses, urgent',
          ),
          validator: (v) =>
              v!.split(',').where((t) => t.trim().isNotEmpty).length > 50 ||
                  v.split(',').any((t) => t.trim().length > 100)
              ? '50 étiquettes maximum, 100 caractères chacune.'
              : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: location,
          decoration: const InputDecoration(
            labelText: 'Lieu',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Sous-tâches'),
        for (final sub in subs)
          Padding(
            key: ValueKey(sub.id),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: sub.text,
                    decoration: const InputDecoration(labelText: 'Sous-tâche'),
                    validator: (value) => value!.trim().isEmpty
                        ? 'Saisissez un titre ou supprimez cette ligne.'
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer la sous-tâche',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    subs.remove(sub);
                    retired.add(sub.text);
                  }),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(
            () => subs.add((
              id: '${DateTime.now().microsecondsSinceEpoch}_${sequence++}',
              done: false,
              text: TextEditingController(),
            )),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une sous-tâche'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: notes,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final heading = widget.existing == null
        ? 'Nouvelle tâche'
        : 'Modifier la tâche';
    final fields = _buildFields(context);

    if (widget.fullScreen) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(heading)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: fields,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: save,
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(heading),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(child: fields),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: save, child: const Text('Enregistrer')),
      ],
    );
  }
}
