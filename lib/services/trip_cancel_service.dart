import '../l10n/phrase.dart';
import 'active_booking_service.dart';
import 'driver_trip_service.dart';
import 'profile_service.dart';
import 'safaron_api.dart';
import 'trip_completion_service.dart';

/// Safarni bir tomondan bekor qilish — ikkala tomonda ham yopiladi, arxivlanadi, xabar beriladi.
class TripCancelService {
  TripCancelService._();
  static final TripCancelService instance = TripCancelService._();

  int? _remoteId(String bookingId) {
    if (bookingId.startsWith('req_')) {
      return int.tryParse(bookingId.substring(4));
    }
    return null;
  }

  String _resolveBookingId(String bookingId, PassengerOrder? order) {
    if (order?.broadcastGroupId != null && order!.broadcastGroupId!.isNotEmpty) {
      return order.broadcastGroupId!;
    }
    return bookingId;
  }

  Future<void> cancelByPassenger({
    required String bookingId,
    required String reason,
    BookingKind? kind,
  }) async {
    PassengerOrder? order = DriverTripService.instance.orderById(bookingId);
    if (order == null) {
      for (final o in DriverTripService.instance.orders) {
        if (DriverTripService.instance.orderBelongsToBooking(o, bookingId)) {
          order = o;
          break;
        }
      }
    }
    final groupId = _resolveBookingId(bookingId, order);

    final remote = _remoteId(groupId);
    if (remote != null) {
      try {
        await RequestApi.instance.cancel(remote, reason);
      } catch (_) {}
    }

    await DriverTripService.instance.cancelAllForBooking(
      groupId,
      reason: reason,
      cancelledBy: 'passenger',
    );

    await ActiveBookingService.instance.markCancelled(
      bookingId: groupId,
      reason: reason,
      cancelledBy: 'passenger',
      kind: kind,
    );

    await _archiveCancellation(
      bookingId: groupId,
      reason: reason,
      cancelledBy: 'passenger',
      order: order,
    );

    DriverTripService.instance.setDriverNotice(
      tr('Yo‘lovchi safarni bekor qildi: {reason}').replaceAll('{reason}', reason),
    );
  }

  Future<void> cancelByDriver({
    required String orderId,
    required String reason,
    bool fullTrip = true,
  }) async {
    final order = DriverTripService.instance.orderById(orderId);
    if (order == null) return;

    final groupId = _resolveBookingId(orderId, order);
    final isLive = order.status == PassengerOrderStatus.accepted ||
        order.status == PassengerOrderStatus.onWay ||
        order.status == PassengerOrderStatus.pickedUp ||
        order.status == PassengerOrderStatus.counterOffered;

    if (!fullTrip || !isLive) {
      await DriverTripService.instance.rejectOpenOrder(orderId, reason: reason);
      return;
    }

    final remote = _remoteId(groupId);
    if (remote != null) {
      try {
        await RequestApi.instance.cancel(remote, reason);
      } catch (_) {}
    }

    await DriverTripService.instance.cancelAllForBooking(
      groupId,
      reason: reason,
      cancelledBy: 'driver',
    );

    await ActiveBookingService.instance.markCancelled(
      bookingId: groupId,
      reason: reason,
      cancelledBy: 'driver',
    );

    await _archiveCancellation(
      bookingId: groupId,
      reason: reason,
      cancelledBy: 'driver',
      order: order,
    );

    DriverTripService.instance.setPassengerNotice(
      tr('Haydovchi safarni bekor qildi: {reason}').replaceAll('{reason}', reason),
    );
  }

  Future<void> _archiveCancellation({
    required String bookingId,
    required String reason,
    required String cancelledBy,
    PassengerOrder? order,
  }) async {
    final booking = ActiveBookingService.instance.byId(bookingId);
    final from = order?.from ?? booking?.from ?? '';
    final to = order?.to ?? booking?.to ?? '';
    final price = order?.displayPrice ?? booking?.offeredPrice ?? booking?.taxi.price ?? 0;
    await TripCompletionService.instance.recordCancellation(
      bookingId: bookingId,
      from: from,
      to: to,
      price: price,
      cancelledBy: cancelledBy,
      reason: reason,
      passengerName: order?.passengerName ??
          (ProfileService.instance.fullName.isEmpty ? tr('Yo‘lovchi') : ProfileService.instance.fullName),
      driverName: booking?.taxi.driverName ?? ProfileService.instance.fullName,
    );
  }
}
