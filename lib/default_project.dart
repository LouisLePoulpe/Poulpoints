/// Chooses the project for a newly created task.
/// The currently opened project takes precedence, but global views use the
/// persisted default. A deleted project never becomes the active default.
String resolveInitialProject(
  List<String> available, {
  String? selectedProject,
  String? preferredProject,
}) {
  if (selectedProject != null && available.contains(selectedProject)) {
    return selectedProject;
  }
  if (preferredProject != null && available.contains(preferredProject)) {
    return preferredProject;
  }
  if (available.contains('Personnel')) return 'Personnel';
  if (available.isNotEmpty) return available.first;
  return 'Personnel';
}
