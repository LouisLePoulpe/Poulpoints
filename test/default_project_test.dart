import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/default_project.dart';

void main() {
  const projects = ['Travail', 'Personnel', 'Autre'];

  test('Explicit default beats first alphabetical project in global views', () {
    expect(resolveInitialProject(projects, preferredProject: 'Travail'), 'Travail');
    expect(resolveInitialProject(projects, preferredProject: 'Autre'), 'Autre');
  });

  test('Current project view beats default', () {
    expect(resolveInitialProject(projects,
      selectedProject: 'Travail', preferredProject: 'Personnel'), 'Travail');
  });

  test('Deleted or missing default falls back safely', () {
    expect(resolveInitialProject(projects, preferredProject: 'Effacé'), 'Personnel');
    expect(resolveInitialProject(['Pro'], preferredProject: 'Effacé'), 'Pro');
    expect(resolveInitialProject([], preferredProject: 'Effacé'), 'Personnel');
  });
}
