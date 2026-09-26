/// Fixed lithology / material labels for non-fossil Identify assessments.
abstract final class RockLithology {
  static const labels = <String>[
    'conglomerate',
    'sandstone',
    'limestone',
    'shale',
    'basalt',
    'granite',
    'chert',
    'concrete',
    'other_rock',
  ];

  static const displayNames = <String, String>{
    'conglomerate': 'Conglomerate',
    'sandstone': 'Sandstone',
    'limestone': 'Limestone',
    'shale': 'Shale',
    'basalt': 'Basalt',
    'granite': 'Granite',
    'chert': 'Chert',
    'concrete': 'Concrete',
    'other_rock': 'Other rock / material',
  };

  /// Maps model output onto the fixed list (fallback: other_rock).
  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'other_rock';
    final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    if (labels.contains(key)) return key;

    // Light synonym / substring matching.
    final lower = raw.trim().toLowerCase();
    if (lower.contains('conglomer') || lower.contains('breccia')) {
      return 'conglomerate';
    }
    if (lower.contains('sand')) return 'sandstone';
    if (lower.contains('lime') || lower.contains('chalk')) return 'limestone';
    if (lower.contains('shale') || lower.contains('mudstone')) return 'shale';
    if (lower.contains('basalt')) return 'basalt';
    if (lower.contains('granite')) return 'granite';
    if (lower.contains('chert') || lower.contains('flint')) return 'chert';
    if (lower.contains('concrete') || lower.contains('cement')) {
      return 'concrete';
    }
    return 'other_rock';
  }

  static String displayName(String? raw) {
    final key = normalize(raw);
    return displayNames[key] ?? displayNames['other_rock']!;
  }
}
