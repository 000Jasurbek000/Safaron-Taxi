class DriverExclusionService {
  DriverExclusionService._();
  static final instance = DriverExclusionService._();

  final Map<String, DateTime> _until = {};

  void excludeForTwoHours(String taxiId) {
    _until[taxiId] = DateTime.now().add(const Duration(hours: 2));
  }

  bool isExcluded(String taxiId) {
    final until = _until[taxiId];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _until.remove(taxiId);
      return false;
    }
    return true;
  }

  Set<String> get activeExcludedIds {
    final now = DateTime.now();
    _until.removeWhere((_, until) => now.isAfter(until));
    return _until.keys.toSet();
  }
}
