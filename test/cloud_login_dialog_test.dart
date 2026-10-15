import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/cloud/cloud_login_dialog.dart';

void main() {
  testWidgets('La validation du dialogue ne dispose pas les champs trop tôt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CloudLoginDetails? details;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                details = await showDialog<CloudLoginDetails>(
                  context: context,
                  builder: (_) => const CloudLoginDialog(
                    initialUrl: 'https://demo.supabase.co',
                    initialPublicKey: 'sb_publishable_demo',
                  ),
                );
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextFormField);
    expect(inputs, findsNWidgets(4));
    await tester.enterText(inputs.at(2), 'personne@example.org');
    await tester.enterText(inputs.at(3), 'mot-de-passe-test');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(details, isNotNull);
    expect(details!.url, 'https://demo.supabase.co');
    expect(details!.publicKey, 'sb_publishable_demo');
    expect(details!.email, 'personne@example.org');
    expect(details!.password, 'mot-de-passe-test');
    expect(find.byType(CloudLoginDialog), findsNothing);
  });

  testWidgets('Annuler ferme proprement le dialogue', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<CloudLoginDetails>(
                context: context,
                builder: (_) => const CloudLoginDialog(),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CloudLoginDialog), findsNothing);
  });
}
