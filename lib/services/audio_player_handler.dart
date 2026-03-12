import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player/models/song.dart';
import 'dart:async';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<Song> _queue = [];
  int _currentIndex = 0;

  // Stream controllers for UI updates
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();

  // Timer for position updates when screen is off
  Timer? _positionUpdateTimer;

  // Timer for delayed notification removal
  Timer? _notificationTimer;

  // Store last media item for notification
  MediaItem? _lastMediaItem;

  // Track if we're in a paused state
  bool _isPaused = false;

  // Public streams for UI to listen to
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  // Playlist management
  List<Song> _playlist = [];
  List<Song> get playlist => List.unmodifiable(_playlist);

  // Current song
  Song? _currentSong;
  Song? get currentSong => _currentSong;

  // Playback state
  bool _isPlaying = false;
  bool get isPlaying => _player.playing;

  bool _isShuffled = false;
  bool get isShuffled => _isShuffled;

  bool _isRepeating = false;
  bool get isRepeating => _isRepeating;

  Duration _currentPosition = Duration.zero;
  Duration get currentPosition => _currentPosition;

  Duration _totalDuration = Duration.zero;
  Duration get totalDuration => _totalDuration;

  AudioPlayerHandler() {
    print('🎵 [DEBUG] AudioPlayerHandler constructor called');
    _initPlayer();
    _startPositionTimer();
  }

  // Schedule notification removal after delay (only when fully stopped)
  void _scheduleNotificationRemoval() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 30), () {
      print('🎵 [DEBUG] Removing notification after delay');
      mediaItem.add(null);
      _lastMediaItem = null;
    });
  }

  // Cancel notification removal
  void _cancelNotificationRemoval() {
    _notificationTimer?.cancel();
  }

  // Restore notification (when resuming playback)
  void _restoreNotification() {
    if (_lastMediaItem != null) {
      print('🎵 [DEBUG] Restoring notification');
      mediaItem.add(_lastMediaItem);
    }
  }

  void _startPositionTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_player.playing && !_positionController.isClosed) {
        _currentPosition += const Duration(milliseconds: 200);
        _positionController.add(_currentPosition);
      }
    });
  }

  void _initPlayer() {
    print('🎵 [DEBUG] Initializing player...');

    // Listen for when the player completes a song
    _player.playerStateStream.listen((state) {
      print('🎵 [DEBUG] Player state: ${state.processingState}');
      if (state.processingState == ProcessingState.completed) {
        print('🎵 [DEBUG] Song completed, playing next');
        skipToNext();
      }
    });

    // Update playback state
    _player.playbackEventStream.listen((event) {
      _currentPosition = event.updatePosition;
      _totalDuration = event.duration ?? Duration.zero;

      print('🎵 [DEBUG] Playback event: playing=${_player.playing}, position=${event.updatePosition}');

      playbackState.add(playbackState.value.copyWith(
        playing: _player.playing,
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
        queueIndex: event.currentIndex,
        processingState: _player.playing
            ? AudioProcessingState.ready
            : (_player.processingState == ProcessingState.completed
            ? AudioProcessingState.completed
            : AudioProcessingState.ready), // Keep as ready when paused
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
      ));

      // Handle notification based on state
      if (!_player.playing && _currentSong != null) {
        // We're paused - keep notification
        _isPaused = true;
        _positionUpdateTimer?.cancel();
      } else if (_player.playing) {
        // We're playing - ensure notification is showing
        _isPaused = false;
        _cancelNotificationRemoval();
        if (_lastMediaItem != null) {
          _restoreNotification();
        }
      }
    });

    // Listen to position changes for UI - emit to stream
    _player.positionStream.listen((position) {
      _currentPosition = position;
      if (!_positionController.isClosed) {
        _positionController.add(position);
      }
    });

    // Listen to duration changes - emit to stream
    _player.durationStream.listen((duration) {
      if (duration != null) {
        _totalDuration = duration;
        if (!_durationController.isClosed) {
          _durationController.add(duration);
        }
      }
    });
  }

  @override
  Future<void> play() {
    print('🎵 [DEBUG] Play button pressed');
    _cancelNotificationRemoval();
    _restoreNotification(); // Ensure notification is showing
    _startPositionTimer();
    return _player.play();
  }

  @override
  Future<void> pause() {
    print('🎵 [DEBUG] Pause button pressed');
    _positionUpdateTimer?.cancel();
    _isPaused = true;
    // DON'T schedule removal - keep notification when paused
    // DON'T clear media item
    return _player.pause();
  }

  @override
  Future<void> stop() {
    print('🎵 [DEBUG] Stop button pressed');
    _positionUpdateTimer?.cancel();
    // Only schedule removal when fully stopped
    _scheduleNotificationRemoval();
    return _player.stop();
  }

  @override
  Future<void> seek(Duration position) {
    print('🎵 [DEBUG] Seek to $position');
    return _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    print('🎵 [DEBUG] Skip to next');
    if (_queue.isEmpty) {
      print('🎵 [DEBUG] Queue is empty');
      return;
    }
    _currentIndex = (_currentIndex + 1) % _queue.length;
    await _playCurrent();
  }

  @override
  Future<void> skipToPrevious() async {
    print('🎵 [DEBUG] Skip to previous');
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex - 1) % _queue.length;
    if (_currentIndex < 0) _currentIndex = _queue.length - 1;
    await _playCurrent();
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    try {
      print('🎵 [DEBUG] ===== PLAYING SONG: ${song.title} =====');

      _cancelNotificationRemoval();

      if (queue != null) {
        print('🎵 [DEBUG] Setting new queue with ${queue.length} songs');
        _queue.clear();
        _queue.addAll(queue);
        _currentIndex = _queue.indexOf(song);
        _playlist = List.from(queue);
      } else {
        if (_queue.isEmpty) {
          print('🎵 [DEBUG] Queue empty, adding single song');
          _queue.add(song);
          _currentIndex = 0;
          _playlist = [song];
        } else {
          int index = _queue.indexWhere((s) => s.id == song.id);
          if (index >= 0) {
            print('🎵 [DEBUG] Song found in queue at index $index');
            _currentIndex = index;
          } else {
            print('🎵 [DEBUG] Adding song to queue');
            _queue.add(song);
            _currentIndex = _queue.length - 1;
            _playlist.add(song);
          }
        }
      }

      _currentSong = song;
      print('🎵 [DEBUG] Current song set to: ${_currentSong?.title}');

      // Update notification with song info
      print('🎵 [DEBUG] Updating media item for notification');
      _lastMediaItem = MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
        artUri: song.coverUrl != null ? Uri.parse(song.coverUrl!) : null,
      );
      mediaItem.add(_lastMediaItem);
      print('🎵 [DEBUG] Media item added: ${_lastMediaItem?.title}');

      // Play the audio
      print('🎵 [DEBUG] Setting audio source');
      if (song.isLocal && song.audioPath != null) {
        print('🎵 [DEBUG] Playing local file: ${song.audioPath}');
        await _player.setAudioSource(AudioSource.uri(Uri.file(song.audioPath!)));
      } else {
        String url = song.audioPath ??
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
        print('🎵 [DEBUG] Playing URL: $url');
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      }

      print('🎵 [DEBUG] Starting playback');
      await _player.play();
      _isPlaying = true;
      _startPositionTimer();
      print('🎵 [DEBUG] Playback started successfully');
      print('🎵 [DEBUG] ===== END PLAY SONG =====');

    } catch (e) {
      print('🎵 [DEBUG] ERROR playing song: $e');
    }
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty) return;
    final song = _queue[_currentIndex];
    await playSong(song);
  }

  Future<void> setPlaylist(List<Song> songs) async {
    print('🎵 [DEBUG] Setting playlist with ${songs.length} songs');
    _playlist = List.from(songs);
    _queue.clear();
    _queue.addAll(songs);
    if (songs.isNotEmpty && _currentIndex >= 0 && _currentIndex < songs.length) {
      _currentSong = songs[_currentIndex];
    }
  }

  Future<void> addToPlaylist(List<Song> songs) async {
    print('🎵 [DEBUG] Adding ${songs.length} songs to playlist');
    _playlist.addAll(songs);
    _queue.addAll(songs);
  }

  void removeSong(Song song) {
    print('🎵 [DEBUG] Removing song: ${song.title}');
    _playlist.removeWhere((s) => s.id == song.id);
    int removedIndex = _queue.indexWhere((s) => s.id == song.id);
    _queue.removeWhere((s) => s.id == song.id);

    if (_currentSong?.id == song.id) {
      _currentSong = null;
      _player.stop();
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _lastMediaItem = null;
      mediaItem.add(null);
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        controls: [],
      ));
      _positionUpdateTimer?.cancel();
      _cancelNotificationRemoval();
    } else {
      if (removedIndex < _currentIndex) {
        _currentIndex--;
      }
    }

    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.isEmpty ? 0 : _queue.length - 1;
    }

    if (_queue.isNotEmpty && _currentIndex < _queue.length) {
      _currentSong = _queue[_currentIndex];
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        _isRepeating = false;
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        _isRepeating = true;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        _isRepeating = true;
        break;
    }
    super.setRepeatMode(repeatMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _isShuffled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(_isShuffled);
    super.setShuffleMode(shuffleMode);
  }

  void toggleShuffle() {
    setShuffleMode(_isShuffled
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all);
  }

  void toggleRepeat() {
    setRepeatMode(_isRepeating
        ? AudioServiceRepeatMode.none
        : AudioServiceRepeatMode.one);
  }

  void playPause() {
    if (_player.playing) {
      pause();
    } else {
      play();
    }
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

  void dispose() {
    _positionUpdateTimer?.cancel();
    _notificationTimer?.cancel();
    _positionController.close();
    _durationController.close();
    _player.dispose();
  }
}