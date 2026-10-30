import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../utils/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  String _languageCode = 'tr';
  late AppStrings _strings;

  LocaleProvider() {
    _strings = AppStrings(_languageCode);
    _loadLanguage();
  }

  String get languageCode => _languageCode;
  AppStrings get strings => _strings;
  bool get isTurkish => _languageCode == 'tr';

  Future<void> _loadLanguage() async {
    _languageCode = await PreferencesService.getLanguage();
    _strings = AppStrings(_languageCode);
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    if (_languageCode == langCode) return;
    _languageCode = langCode;
    _strings = AppStrings(langCode);
    await PreferencesService.saveLanguage(langCode);
    notifyListeners();
  }
}

