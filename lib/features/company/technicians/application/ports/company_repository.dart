import '../../domain/associated_technician.dart';
import '../../domain/company_account.dart';

/// Puerto de salida: la empresa del administrador autenticado y sus técnicos
/// asociados (GC-467, API de GC-466).
///
/// Ambos métodos lanzan `CompanyFailure` si el backend rechaza la consulta o
/// no se puede contactar.
abstract interface class CompanyRepository {
  Future<CompanyAccount> getMine();

  /// Técnicos asociados, en el orden en que se asociaron. Lista vacía si la
  /// empresa no tiene ninguno.
  Future<List<AssociatedTechnician>> listTechnicians();
}
