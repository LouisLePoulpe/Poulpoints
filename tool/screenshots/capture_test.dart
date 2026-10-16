// Render the real app with an isolated, fictional database; no user data or cloud.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/storage/task_repository.dart';
import 'package:poulpoints/storage/database_handle.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoRepository extends TaskRepository {
 DemoRepository(super.handle);
 @override Future<TaskSnapshot> load(SharedPreferences prefs) async => TaskSnapshot(tasks:[
  Task(id:'demo-1',title:'Préparer le week-end',list:'Personnel',priority:true,notes:'Réserver le train et préparer le sac.',subtasks:[Subtask(id:'a',title:'Réserver les billets'),Subtask(id:'b',title:'Préparer le sac')]),
  Task(id:'demo-2',title:'Arroser les plantes',list:'Maison',recurrence:'weekly',dueDate:DateTime(2026,11,7,9),hasDueTime:true),
  Task(id:'demo-3',title:'Lire un chapitre',list:'Personnel'),
  Task(id:'demo-4',title:'Préparer la présentation',list:'Travail',tags:['Projet'],notes:'Ajouter les idées de l’équipe.'),
 ],projects:['Personnel','Maison','Travail'],deleted:{});
}
void main(){
 debugDisableShadows=false;
 testWidgets('Capture real Poulpoints interface using demonstration tasks',(tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() async {
  final font=File(Platform.environment['POULPOINTS_SCREENSHOT_FONT']!);
  final loader=FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));await loader.load();
  final icons=FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(await File(Platform.environment['POULPOINTS_SCREENSHOT_ICONS']!).readAsBytes()))); await icons.load();
  });
  tester.view.physicalSize=const Size(1080,1920);tester.view.devicePixelRatio=2.75;
  final repository=DemoRepository(DatabaseHandle(await newDatabaseFactoryMemory().openDatabase('demo')));
  await tester.pumpWidget(PoulpointsApp(repository:repository));await tester.pumpAndSettle();
  await tester.runAsync(() => precacheImage(const AssetImage('assets/poulpoints_logo.png'), tester.element(find.byType(MaterialApp))));await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp),matchesGoldenFile('../../fastlane/metadata/android/fr-FR/images/phoneScreenshots/01-taches.png'));
  await tester.tap(find.text('Préparer le week-end'));await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp),matchesGoldenFile('../../fastlane/metadata/android/fr-FR/images/phoneScreenshots/02-details.png'));
  await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();await repository.close();
  tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
 });
}
