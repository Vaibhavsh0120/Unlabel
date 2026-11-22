import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';

void main() {
  test(
    'machine readings honor capabilities and never call a retired vendor',
    () async {
      final paths = <String>[];
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'api_major': 1,
              'contract_schema': '1',
              'report_version': 'label-report-v1',
              'capabilities': {'ai_machine_observations': false},
            }),
            200,
          );
        }),
      );
      expect(
        (await repository.machineProduct('012345678905')).readings,
        isEmpty,
      );
      expect(paths, ['/v1/meta']);
      repository.close();
    },
  );
}
