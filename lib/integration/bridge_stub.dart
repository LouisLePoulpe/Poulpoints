class PlatformBridge {
  bool get usesSharedRuntime => false;
  Future<void> publish(Map<String, dynamic> data) async {}
  Future<List<Map<String, dynamic>>> commands() async => [];
  void setCommandHandler(
    Future<void> Function() action, {
    Future<void> Function()? sync,
  }) {}
  Future<void> scheduleSync() async {}
  Future<void> ready() async {}
  Future<void> reportWidgetError(String message) async {}
  Future<void> ack(String token) async {}
  Future<String> permissions({
    bool request = false,
    bool exact = false,
  }) async => 'Rappels et widgets disponibles sur Android et Linux KDE.';
}
