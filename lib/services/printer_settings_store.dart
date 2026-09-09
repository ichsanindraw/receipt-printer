import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_settings.dart';

/// Persists the chosen printer between launches.
///
/// Both calls swallow platform-channel failures: losing the saved printer is a
/// minor inconvenience, but an unhandled error on startup is not.
class PrinterSettingsStore {
  const PrinterSettingsStore();

  static const String _key = 'printer_settings';

  Future<PrinterSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PrinterSettings.decode(prefs.getString(_key));
    } catch (error) {
      debugPrint('Could not read printer settings: $error');
      return const PrinterSettings();
    }
  }

  Future<void> save(PrinterSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, settings.encode());
    } catch (error) {
      debugPrint('Could not save printer settings: $error');
    }
  }
}
