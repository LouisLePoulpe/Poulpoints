import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/models.dart';
import 'package:poulpoints/task_actions.dart';

void main() {
  const task = Task(id: 'file-task', title: 'Document', list: 'Personnel');
  test(
    'Completion retires attachments exactly once and reopening does not restore them',
    () {
      final completed = completeTask(task, true);
      expect(completed.attachmentCycle, 1);
      expect(completeTask(completed, true).attachmentCycle, 1);
      final reopened = completeTask(completed, false);
      expect(reopened.done, false);
      expect(reopened.attachmentCycle, 1);
      expect(completeTask(reopened, true).attachmentCycle, 2);
    },
  );
  test('Recurring completion retires current occurrence attachments', () {
    final recurring = task.copyWith(
      recurrence: 'daily',
      dueDate: DateTime(2026, 10, 16, 12),
    );
    final next = completeTask(recurring, true);
    expect(next.done, false);
    expect(next.dueDate, DateTime(2026, 10, 17, 12));
    expect(next.attachmentCycle, 1);
    expect(moveOccurrence(next, DateTime(2026, 10, 18)).attachmentCycle, 1);
  });
  test('Attachment retirement survives serialization and ordinary edits', () {
    final completed = completeTask(task, true);
    expect(Task.fromJson(completed.toJson()).attachmentCycle, 1);
    expect(completed.copyWith(title: 'Changed').attachmentCycle, 1);
    final legacy = task.toJson()..remove('attachmentCycle');
    expect(Task.fromJson(legacy).attachmentCycle, 0);
  });
}
