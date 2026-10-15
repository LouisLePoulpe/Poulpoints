import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/storage/task_repository.dart';
import 'package:poulpoints/storage/database_handle.dart';

class ProjectRepository extends TaskRepository {
  ProjectRepository(super.handle);
  TaskSnapshot data = TaskSnapshot(
    tasks: [
      const Task(
        id: 'a',
        title: 'À conserver',
        list: 'Projet test',
        done: true,
        notes: 'Notes',
        tags: ['maison'],
      ),
    ],
    projects: ['Personnel', 'Projet test'],
    deleted: {},
  );
  @override
  Future<TaskSnapshot> load(SharedPreferences prefs) async => data;
  @override
  Future<void> save(TaskSnapshot snapshot) async {
    data = snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Project removal confirms relocation and preserves completed task fields',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = await newDatabaseFactoryMemory().openDatabase('project-ui');
      final repo = ProjectRepository(DatabaseHandle(db));
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(PoulpointsApp(repository: repo));
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, 'Projet test');
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.byTooltip('Supprimer ce projet'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(repo.data.projects, contains('Projet test'));
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.byTooltip('Supprimer ce projet'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Déplacer et supprimer le projet'));
      await tester.pumpAndSettle();
      expect(repo.data.projects, ['Personnel']);
      expect(repo.data.tasks.single.list, 'Personnel');
      expect(repo.data.tasks.single.done, true);
      expect(repo.data.tasks.single.notes, 'Notes');
      expect(repo.data.tasks.single.tags, ['maison']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await repo.close();
    },
  );
}
