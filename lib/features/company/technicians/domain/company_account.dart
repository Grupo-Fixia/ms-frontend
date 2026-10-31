/// Empresa prestadora que administra la cuenta autenticada (GC-466,
/// GC-467). La identidad sale siempre del token: el frontend nunca envía un
/// identificador de empresa.
class CompanyAccount {
  const CompanyAccount({
    required this.id,
    required this.name,
    this.nit,
  });

  final String id;

  /// Nombre comercial.
  final String name;

  /// `null` si el backend no lo entrega.
  final String? nit;
}
