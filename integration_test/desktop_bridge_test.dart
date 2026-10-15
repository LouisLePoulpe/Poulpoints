// Run only with isolated XDG_DATA_HOME and XDG_CONFIG_HOME; writes fixture data.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/integration/platform_bridge.dart';
import 'package:poulpoints/storage/task_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Linux widget command commits recurrence and updates reminder projection',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repository = await TaskRepository.open();
      await repository.load(prefs);
      final date = DateTime.now().add(const Duration(days: 2));
      await repository.save(
        TaskSnapshot(
          tasks: [
            Task(
              id: 'desktop-fixture',
              title: 'Widget Linux',
              list: 'Personnel',
              dueDate: date,
              hasDueTime: true,
              reminderMinutes: 15,
              recurrence: 'daily',
              updatedAt: 42,
            ),
          ],
          projects: ['Personnel'],
          deleted: {},
        ),
      );
      await tester.pumpWidget(
        PoulpointsApp(
          repository: repository,
          integrationBridge: PlatformBridge(),
        ),
      );
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(seconds: 1));
      final root = Directory(
        '${Platform.environment['XDG_DATA_HOME']}/poulpoints-desktop',
      );
      final snapshot = File('${root.path}/snapshot.json');
      expect(await snapshot.exists(), true);
      final queue = Directory('${root.path}/commands');
      await queue.create(recursive: true);
      final command = File('${queue.path}/integration-test.json');
      await command.writeAsString(
        jsonEncode({
          'action': 'complete',
          'id': 'desktop-fixture',
          'revision': '42',
        }),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final saved = (await repository.load(prefs)).tasks.single;
      expect(
        saved.dueDate,
        DateTime(date.year, date.month, date.day + 1, date.hour, date.minute),
      );
      expect(await command.exists(), false);
      final published = jsonDecode(await snapshot.readAsString());
      expect(
        published['tasks'][0]['remindAt'],
        saved.dueDate!
            .subtract(const Duration(minutes: 15))
            .millisecondsSinceEpoch,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await repository.close();
    },
    skip: !Platform.isLinux,
  );
}
