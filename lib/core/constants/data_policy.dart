/// Versión vigente de la política de tratamiento de datos personales (RF-007).
///
/// Se envía al backend junto con el consentimiento. Valor acordado con
/// backend: `v1.0`. Se puede sobrescribir en build con
/// `--dart-define=DATA_POLICY_VERSION=...`.
const dataPolicyVersion = String.fromEnvironment(
  'DATA_POLICY_VERSION',
  defaultValue: 'v1.0',
);
