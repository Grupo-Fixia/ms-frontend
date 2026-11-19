class ClientProfileUpdate {
  const ClientProfileUpdate({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.address = '',
    this.city = '',
  });

  /// Opcionales: en blanco, el servidor las deja vacías.
  final String address;
  final String city;

  final String firstName;
  final String lastName;
  final String phone;
}
