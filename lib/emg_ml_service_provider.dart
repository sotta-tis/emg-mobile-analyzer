import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emg_mobile_analyzer/services/emg_ml_service.dart';

final emgMlServiceProvider = Provider<EmgMlService>((ref) {
  return EmgMlService();
});
