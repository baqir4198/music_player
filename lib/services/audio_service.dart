import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';

// Extend BaseAudioHandler for background playback support
class AudioService extends BaseAudioHandler with ChangeNotifier {
  final audioplayers.AudioPlayer _audioPlayer = audioplayers.AudioPlayer();

  List<Song> _playlist = [];
  Song? _currentSong;
  bool _isPlaying = false;
  bool _isShuffled = false;
  bool _isRepeating = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  List<Song> _shuffledPlaylist = [];

  // Getters
  List<Song> get playlist => _playlist;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isShuffled => _isShuffled;
  bool get isRepeating => _isRepeating;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get volume => _volume;

  // Constructor
  AudioService() {
    _initAudioPlayer();
    _setupAudioSession();
  }

  Future<void> _setupAudioSession() async {
    // Configure audio session for background playback
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  }

  void _initAudioPlayer() {
    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
      notifyListeners();
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      // Update media item with duration
      if (_currentSong != null) {
        mediaItem.add(MediaItem(
          id: _currentSong!.id,
          title: _currentSong!.title,
          artist: _currentSong!.artist,
          album: _currentSong!.album,
          duration: duration,
          artUri: _currentSong!.coverUrl != null
              ? Uri.parse(_currentSong!.coverUrl!)
              : null,
        ));
      }
      notifyListeners();
    });

    // Listen to player completion - FIXED for background playback
    _audioPlayer.onPlayerComplete.listen((event) {
      print("=== SONG COMPLETED ===");
      _onSongComplete();
    });

    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state == audioplayers.PlayerState.playing;

      // Update playback state for audio_service
      playbackState.add(playbackState.value.copyWith(
        playing: _isPlaying,
        processingState: _isPlaying
            ? AudioProcessingState.ready
            : AudioProcessingState.idle,
      ));

      // Only notify if state actually changed
      if (wasPlaying != _isPlaying) {
        notifyListeners();
      }
    });
  }

  void _onSongComplete() {
    print("=== PROCESSING SONG COMPLETE ===");
    print("Is repeating: $_isRepeating");

    if (_isRepeating) {
      // Repeat current song
      print("Repeating current song");
      if (_currentSong != null) {
        playSong(_currentSong!);
      }
    } else {
      // Play next song
      print("Playing next song");
      playNext();
    }
  }

  Future<void> setPlaylist(List<Song> songs) async {
    _playlist = songs;
    _updateShuffledPlaylist();
    notifyListeners();
  }

  Future<void> addToPlaylist(List<Song> songs) async {
    _playlist.addAll(songs);
    _updateShuffledPlaylist();
    notifyListeners();
  }

  void _updateShuffledPlaylist() {
    _shuffledPlaylist = List.from(_playlist)..shuffle();
  }

  @override
  Future<void> play() async {
    await resumePlayback();
  }

  @override
  Future<void> pause() async {
    await pausePlayback();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    await seekTo(position);
  }

  @override
  Future<void> skipToNext() async {
    print("=== SKIP TO NEXT ===");
    await playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    print("=== SKIP TO PREVIOUS ===");
    await playPrevious();
  }

  Future<void> playSong(Song song) async {
    try {
      print("=== PLAYING SONG: ${song.title} ===");

      // Stop current playback
      await _audioPlayer.stop();

      // Update current song
      _currentSong = song;

      // Update media item for notification
      mediaItem.add(MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        artUri: song.coverUrl != null ? Uri.parse(song.coverUrl!) : null,
      ));

      // Play the song
      if (song.isLocal && song.audioPath != null) {
        await _audioPlayer.play(audioplayers.DeviceFileSource(song.audioPath!));
      } else {
        String url = song.audioPath ??
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
        await _audioPlayer.play(audioplayers.UrlSource(url));
      }

      // Update playback state
      _isPlaying = true;
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
        updatePosition: Duration.zero,
      ));

      notifyListeners();

      // Get initial duration
      final duration = await _audioPlayer.getDuration();
      if (duration != null) {
        _totalDuration = duration;
      }

    } catch (e) {
      print('Error playing song: $e');
    }
  }

  Future<void> pausePlayback() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.ready,
    ));
    notifyListeners();
  }

  Future<void> resumePlayback() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.ready,
    ));
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pausePlayback();
    } else {
      await resumePlayback();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    _currentPosition = position;
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _audioPlayer.setVolume(volume);
    notifyListeners();
  }

  Future<void> playNext() async {
    print("=== PLAY NEXT CALLED ===");

    if (_playlist.isEmpty) {
      print("Playlist is empty");
      return;
    }

    if (_currentSong == null) {
      print("No current song, playing first");
      if (_playlist.isNotEmpty) {
        await playSong(_playlist[0]);
      }
      return;
    }

    final currentPlaylist = _getCurrentPlaylist();
    int currentIndex = currentPlaylist.indexWhere(
            (song) => song.id == _currentSong!.id
    );

    print("Current index: $currentIndex");
    print("Playlist length: ${currentPlaylist.length}");

    if (currentIndex == -1) {
      print("Current song not found in playlist, playing first");
      currentIndex = 0;
    }

    int nextIndex = (currentIndex + 1) % currentPlaylist.length;
    print("Next index: $nextIndex");

    if (currentPlaylist.isNotEmpty) {
      await playSong(currentPlaylist[nextIndex]);
    }
  }

  Future<void> playPrevious() async {
    print("=== PLAY PREVIOUS CALLED ===");

    if (_playlist.isEmpty || _currentSong == null) return;

    final currentPlaylist = _getCurrentPlaylist();
    int currentIndex = currentPlaylist.indexWhere(
            (song) => song.id == _currentSong!.id
    );

    if (currentIndex == -1) {
      currentIndex = 0;
    }

    int previousIndex = (currentIndex - 1) % currentPlaylist.length;
    if (previousIndex < 0) {
      previousIndex = currentPlaylist.length - 1;
    }

    await playSong(currentPlaylist[previousIndex]);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    print("=== SET REPEAT MODE: $repeatMode ===");
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _isRepeating = false;
        break;
      case AudioServiceRepeatMode.one:
        _isRepeating = true;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        _isRepeating = true;
        break;
    }
    notifyListeners();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    print("=== SET SHUFFLE MODE: $shuffleMode ===");
    _isShuffled = shuffleMode == AudioServiceShuffleMode.all;
    if (_isShuffled) {
      _updateShuffledPlaylist();
    }
    notifyListeners();
  }

  void removeSong(Song song) {
    _playlist.removeWhere((s) => s.id == song.id);
    _shuffledPlaylist.removeWhere((s) => s.id == song.id);

    if (_currentSong?.id == song.id) {
      _currentSong = null;
      _audioPlayer.stop();
      _isPlaying = false;
      _currentPosition = Duration.zero;

      // Update media item
      mediaItem.add(null);

      // Update playback state
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ));
    }

    notifyListeners();
  }

  List<Song> _getCurrentPlaylist() {
    return _isShuffled ? _shuffledPlaylist : _playlist;
  }

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    if (_isShuffled) {
      _updateShuffledPlaylist();
    }
    setShuffleMode(_isShuffled
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none);
  }

  void toggleRepeat() {
    _isRepeating = !_isRepeating;
    setRepeatMode(_isRepeating
        ? AudioServiceRepeatMode.one
        : AudioServiceRepeatMode.none);
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      String hours = twoDigits(duration.inHours);
      return "$hours:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}