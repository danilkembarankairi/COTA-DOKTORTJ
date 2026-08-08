import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/threshold.dart'; // ✅ IMPORT INI WAJIB!
import '../models/schedule.dart'; // ✅ Untuk ScheduleModel
import '../config/api_config.dart';

class ThresholdService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> getThresholdAndSchedule(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/threshold/$userId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'threshold': ThresholdModel.fromJson(data['data']['threshold']),
        'schedules': (data['data']['schedules'] as List)
            .map((s) => ScheduleModel.fromJson(s))
            .toList(),
      };
    } else {
      throw Exception('Failed to load threshold');
    }
  }

  Future<bool> updateThreshold(String userId, ThresholdModel threshold) async {
    final response = await http.post(
      Uri.parse('$baseUrl/threshold/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(threshold.toJson()),
    );

    return response.statusCode == 200;
  }

  Future<bool> updateSchedule(
      String userId, List<ScheduleModel> schedules) async {
    final response = await http.post(
      Uri.parse('$baseUrl/schedule/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'schedules': schedules.map((s) => s.toJson()).toList(),
      }),
    );

    return response.statusCode == 200;
  }
}
