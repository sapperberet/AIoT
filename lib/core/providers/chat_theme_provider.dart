import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chat theme configuration for customizing AI chat appearance
class ChatThemeConfig {
  final String name;
  final Color userBubbleColor;
  final Color aiBubbleColor;
  final Color userTextColor;
  final Color aiTextColor;
  final Color backgroundColor;
  final String fontFamily;
  final double fontSize;
  final double bubbleRadius;
  final bool showTimestamps;
  final bool showAvatars;

  const ChatThemeConfig({
    required this.name,
    required this.userBubbleColor,
    required this.aiBubbleColor,
    required this.userTextColor,
    required this.aiTextColor,
    required this.backgroundColor,
    this.fontFamily = 'Default',
    this.fontSize = 15.0,
    this.bubbleRadius = 20.0,
    this.showTimestamps = true,
    this.showAvatars = true,
  });

  ChatThemeConfig copyWith({
    String? name,
    Color? userBubbleColor,
    Color? aiBubbleColor,
    Color? userTextColor,
    Color? aiTextColor,
    Color? backgroundColor,
    String? fontFamily,
    double? fontSize,
    double? bubbleRadius,
    bool? showTimestamps,
    bool? showAvatars,
  }) {
    return ChatThemeConfig(
      name: name ?? this.name,
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      aiBubbleColor: aiBubbleColor ?? this.aiBubbleColor,
      userTextColor: userTextColor ?? this.userTextColor,
      aiTextColor: aiTextColor ?? this.aiTextColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      showAvatars: showAvatars ?? this.showAvatars,
    );
  }
}

/// Provider for managing chat theme settings
class ChatThemeProvider with ChangeNotifier {
  static const String _themeKey = 'chat_theme';
  static const String _fontSizeKey = 'chat_font_size';
  static const String _fontFamilyKey = 'chat_font_family';
  static const String _bubbleRadiusKey = 'chat_bubble_radius';
  static const String _showTimestampsKey = 'chat_show_timestamps';
  static const String _showAvatarsKey = 'chat_show_avatars';
  static const String _userBubbleColorKey = 'chat_user_bubble_color';
  static const String _aiBubbleColorKey = 'chat_ai_bubble_color';

  String _currentThemeName = 'default';
  double _fontSize = 15.0;
  String _fontFamily = 'Default';
  double _bubbleRadius = 20.0;
  bool _showTimestamps = true;
  bool _showAvatars = true;
  Color? _customUserBubbleColor;
  Color? _customAiBubbleColor;

  // Predefined chat themes
  static final Map<String, ChatThemeConfig> themes = {
    'default': const ChatThemeConfig(
      name: 'Default',
      userBubbleColor: Color(0xFF6C63FF),
      aiBubbleColor: Color(0xFF2A2A3E),
      userTextColor: Colors.white,
      aiTextColor: Colors.white,
      backgroundColor: Color(0xFF0F0F1E),
    ),
    'light': const ChatThemeConfig(
      name: 'Light',
      userBubbleColor: Color(0xFF6C63FF),
      aiBubbleColor: Color(0xFFE8E8E8),
      userTextColor: Colors.white,
      aiTextColor: Color(0xFF1A1A2E),
      backgroundColor: Color(0xFFF5F7FA),
    ),
    'ocean': const ChatThemeConfig(
      name: 'Ocean',
      userBubbleColor: Color(0xFF0077B6),
      aiBubbleColor: Color(0xFF023E8A),
      userTextColor: Colors.white,
      aiTextColor: Colors.white,
      backgroundColor: Color(0xFF03045E),
    ),
    'forest': const ChatThemeConfig(
      name: 'Forest',
      userBubbleColor: Color(0xFF2D6A4F),
      aiBubbleColor: Color(0xFF1B4332),
      userTextColor: Colors.white,
      aiTextColor: Colors.white,
      backgroundColor: Color(0xFF081C15),
    ),
    'sunset': const ChatThemeConfig(
      name: 'Sunset',
      userBubbleColor: Color(0xFFFF6B6B),
      aiBubbleColor: Color(0xFFFFE66D),
      userTextColor: Colors.white,
      aiTextColor: Color(0xFF2A2A2A),
      backgroundColor: Color(0xFF4A4A4A),
    ),
    'midnight': const ChatThemeConfig(
      name: 'Midnight',
      userBubbleColor: Color(0xFF7C3AED),
      aiBubbleColor: Color(0xFF1F2937),
      userTextColor: Colors.white,
      aiTextColor: Colors.white,
      backgroundColor: Color(0xFF111827),
    ),
    'candy': const ChatThemeConfig(
      name: 'Candy',
      userBubbleColor: Color(0xFFFF69B4),
      aiBubbleColor: Color(0xFFB4E4FF),
      userTextColor: Colors.white,
      aiTextColor: Color(0xFF2A2A2A),
      backgroundColor: Color(0xFFFFF0F5),
    ),
    'neon': const ChatThemeConfig(
      name: 'Neon',
      userBubbleColor: Color(0xFF00FF87),
      aiBubbleColor: Color(0xFF00D4FF),
      userTextColor: Color(0xFF1A1A2E),
      aiTextColor: Color(0xFF1A1A2E),
      backgroundColor: Color(0xFF0D0D0D),
    ),
  };

  // Available font families
  static const List<String> fontFamilies = [
    'Default',
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Poppins',
    'Source Code Pro',
    'Comic Sans MS',
  ];

  ChatThemeProvider() {
    _loadSettings();
  }

  // Getters
  String get currentThemeName => _currentThemeName;
  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  double get bubbleRadius => _bubbleRadius;
  bool get showTimestamps => _showTimestamps;
  bool get showAvatars => _showAvatars;
  Color? get customUserBubbleColor => _customUserBubbleColor;
  Color? get customAiBubbleColor => _customAiBubbleColor;

  ChatThemeConfig get currentTheme {
    final baseTheme = themes[_currentThemeName] ?? themes['default']!;
    return baseTheme.copyWith(
      userBubbleColor: _customUserBubbleColor ?? baseTheme.userBubbleColor,
      aiBubbleColor: _customAiBubbleColor ?? baseTheme.aiBubbleColor,
      fontFamily: _fontFamily,
      fontSize: _fontSize,
      bubbleRadius: _bubbleRadius,
      showTimestamps: _showTimestamps,
      showAvatars: _showAvatars,
    );
  }

  // Gradient for user bubble
  LinearGradient get userBubbleGradient {
    final color = _customUserBubbleColor ?? currentTheme.userBubbleColor;
    return LinearGradient(
      colors: [color, color.withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Gradient for AI bubble
  LinearGradient get aiBubbleGradient {
    final color = _customAiBubbleColor ?? currentTheme.aiBubbleColor;
    return LinearGradient(
      colors: [color, color.withOpacity(0.9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentThemeName = prefs.getString(_themeKey) ?? 'default';
      _fontSize = prefs.getDouble(_fontSizeKey) ?? 15.0;
      _fontFamily = prefs.getString(_fontFamilyKey) ?? 'Default';
      _bubbleRadius = prefs.getDouble(_bubbleRadiusKey) ?? 20.0;
      _showTimestamps = prefs.getBool(_showTimestampsKey) ?? true;
      _showAvatars = prefs.getBool(_showAvatarsKey) ?? true;

      final userColorInt = prefs.getInt(_userBubbleColorKey);
      if (userColorInt != null) {
        _customUserBubbleColor = Color(userColorInt);
      }

      final aiColorInt = prefs.getInt(_aiBubbleColorKey);
      if (aiColorInt != null) {
        _customAiBubbleColor = Color(aiColorInt);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat theme settings: $e');
    }
  }

  Future<void> setTheme(String themeName) async {
    if (!themes.containsKey(themeName)) return;
    _currentThemeName = themeName;
    _customUserBubbleColor = null; // Reset custom colors when changing theme
    _customAiBubbleColor = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
    await prefs.remove(_userBubbleColorKey);
    await prefs.remove(_aiBubbleColorKey);

    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(10.0, 24.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, family);
    notifyListeners();
  }

  Future<void> setBubbleRadius(double radius) async {
    _bubbleRadius = radius.clamp(4.0, 32.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_bubbleRadiusKey, _bubbleRadius);
    notifyListeners();
  }

  Future<void> setShowTimestamps(bool show) async {
    _showTimestamps = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTimestampsKey, show);
    notifyListeners();
  }

  Future<void> setShowAvatars(bool show) async {
    _showAvatars = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAvatarsKey, show);
    notifyListeners();
  }

  Future<void> setUserBubbleColor(Color color) async {
    _customUserBubbleColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userBubbleColorKey, color.value);
    notifyListeners();
  }

  Future<void> setAiBubbleColor(Color color) async {
    _customAiBubbleColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiBubbleColorKey, color.value);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _currentThemeName = 'default';
    _fontSize = 15.0;
    _fontFamily = 'Default';
    _bubbleRadius = 20.0;
    _showTimestamps = true;
    _showAvatars = true;
    _customUserBubbleColor = null;
    _customAiBubbleColor = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    await prefs.remove(_fontSizeKey);
    await prefs.remove(_fontFamilyKey);
    await prefs.remove(_bubbleRadiusKey);
    await prefs.remove(_showTimestampsKey);
    await prefs.remove(_showAvatarsKey);
    await prefs.remove(_userBubbleColorKey);
    await prefs.remove(_aiBubbleColorKey);

    notifyListeners();
  }
}
