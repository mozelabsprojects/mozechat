import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

enum AppThemeMode { matrix, cyberpunk, retro, hacker, blue }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentMode = AppThemeMode.matrix;
  Color? _senderBubbleColor;
  Color? _receiverBubbleColor;
  bool _animationsEnabled = true;

  AppThemeMode get currentMode => _currentMode;
  Color? get senderBubbleColor => _senderBubbleColor;
  Color? get receiverBubbleColor => _receiverBubbleColor;
  bool get animationsEnabled => _animationsEnabled;

  Future<void> initializeState() async {
    final index = await PreferencesService.getThemeIndex();
    if (index != null && index >= 0 && index < AppThemeMode.values.length) {
      _currentMode = AppThemeMode.values[index];
    }

    final senderColor = await PreferencesService.getSenderBubbleColor();
    if (senderColor != null) _senderBubbleColor = Color(senderColor);

    final receiverColor = await PreferencesService.getReceiverBubbleColor();
    if (receiverColor != null) _receiverBubbleColor = Color(receiverColor);

    _animationsEnabled = await PreferencesService.getAnimationsEnabled();

    notifyListeners();
  }

  void setTheme(AppThemeMode mode) {
    _currentMode = mode;
    PreferencesService.saveThemeIndex(mode.index);
    notifyListeners();
  }

  void setSenderBubbleColor(Color color) {
    _senderBubbleColor = color;
    PreferencesService.saveSenderBubbleColor(color.toARGB32());
    notifyListeners();
  }

  void setReceiverBubbleColor(Color color) {
    _receiverBubbleColor = color;
    PreferencesService.saveReceiverBubbleColor(color.toARGB32());
    notifyListeners();
  }

  void setAnimationsEnabled(bool enabled) {
    _animationsEnabled = enabled;
    PreferencesService.saveAnimationsEnabled(enabled);
    notifyListeners();
  }

  Color get accentColor {
    switch (_currentMode) {
      case AppThemeMode.matrix:
        return const Color(0xFF159D87); // Custom Green
      case AppThemeMode.cyberpunk:
        return const Color(0xFF4A3B5A); // Cyberpunk Purple
      case AppThemeMode.retro:
        return const Color(0xFF000000); // Retro Black text (Light Mode)
      case AppThemeMode.hacker:
        return const Color(0xFF8B263E); // Hacker Red
      case AppThemeMode.blue:
        return const Color(0xFF6482AD); // New Blue
    }
  }

  ThemeData get themeData {
    final isLight = _currentMode == AppThemeMode.retro;
    final bgColor = isLight ? Colors.white : Colors.black;
    final fgColor = accentColor;

    return ThemeData(
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      primaryColor: fgColor,
      cardColor: isLight ? Colors.grey.shade200 : Colors.black87,
      colorScheme: isLight
          ? ColorScheme.light(
              primary: fgColor,
              secondary: fgColor,
              surface: Colors.white,
            )
          : ColorScheme.dark(
              primary: fgColor,
              secondary: fgColor,
              surface: Colors.black,
            ),
      fontFamily: 'Courier',
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: fgColor, width: 1)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: fgColor, fontFamily: 'Courier'),
        bodyMedium: TextStyle(color: fgColor, fontFamily: 'Courier'),
        titleLarge: TextStyle(
          color: fgColor,
          fontFamily: 'Courier',
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: fgColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: fgColor),
        ),
        labelStyle: TextStyle(color: fgColor),
        hintStyle: TextStyle(color: fgColor.withValues(alpha: 0.5)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: fgColor,
        selectionColor: fgColor.withValues(alpha: 0.3),
        selectionHandleColor: fgColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: bgColor,
          backgroundColor: fgColor,
          textStyle: const TextStyle(
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
          ),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fgColor,
          textStyle: const TextStyle(
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
