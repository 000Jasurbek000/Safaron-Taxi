/// Bir-biriga yaqin / bir xil deb hisoblanadigan manzillar.
const List<List<String>> placeClusters = [
  [
    'qizil qala',
    'qizil qala ofy',
    'algabas',
    'sadvin',
    'sadvin mahalla',
    'qiziltepa',
  ],
  [
    'beruniy',
    'beruniy markazi',
    'beruniy balnitsa',
    'balnitsa',
    'hokimiyat',
    'beruniy hokimiyat',
    'beruniy tumani',
  ],
  [
    'urganch',
    'urganch vokzal',
    'urganch markazi',
  ],
  [
    'xiva',
    'xiva ichan qala',
  ],
  [
    'xonqa',
    'xonqa markazi',
  ],
  [
    'gurlan',
  ],
  [
    'tuproqqala',
    "tuproqqal'a",
    'tuproqqalʼa',
  ],
];

String normalizePlace(String raw) {
  var s = raw.trim().toLowerCase();
  s = s
      .replaceAll('ʼ', "'")
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('ʻ', "'");
  s = s.replaceAll(RegExp(r"[^\w\s']+"), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

int? _clusterIndex(String place) {
  final n = normalizePlace(place);
  if (n.isEmpty) return null;
  for (var i = 0; i < placeClusters.length; i++) {
    for (final alias in placeClusters[i]) {
      final a = normalizePlace(alias);
      if (n == a || n.contains(a) || a.contains(n)) return i;
    }
  }
  return null;
}

/// Ikki manzil bir klasterdami yoki matn sifatida o‘xshashmi.
bool placesRelated(String a, String b) {
  final na = normalizePlace(a);
  final nb = normalizePlace(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  if (na.contains(nb) || nb.contains(na)) return true;
  final ca = _clusterIndex(na);
  final cb = _clusterIndex(nb);
  return ca != null && ca == cb;
}

/// Qidiruv matni (qisman ham) manzilga mos keladimi.
bool placeMatchesQuery(String place, String query) {
  final q = normalizePlace(query);
  if (q.isEmpty) return true;
  final p = normalizePlace(place);
  if (p.contains(q) || q.contains(p)) return true;

  // Klasterdagi aliaslar orqali: "sadvin" → "qizil qala"
  final ci = _clusterIndex(place);
  if (ci != null) {
    for (final alias in placeClusters[ci]) {
      final a = normalizePlace(alias);
      if (a.contains(q) || q.contains(a)) return true;
    }
  }

  // Query o‘zi klasterga tushsa — shu klasterdagi joylar
  final cq = _clusterIndex(q);
  if (cq != null) {
    final placeCluster = _clusterIndex(place);
    if (placeCluster == cq) return true;
  }

  return false;
}

bool anyPlaceMatchesQuery(Iterable<String> places, String query) {
  final q = normalizePlace(query);
  if (q.isEmpty) return true;
  for (final p in places) {
    if (placeMatchesQuery(p, q)) return true;
  }
  return false;
}
