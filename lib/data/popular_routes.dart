import '../services/active_booking_service.dart';
import 'mock_taxis.dart';

class PopularRoute {
  const PopularRoute({
    required this.from,
    required this.to,
    required this.count,
    required this.priceLabel,
    required this.imageAsset,
  });

  final String from;
  final String to;
  final int count;
  final String priceLabel;
  final String imageAsset;

  String get title => '$from → $to';
  String get subtitle => '$count ta safar';
}

/// Yakunlangan safarlar va haydovchi e’lonlaridan mashhur yo‘nalishlar.
List<PopularRoute> popularRoutes({int limit = 6}) {
  final counts = <String, int>{};
  final samples = <String, (String, String)>{};

  void bump(String from, String to) {
    if (from.trim().isEmpty && to.trim().isEmpty) return;
    final key = '$from|$to';
    counts[key] = (counts[key] ?? 0) + 1;
    samples[key] = (from, to);
  }

  for (final b in ActiveBookingService.instance.bookings) {
    if (b.status == BookingStatus.completed) {
      bump(b.from, b.to);
    }
  }
  for (final t in allCatalogTaxis()) {
    if (!t.isOpenTrip) bump(t.from, t.to);
  }

  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  const thumbs = [
    'assets/images/trip_thumb_1.png',
    'assets/images/trip_thumb_2.png',
    'assets/images/trip_thumb_3.png',
  ];

  final out = <PopularRoute>[];
  for (var i = 0; i < sorted.length && out.length < limit; i++) {
    final key = sorted[i].key;
    final pair = samples[key]!;
    final price = allCatalogTaxis()
        .where((t) => t.from == pair.$1 && t.to == pair.$2)
        .map((t) => t.priceLabel)
        .firstOrNull;
    out.add(
      PopularRoute(
        from: pair.$1,
        to: pair.$2,
        count: sorted[i].value,
        priceLabel: price ?? '—',
        imageAsset: thumbs[i % thumbs.length],
      ),
    );
  }
  return out;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
