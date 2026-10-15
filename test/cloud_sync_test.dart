import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poulpoints/cloud/cloud_sync.dart';
import 'package:poulpoints/cloud/supabase_cloud.dart';

void main() {
  group('Decision conservatrice 3 voies', () {
    test('Deux créations différentes sur le même identifiant = conflit', () {
      expect(decideChange('local', 'distant', null), CloudDecision.conflict);
    });
    test('Les changements cloud sont importés si le local est inchangé', () {
      expect(decideChange('ancien', 'nouveau', 'ancien'), CloudDecision.pull);
    });
    test('La modification locale est envoyée si le cloud est inchangé', () {
      expect(decideChange('nouveau', 'ancien', 'ancien'), CloudDecision.push);
    });
    test('Deux modifications concurrentes différentes sont bloquées', () {
      expect(decideChange('A', 'B', 'ancien'), CloudDecision.conflict);
    });
    test('Une suppression distante se propage sans ressusciter de tâche', () {
      expect(decideChange('ancien', '#deleted', 'ancien'), CloudDecision.pull);
    });
    test('Une suppression locale se propage avec tombstone', () {
      expect(decideChange('#deleted', 'ancien', 'ancien'), CloudDecision.push);
    });
    test('Deux modifications identiques sont sans conflit', () {
      expect(
        decideChange('nouveau', 'nouveau', 'ancien'),
        CloudDecision.unchanged,
      );
    });
    test('Empreinte identique malgré réorganisation des clés jsonb', () {
      expect(
        canonicalJson({
          'b': 1,
          'a': {'y': 2, 'x': 1},
        }),
        canonicalJson({
          'a': {'x': 1, 'y': 2},
          'b': 1,
        }),
      );
    });
  });

  test(
    'La connexion vérifie effectivement l’autorisation Poulpoints',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': 'token-de-test',
              'refresh_token': 'refresh-de-test',
              'expires_in': 3600,
              'user': {'id': 'identifiant'},
            }),
            200,
          );
        }
        if (request.url.path == '/rest/v1/poulapp_access') {
          expect(request.headers['authorization'], 'Bearer token-de-test');
          return http.Response('[{"app_id":"poulpoints"}]', 200);
        }
        fail('Route inattendue: ${request.url}');
      });
      final cloud = SupabaseCloud(
        url: 'https://example.supabase.co',
        publicKey: 'sb_publishable_test',
        httpClient: client,
      );
      await cloud.signIn('test@example.com', 'test-seulement');
      expect(cloud.signedIn, isTrue);
      expect(cloud.userId, 'identifiant');
      cloud.dispose();
    },
  );

  test('Refuse un compte sans autorisation Poulpoints', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': 'token',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'user': {'id': 'inconnu'},
          }),
          200,
        );
      }
      return http.Response('[]', 200);
    });
    final cloud = SupabaseCloud(
      url: 'https://example.supabase.co',
      publicKey: 'sb_publishable_test',
      httpClient: client,
    );
    await expectLater(
      cloud.signIn('test@example.com', 'test'),
      throwsA(isA<CloudException>()),
    );
    cloud.dispose();
  });

  test('Clé secrète Supabase rejetée', () {
    expect(
      () => SupabaseCloud(
        url: 'https://example.supabase.co',
        publicKey: 'sb_secret_incorrect',
      ),
      throwsFormatException,
    );
  });
}
