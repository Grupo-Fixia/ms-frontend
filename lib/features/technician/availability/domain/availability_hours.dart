class AvailabilityHours {
  const AvailabilityHours(
      {required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;

  bool get isValid =>
      startMinutes >= 0 &&
      startMinutes < 24 * 60 &&
      endMinutes > startMinutes &&
      endMinutes < 24 * 60;

  @override
  bool operator ==(Object other) =>
      other is AvailabilityHours &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes);
}
