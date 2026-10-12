import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preference for the dyslexia-friendly OpenDyslexic typeface.
class SettingsController extends ChangeNotifier {
  static const _dyslexiaFontKey = 'use_dyslexia_font';

  bool _useDyslexiaFont = false;
  bool _loaded = false;

  bool get useDyslexiaFont => _useDyslexiaFont;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _useDyslexiaFont = prefs.getBool(_dyslexiaFontKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setUseDyslexiaFont(bool value) async {
    if (_useDyslexiaFont == value) return;
    _useDyslexiaFont = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dyslexiaFontKey, value);
  }
}
