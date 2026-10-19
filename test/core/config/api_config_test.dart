import 'package:flutter_test/flutter_test.dart';
import 'package:ms_frontend/core/config/api_config.dart';

void main() {
  test('sin configuración, ms-services usa el mismo origen que ms-users', () {
    expect(ApiConfig.usersBaseUrl, 'http://localhost');
    expect(ApiConfig.servicesBaseUrl, ApiConfig.usersBaseUrl);
  });
}
