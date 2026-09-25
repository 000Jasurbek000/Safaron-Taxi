class PastTrip {
  const PastTrip({
    required this.id,
    required this.from,
    required this.to,
    required this.dateLabel,
    required this.timeLabel,
    required this.plate,
    required this.phone,
    required this.status,
  });

  final String id;
  final String from;
  final String to;
  final String dateLabel;
  final String timeLabel;
  final String plate;
  final String phone;
  final String status; // Yakunlangan | Bekor qilingan
}

const mockPastTrips = <PastTrip>[];

List<PastTrip> get completedPastTrips =>
    mockPastTrips.where((t) => t.status != 'Bekor qilingan').toList();
