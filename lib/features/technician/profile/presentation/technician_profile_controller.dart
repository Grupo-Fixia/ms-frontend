import 'package:flutter/foundation.dart';

import '../../../../core/constants/service_category.dart';
import '../application/get_technician_profile.dart';
import '../application/update_technician_profile.dart';
import '../domain/professional_profile_update.dart';
import '../domain/technician_profile.dart';
import '../domain/technician_profile_exceptions.dart';
import '../domain/technician_profile_rules.dart';

enum TechnicianProfileStatus { loading, loadError, ready }

/// Estado de la pantalla del perfil profesional (GC-263).
class TechnicianProfileController extends ChangeNotifier {
  TechnicianProfileController({
    required GetTechnicianProfile getProfile,
    required UpdateTechnicianProfile updateProfile,
  })  : _getProfile = getProfile,
        _updateProfile = updateProfile;

  static const unexpectedErrorMessage =
      'No pudimos cargar tu perfil. Inténtalo de nuevo.';

  final GetTechnicianProfile _getProfile;
  final UpdateTechnicianProfile _updateProfile;

  TechnicianProfileStatus _status = TechnicianProfileStatus.loading;
  TechnicianProfile? _profile;
  String? _loadErrorMessage;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _justSaved = false;
  bool _isSessionExpired = false;
  String? _saveErrorMessage;
  Map<String, String> _fieldErrors = const {};

  TechnicianProfileStatus get status => _status;
  TechnicianProfile? get profile => _profile;
  String? get loadErrorMessage => _loadErrorMessage;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;

  /// Se acaba de guardar: la pantalla lo confirma.
  bool get justSaved => _justSaved;

  /// La sesión venció: hay que volver a iniciar sesión.
  bool get isSessionExpired => _isSessionExpired;
  String? get saveErrorMessage => _saveErrorMessage;

  /// El formulario se muestra mientras el perfil esté incompleto (paso 2) o
  /// cuando el técnico decide editarlo.
  bool get showForm {
    final profile = _profile;
    return profile != null && (!profile.isComplete || _isEditing);
  }

  String? fieldError(String field) => _fieldErrors[field];

  void clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    _fieldErrors = Map.of(_fieldErrors)..remove(field);
    notifyListeners();
  }

  void dismissSaveError() {
    if (_saveErrorMessage == null) return;
    _saveErrorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    // Al abrir la pantalla ya está cargando: solo se avisa al reintentar.
    if (_status != TechnicianProfileStatus.loading) {
      _status = TechnicianProfileStatus.loading;
      _loadErrorMessage = null;
      notifyListeners();
    }
    try {
      _profile = await _getProfile();
      _status = TechnicianProfileStatus.ready;
    } on TechnicianProfileFailure catch (failure) {
      _status = TechnicianProfileStatus.loadError;
      _loadErrorMessage = failure.message;
      _isSessionExpired = failure.isSessionExpired;
    } catch (_) {
      _status = TechnicianProfileStatus.loadError;
      _loadErrorMessage = unexpectedErrorMessage;
    }
    notifyListeners();
  }

  void startEditing() {
    if (_profile == null || _isEditing) return;
    _isEditing = true;
    _justSaved = false;
    _resetSaveState();
    notifyListeners();
  }

  void cancelEditing() {
    if (!_isEditing) return;
    _isEditing = false;
    _resetSaveState();
    notifyListeners();
  }

  /// Guarda el perfil. Devuelve `true` si quedó guardado.
  Future<bool> save({
    required String professionalDescription,
    required String yearsOfExperience,
    required Set<ServiceCategory> categories,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;
    _resetSaveState();
    notifyListeners();
    try {
      _profile = await _updateProfile(
        ProfessionalProfileUpdate(
          professionalDescription: professionalDescription.trim(),
          yearsOfExperience: TechnicianProfileRules.parseYears(
            yearsOfExperience,
          ),
          categories: categories,
        ),
      );
      _isEditing = false;
      _justSaved = true;
      return true;
    } on TechnicianProfileFailure catch (failure) {
      _saveErrorMessage = failure.message;
      _fieldErrors = failure.fieldErrors;
      _isSessionExpired = failure.isSessionExpired;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _resetSaveState() {
    _saveErrorMessage = null;
    _fieldErrors = const {};
  }
}
