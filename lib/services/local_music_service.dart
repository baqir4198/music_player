import 'dart:typed_data';
import 'package:music_player/models/song.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

class LocalMusicService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// FAST scanning — no artwork loading here
  Future<List<Song>> scanLocalSongs() async {
    List<Song> localSongs = [];

    try {
      // Query songs only (no heavy artwork here)
      List<SongModel> songs = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      for (var song in songs) {
        localSongs.add(
          Song(
            id: song.id.toString(),
            title: song.title,
            artist: song.artist ?? 'Unknown Artist',
            album: song.album ?? 'Unknown Album',
            genre: 'Unknown',
            duration: Duration(milliseconds: song.duration ?? 0),
            audioPath: song.data,
            coverImage: null, // 🔥 IMPORTANT: Do NOT load artwork here
            isLocal: true,
            dateAdded: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      print('Error scanning local songs: $e');
    }

    return localSongs;
  }

  /// Load album art ONLY when needed (like in NowPlaying screen)
  Future<Uint8List?> getAlbumArt(int songId) async {
    try {
      return await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 300,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<AlbumModel>> getAlbums() async {
    try {
      return await _audioQuery.queryAlbums();
    } catch (e) {
      print('Error getting albums: $e');
      return [];
    }
  }

  Future<List<ArtistModel>> getArtists() async {
    try {
      return await _audioQuery.queryArtists();
    } catch (e) {
      print('Error getting artists: $e');
      return [];
    }
  }

  Future<List<Song>> getSongsByAlbum(int albumId) async {
    List<Song> songs = [];

    try {
      List<SongModel> albumSongs = await _audioQuery.queryAudiosFrom(
        AudiosFromType.ALBUM_ID,
        albumId,
      );

      for (var song in albumSongs) {
        songs.add(
          Song(
            id: song.id.toString(),
            title: song.title,
            artist: song.artist ?? 'Unknown Artist',
            album: song.album ?? 'Unknown Album',
            duration: Duration(milliseconds: song.duration ?? 0),
            audioPath: song.data,
            coverImage: null, // still lazy load
            isLocal: true,
            dateAdded: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      print('Error getting album songs: $e');
    }

    return songs;
  }
}
