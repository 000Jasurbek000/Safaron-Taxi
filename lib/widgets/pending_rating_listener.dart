import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../services/trip_completion_service.dart';
import 'rating_dialog.dart';

/// Safar yakunlanganda qarama-qarshi tomondan baholashni darhol so‘raydi.
class PendingRatingListener extends StatefulWidget {
  const PendingRatingListener({super.key, required this.child});

  final Widget child;

  @override
  State<PendingRatingListener> createState() => _PendingRatingListenerState();
}

class _PendingRatingListenerState extends State<PendingRatingListener> {
  final _completion = TripCompletionService.instance;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _completion.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  void _onChange() => _maybePrompt();

  Future<void> _maybePrompt() async {
    if (!mounted || _showing) return;
    final isDriver = ProfileService.instance.isDriverRole;
    final bookingId = isDriver
        ? _completion.pendingDriverRatingBookingId
        : _completion.pendingPassengerRatingBookingId;
    if (bookingId == null) return;

    final record = _completion.byBookingId(bookingId);
    if (record == null) return;

    _showing = true;
    final title = isDriver
        ? '${record.passengerName} ni baholang'
        : '${record.driverName} ni baholang';

    final stars = await showTripRatingDialog(context, title: title);
    if (!mounted) {
      _showing = false;
      return;
    }

    if (stars != null) {
      if (isDriver) {
        await _completion.markDriverRatedPassenger(bookingId);
      } else {
        await _completion.markPassengerRatedDriver(bookingId);
      }
    } else {
      _completion.clearPendingForRole(isDriver: isDriver);
    }

    _showing = false;
  }

  @override
  void dispose() {
    _completion.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
