import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeColorKey = 'theme_color';
  static const String _themeStyleKey = 'theme_style';

  Color _accentColor = Colors.deepPurple;
  String _themeStyle = 'modern'; // modern, classic, vibrant, minimal

  Color get accentColor => _accentColor;
  String get themeStyle => _themeStyle;

  ThemeService() {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved color
    final colorValue = prefs.getInt(_themeColorKey) ?? Colors.deepPurple.value;
    _accentColor = Color(colorValue);

    // Load saved style
    _themeStyle = prefs.getString(_themeStyleKey) ?? 'modern';

    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeColorKey, color.value);
    notifyListeners();
  }

  Future<void> setThemeStyle(String style) async {
    _themeStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeStyleKey, style);
    notifyListeners();
  }

  // Get icon based on theme style - USING CORRECT ICON NAMES
  IconData getPlayIcon(bool isPlaying) {
    switch (_themeStyle) {
      case 'modern':
        return isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled;
      case 'classic':
        return isPlaying ? Icons.pause : Icons.play_arrow;
      case 'vibrant':
        return isPlaying ? Icons.pause_circle : Icons.play_circle;
      case 'minimal':
        return isPlaying ? Icons.pause : Icons.play_arrow;
      default:
        return isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled;
    }
  }

  IconData getSkipNextIcon() {
    switch (_themeStyle) {
      case 'modern':
        return Icons.skip_next;
      case 'classic':
        return Icons.skip_next;
      case 'vibrant':
        return Icons.skip_next;
      case 'minimal':
        return Icons.skip_next;
      default:
        return Icons.skip_next;
    }
  }

  IconData getSkipPreviousIcon() {
    switch (_themeStyle) {
      case 'modern':
        return Icons.skip_previous;
      case 'classic':
        return Icons.skip_previous;
      case 'vibrant':
        return Icons.skip_previous;
      case 'minimal':
        return Icons.skip_previous;
      default:
        return Icons.skip_previous;
    }
  }

  IconData getShuffleIcon(bool isShuffled) {
    switch (_themeStyle) {
      case 'modern':
        return Icons.shuffle;
      case 'classic':
        return Icons.shuffle;
      case 'vibrant':
        return Icons.shuffle;
      case 'minimal':
        return Icons.shuffle;
      default:
        return Icons.shuffle;
    }
  }

  IconData getRepeatIcon(bool isRepeating) {
    switch (_themeStyle) {
      case 'modern':
        return isRepeating ? Icons.repeat_one : Icons.repeat;
      case 'classic':
        return isRepeating ? Icons.repeat_one : Icons.repeat;
      case 'vibrant':
        return isRepeating ? Icons.repeat_one : Icons.repeat;
      case 'minimal':
        return isRepeating ? Icons.repeat_one : Icons.repeat;
      default:
        return isRepeating ? Icons.repeat_one : Icons.repeat;
    }
  }

  // Get text style based on theme
  TextStyle getTitleStyle() {
    switch (_themeStyle) {
      case 'modern':
        return const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1,
        );
      case 'classic':
        return const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );
      case 'vibrant':
        return TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _accentColor,
          shadows: [
            Shadow(
              color: _accentColor.withOpacity(0.5),
              blurRadius: 10,
            ),
          ],
        );
      case 'minimal':
        return const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.normal,
          color: Colors.white70,
        );
      default:
        return const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        );
    }
  }

  TextStyle getArtistStyle() {
    switch (_themeStyle) {
      case 'modern':
        return TextStyle(
          fontSize: 18,
          color: Colors.grey.shade300,
          fontWeight: FontWeight.w500,
        );
      case 'classic':
        return TextStyle(
          fontSize: 16,
          color: Colors.grey.shade400,
        );
      case 'vibrant':
        return TextStyle(
          fontSize: 20,
          color: _accentColor.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        );
      case 'minimal':
        return TextStyle(
          fontSize: 16,
          color: Colors.grey.shade500,
        );
      default:
        return TextStyle(
          fontSize: 18,
          color: Colors.grey.shade300,
        );
    }
  }

  // Get button size based on theme
  double getPlayButtonSize() {
    switch (_themeStyle) {
      case 'modern':
        return 50;
      case 'classic':
        return 40;
      case 'vibrant':
        return 55;
      case 'minimal':
        return 36;
      default:
        return 45;
    }
  }

  double getControlButtonSize() {
    switch (_themeStyle) {
      case 'modern':
        return 30;
      case 'classic':
        return 28;
      case 'vibrant':
        return 32;
      case 'minimal':
        return 26;
      default:
        return 28;
    }
  }
}