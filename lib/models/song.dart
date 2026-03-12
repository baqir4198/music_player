import 'dart:typed_data';
import 'dart:convert';

class Song {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? genre;
  final Duration duration;
  final String? audioPath;
  final Uint8List? coverImage;
  final String? coverUrl;
  final bool isLocal;
  final DateTime? dateAdded;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.genre,
    required this.duration,
    this.audioPath,
    this.coverImage,
    this.coverUrl,
    required this.isLocal,
    this.dateAdded,
  });

  // Helper getters
  bool get hasCoverImage => coverImage != null || coverUrl != null;

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'duration': duration.inMilliseconds,
      'audioPath': audioPath,
      'coverImage': coverImage != null ? base64Encode(coverImage!) : null,
      'coverUrl': coverUrl,
      'isLocal': isLocal ? 1 : 0,
      'dateAdded': dateAdded?.millisecondsSinceEpoch,
    };
  }

  // Create from Map
  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      title: map['title'],
      artist: map['artist'],
      album: map['album'],
      genre: map['genre'],
      duration: Duration(milliseconds: map['duration']),
      audioPath: map['audioPath'],
      coverImage: map['coverImage'] != null
          ? base64Decode(map['coverImage'])
          : null,
      coverUrl: map['coverUrl'],
      isLocal: map['isLocal'] == 1,
      dateAdded: map['dateAdded'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateAdded'])
          : null,
    );
  }

  // NEW: Convert to JSON for favorites service
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'duration': duration.inMilliseconds,
      'audioPath': audioPath,
      'coverImage': coverImage != null ? base64Encode(coverImage!) : null,
      'coverUrl': coverUrl,
      'isLocal': isLocal,
    };
  }

  // NEW: Create from JSON for favorites service
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'],
      genre: json['genre'],
      duration: Duration(milliseconds: json['duration']),
      audioPath: json['audioPath'],
      coverImage: json['coverImage'] != null
          ? base64Decode(json['coverImage'])
          : null,
      coverUrl: json['coverUrl'],
      isLocal: json['isLocal'],
      dateAdded: null, // Not needed for favorites
    );
  }
}

// Sample songs - using coverUrl for network images
List<Song> sampleSongs = [
  Song(
    id: '1',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    album: 'A Night at the Opera',
    duration: const Duration(seconds: 354),
    coverUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400',
    isLocal: false,
    dateAdded: DateTime.now(),
  ),
  Song(
    id: '2',
    title: 'Shape of You',
    artist: 'Ed Sheeran',
    album: '/',
    duration: const Duration(seconds: 233),
    coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400',
    isLocal: false,
    dateAdded: DateTime.now(),
  ),
  Song(
    id: '3',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    album: 'After Hours',
    duration: const Duration(seconds: 200),
    coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400',
    isLocal: false,
    dateAdded: DateTime.now(),
  )
];