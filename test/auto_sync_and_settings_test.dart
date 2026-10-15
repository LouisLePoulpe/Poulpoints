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
      await tester.scrollUntilVisible(
        find.text('Apparence'),
        110,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Apparence'), findsOneWidget);
      expect(find.text('Synchroniser avec l’ancien serveur'), findsOneWidget);
      expect(find.text('Toutes'), findsWidgets);

      await tester.tap(find.text('Toutes'));
      await tester.pumpAndSettle();
      expect(find.text('Ancien serveur expérimental'), findsNothing);
      expect(find.text('Sauvegardes'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

class SettingsRepository extends TaskRepository {
  SettingsRepository(super.handle);
  @override
  Future<TaskSnapshot> load(SharedPreferences prefs) async =>
      TaskSnapshot(tasks: [], projects: ['Personnel', 'Travail'], deleted: {});
}
