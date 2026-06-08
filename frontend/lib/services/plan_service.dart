import 'dart:convert';
import '../core/api_service.dart';
import '../data/database_service.dart';
import '../models/training_data.dart';

class PlanService {
  PlanService._();

  /// Scarica il piano dal backend, lo salva su Hive e lo restituisce parsato.
  /// Lancia [Exception('no_plan')] se il server risponde senza scheda.
  /// Propaga [ApiException] per errori HTTP.
  static Future<List<TrainingDay>> syncPlan(int userId) async {
    final response = await ApiService.getPlans(userId);
    final rawPlan = response['plan'];

    if (rawPlan == null) throw Exception('no_plan');

    final Map<String, dynamic> planMap;
    if (rawPlan is Map<String, dynamic>) {
      planMap = rawPlan;
    } else if (rawPlan is String) {
      planMap = jsonDecode(rawPlan) as Map<String, dynamic>;
    } else {
      throw Exception('unexpected_plan_format');
    }

    await DatabaseService.saveRawPlan(planMap);
    return DatabaseService.parseTrainingDaysFromJson(planMap);
  }
}
