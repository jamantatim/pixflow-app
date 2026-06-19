import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _keyIsPremium = 'is_premium';
  static const _keyActivationDate = 'premium_activation_date';
  static const _keyPlanDays = 'premium_plan_days';
  static const _keyFreeQrCount = 'free_qr_count';
  static const _keyUserEmail = 'user_email';

  static Future<SharedPreferences> _getPrefs() => SharedPreferences.getInstance();

  /// Verifica se é Premium. Se expirou, limpa automaticamente.
  static Future<bool> isPremium() async {
    final prefs = await _getPrefs();
    final dateStr = prefs.getString(_keyActivationDate);
    final days = prefs.getInt(_keyPlanDays);
    
    if (dateStr != null && days != null) {
      try {
        final activationDate = DateTime.parse(dateStr);
        final expirationDate = activationDate.add(Duration(days: days));
        final isValid = DateTime.now().isBefore(expirationDate);
        
        if (!isValid) await resetPremium();
        return isValid;
      } catch (_) {
        await resetPremium();
        return false;
      }
    }
    return false;
  }

  static Future<void> activatePremium(int days) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyActivationDate, DateTime.now().toIso8601String());
    await prefs.setInt(_keyPlanDays, days);
    await prefs.setBool(_keyIsPremium, true);
  }

  static Future<void> resetPremium() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyActivationDate);
    await prefs.remove(_keyPlanDays);
    await prefs.setBool(_keyIsPremium, false);
  }

  static Future<int> getFreeQrCount() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyFreeQrCount) ?? 0;
  }

  static Future<void> incrementFreeQrCount() async {
    final prefs = await _getPrefs();
    final count = await getFreeQrCount();
    await prefs.setInt(_keyFreeQrCount, count + 1);
  }

  static Future<void> resetFreeQrCount() async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyFreeQrCount, 0);
  }

  static Future<void> setUserEmail(String email) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyUserEmail, email);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyUserEmail);
  }
}