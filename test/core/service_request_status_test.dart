import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/constants/service_request_status.dart';

void main() {
  test(
      'reconoce todos los estados de ms-services, incluida la ejecución y el cierre',
      () {
    const api = [
      'PUBLISHED',
      'PROVIDER_SELECTED',
      'CONTRACTED',
      'IN_PROGRESS',
      'TECHNICIAN_FINISHED',
      'CLOSED',
      'CANCELLED',
      'EXPIRED',
    ];
    for (final value in api) {
      expect(ServiceRequestStatus.fromApi(value)?.apiValue, value);
    }
    expect(ServiceRequestStatus.fromApi('OTRO'), isNull);
  });

  test('solo cerrada, cancelada y vencida son finales', () {
    expect(
      ServiceRequestStatus.values.where((s) => s.isTerminal),
      [
        ServiceRequestStatus.closed,
        ServiceRequestStatus.cancelled,
        ServiceRequestStatus.expired,
      ],
    );
  });
}
