import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:poulpoints/storage/database_handle.dart';
import 'package:poulpoints/storage/task_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsRepository repository;
  setUp(() async {
    repository = SettingsRepository(
      DatabaseHandle(
        await newDatabaseFactoryMemory().openDatabase('settings-ui'),
      ),
    );
  });
  tearDown(() => repository.close());

  test('Automatic retry intervals are bounded to avoid excess cloud usage', () {
    expect(cloudRetryDelay(0), const Duration(seconds: 15));
    expect(cloudRetryDelay(1), const Duration(seconds: 15));
    expect(cloudRetryDelay(2), const Duration(seconds: 30));
    expect(cloudRetryDelay(3), const Duration(seconds: 60));
    expect(cloudRetryDelay(4), const Duration(seconds: 120));
    expect(cloudRetryDelay(10), const Duration(seconds: 240));
  });

  testWidgets(
    'Desktop navigation is aligned and settings are a separate page',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(PoulpointsApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Ancien serveur expérimental'), findsNothing);
      final personal = find.widgetWithText(ListTile, 'Personnel');
      final work = find.widgetWithText(ListTile, 'Travail');
      final stats = find.widgetWithText(ListTile, 'Statistiques');
      expect(tester.getTopLeft(personal).dx, tester.getTopLeft(work).dx);
      expect(tester.getTopLeft(work).dx, tester.getTopLeft(stats).dx);

      await tester.tap(find.text('Paramètres'));
      await tester.pumpAndSettle();
      expect(find.text('Se connecter'), findsWidgets);
      expect(find.text('À propos'), findsOneWidget);
      expect(find.text('Version 0.8.5 (build 26)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sauvegardes'),
        110,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Sauvegardes'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ancien serveur expérimental'),
        110,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Ancien serveur expérimental'), findsOneWidget);
      expect(find.text('Synchroniser avec l’ancien serveur'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Projet par défaut'),
        110,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Projet par défaut'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Apparence'),
        110,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Apparence'), findsOneWidget);
      expect(find.text('Toutes'), findsWidgets);

      await tester.tap(find.text('Toutes'));
      await tester.pumpAndSettle();
      expect(find.text('Ancien serveur expérimental'), findsNothing);
      expect(find.text('Sauvegardes'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Chosen default project persists and new tasks use it', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(PoulpointsApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    // The settings ListView builds children lazily. First scroll until the
    // target text is BUILT; calling ensureVisible() before that throws
    // StateError: Bad state: No element.
    await tester.scrollUntilVisible(
      find.text('Projet par défaut'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    // The newly built tile may still be partially outside the viewport.
    final defaultProjectTile =
        find.widgetWithText(ListTile, 'Projet par défaut');
    await tester.ensureVisible(defaultProjectTile);
    await tester.pumpAndSettle();
    await tester.tap(defaultProjectTile);
    await tester.pumpAndSettle();
    expect(find.text('Choisir le projet par défaut'), findsOneWidget);
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Travail'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('poulpoints_default_project_v1'), 'Travail');
    await tester.tap(find.text('Toutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une tâche'));
    await tester.pumpAndSettle();
    final listField = find.widgetWithText(DropdownButtonFormField<String>, 'Liste');
    expect(tester.widget<DropdownButtonFormField<String>>(listField).initialValue, 'Travail');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

}

class SettingsRepository extends TaskRepository {
  SettingsRepository(super.handle);
  @override
  Future<TaskSnapshot> load(SharedPreferences prefs) async =>
      TaskSnapshot(tasks: [], projects: ['Personnel', 'Travail'], deleted: {});
}
