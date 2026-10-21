import 'availability_day.dart';
import 'availability_hours.dart';

class TechnicianAvailability {
  TechnicianAvailability(
      {required Map<AvailabilityDay, AvailabilityHours> days})
      : days = Map.unmodifiable(days);

  final Map<AvailabilityDay, AvailabilityHours> days;

  TechnicianAvailability copyWith(
          {Map<AvailabilityDay, AvailabilityHours>? days}) =>
      TechnicianAvailability(days: days ?? this.days);
}
