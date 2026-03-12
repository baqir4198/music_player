import 'package:flutter/material.dart';
import 'package:music_player/models/song.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesService extends ChangeNotifier {
  static const String _favoritesKey = 'favorite_songs';
  List<Song> _favoriteSongs = [];

  List<Song> get favoriteSongs => List.unmodifiable(_favoriteSongs);

  FavoritesService() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? favoritesJson = prefs.getString(_favoritesKey);

      if (favoritesJson != null) {
        final List<dynamic> jsonList = json.decode(favoritesJson);
        _favoriteSongs = jsonList.map((json) => Song.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _favoriteSongs.map((song) => song.toJson()).toList();
      await prefs.setString(_favoritesKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  bool isFavorite(String songId) {
    return _favoriteSongs.any((song) => song.id == songId);
  }

  Future<void> toggleFavorite(Song song) async {
    if (isFavorite(song.id)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> removeFavorite(String songId) async {
    _favoriteSongs.removeWhere((s) => s.id == songId);
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> clearFavorites() async {
    _favoriteSongs.clear();
    await _saveFavorites();
    notifyListeners();
  }
}