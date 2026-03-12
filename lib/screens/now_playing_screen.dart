import 'dart:async';
import 'dart:io';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:music_player/services/audio_player_handler.dart';
import 'package:music_player/services/favorites_service.dart';
import 'package:music_player/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/song.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _isFavorite = false;
  final List<Map<String, dynamic>> _playlists = [
    {'name': 'Workout', 'songs': []},
    {'name': 'Relax', 'songs': []},
    {'name': 'Road Trip', 'songs': []},
  ];

  // Stream subscriptions
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  // Local state for UI updates
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isSliderDragging = false;
  double _sliderValue = 0.0;
  bool _isShuffled = false;
  bool _isRepeating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfFavorite();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupStreamListeners();
  }

  void _setupStreamListeners() {
    final audioHandler = Provider.of<AudioPlayerHandler>(context, listen: false);

    // Cancel existing subscriptions
    _playbackStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();

    // Listen to playback state changes
    _playbackStateSubscription = audioHandler.playbackState.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    // Listen to position changes (updates frequently - every 200ms)
    _positionSubscription = audioHandler.positionStream.listen((position) {
      if (mounted && !_isSliderDragging) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration changes
    _durationSubscription = audioHandler.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    // Initialize with current values
    _isShuffled = audioHandler.isShuffled;
    _isRepeating = audioHandler.isRepeating;
    _currentPosition = audioHandler.currentPosition;
    _totalDuration = audioHandler.totalDuration;
  }

  @override
  void dispose() {
    _playbackStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    super.dispose();
  }

  void _checkIfFavorite() {
    final audioHandler = Provider.of<AudioPlayerHandler>(context, listen: false);
    final favoritesService = Provider.of<FavoritesService>(context, listen: false);
    final currentSong = audioHandler.currentSong;
    if (currentSong != null) {
      setState(() {
        _isFavorite = favoritesService.isFavorite(currentSong.id);
      });
    }
  }

  Future<void> _shareSong(dynamic song) async {
    try {
      if (song.audioPath == null || song.audioPath!.isEmpty) {
        _showSnackBar('No audio file available to share');
        return;
      }

      String filePath = song.audioPath!;

      if (filePath.startsWith('file://')) {
        filePath = filePath.replaceFirst('file://', '');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        _showSnackBar('Audio file not found on device');
        return;
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Check out this song: ${song.title} by ${song.artist ?? "Unknown"}',
        subject: 'Song: ${song.title}',
      );

      _showSnackBar('Song shared successfully');

    } catch (e) {
      debugPrint('Error sharing file: $e');
      _showSnackBar('Error sharing song');
    }
  }

  String _formatDuration(Duration duration) {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);
    final audioHandler = Provider.of<AudioPlayerHandler>(context);
    final favoritesService = Provider.of<FavoritesService>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, theme),
            Expanded(
              child: Consumer<AudioPlayerHandler>(
                builder: (context, audioHandler, child) {
                  final song = audioHandler.currentSong;

                  if (song == null) {
                    return Center(
                      child: Text(
                        'No song playing',
                        style: theme.textTheme.bodyLarge,
                      ),
                    );
                  }

                  // Update shuffle and repeat state
                  _isShuffled = audioHandler.isShuffled;
                  _isRepeating = audioHandler.isRepeating;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          _buildAlbumArt(song, theme),
                          const SizedBox(height: 40),
                          _buildSongInfo(song, theme, themeService),
                          const SizedBox(height: 30),
                          _buildProgressBar(audioHandler),
                          const SizedBox(height: 30),
                          _buildControls(audioHandler, theme, themeService),
                          const SizedBox(height: 40),
                          _buildAdditionalControls(audioHandler, song, theme, themeService, favoritesService),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 28,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'NOW PLAYING',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(dynamic song, ThemeData theme) {
    ImageProvider imageProvider;

    if (song.coverImage != null) {
      imageProvider = NetworkImage(song.coverImage!);
    } else if (song.coverUrl != null) {
      imageProvider = NetworkImage(song.coverUrl!);
    } else {
      imageProvider = const AssetImage('assets/images/default_album.jpg');
    }

    return Center(
      child: Hero(
        tag: 'album-art-${song.id}',
        child: Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
              onError: (exception, stackTrace) {
                debugPrint('Error loading image: $exception');
              },
            ),
          ),
          child: song.coverImage == null && song.coverUrl == null
              ? Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Icon(
                Icons.music_note,
                size: 100,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ),
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildSongInfo(dynamic song, ThemeData theme, ThemeService themeService) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: SizedBox(
              width: double.infinity,
              child: AnimatedTextKit(
                key: ValueKey(song?.id),
                animatedTexts: [
                  TyperAnimatedText(
                    song?.title ?? 'Unknown Title',
                    textStyle: themeService.getTitleStyle().copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    speed: const Duration(milliseconds: 100),
                  ),
                ],
                totalRepeatCount: 1,
                isRepeatingAnimation: false,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          song?.artist ?? 'Unknown Artist',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        if (song?.album != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              song!.album!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(AudioPlayerHandler audioHandler) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(context).colorScheme.surface,
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            min: 0,
            max: _totalDuration.inSeconds.toDouble() > 0
                ? _totalDuration.inSeconds.toDouble()
                : 1.0,
            value: _currentPosition.inSeconds.toDouble().clamp(
                0,
                _totalDuration.inSeconds.toDouble() > 0
                    ? _totalDuration.inSeconds.toDouble()
                    : 1.0
            ),
            onChanged: (value) {
              setState(() {
                _isSliderDragging = true;
                _sliderValue = value;
              });
            },
            onChangeEnd: (value) {
              audioHandler.seek(Duration(seconds: value.toInt()));
              setState(() {
                _isSliderDragging = false;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDuration(_currentPosition),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDuration(_totalDuration),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(AudioPlayerHandler audioHandler, ThemeData theme, ThemeService themeService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle button
        IconButton(
          icon: Icon(
            themeService.getShuffleIcon(_isShuffled),
            color: _isShuffled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5),
            size: themeService.getControlButtonSize(),
          ),
          onPressed: () {
            audioHandler.toggleShuffle();
            setState(() {
              _isShuffled = !_isShuffled;
            });
          },
        ),
        const SizedBox(width: 5),

        // Previous button
        IconButton(
          icon: Icon(
            themeService.getSkipPreviousIcon(),
            color: theme.colorScheme.onSurface,
            size: themeService.getControlButtonSize() + 4,
          ),
          onPressed: () => audioHandler.skipToPrevious(),
        ),
        const SizedBox(width: 5),

        // Play/Pause button
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              themeService.getPlayIcon(_isPlaying),
              color: theme.colorScheme.onPrimary,
              size: themeService.getPlayButtonSize(),
            ),
            onPressed: () => audioHandler.playPause(),
          ),
        ),
        const SizedBox(width: 5),

        // Next button
        IconButton(
          icon: Icon(
            themeService.getSkipNextIcon(),
            color: theme.colorScheme.onSurface,
            size: themeService.getControlButtonSize() + 4,
          ),
          onPressed: () => audioHandler.skipToNext(),
        ),
        const SizedBox(width: 5),

        // Repeat button
        IconButton(
          icon: Icon(
            themeService.getRepeatIcon(_isRepeating),
            color: _isRepeating ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5),
            size: themeService.getControlButtonSize(),
          ),
          onPressed: () {
            audioHandler.toggleRepeat();
            setState(() {
              _isRepeating = !_isRepeating;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAdditionalControls(AudioPlayerHandler audioHandler, dynamic song, ThemeData theme, ThemeService themeService, FavoritesService favoritesService) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Favorite button
          Expanded(
            child: InkWell(
              onTap: () => _toggleFavorite(song, favoritesService),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : theme.colorScheme.onSurface,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Favorite',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Share button
          Expanded(
            child: InkWell(
              onTap: () => _shareSong(song),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.share,
                    color: theme.colorScheme.onSurface,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Delete button
          Expanded(
            child: InkWell(
              onTap: () => _showDeleteConfirmation(audioHandler, song, theme, favoritesService),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Delete',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // More button
          Expanded(
            child: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'favorites':
                    _showFavoritesList(theme, favoritesService);
                    break;
                  case 'playlist':
                    _showPlaylistOptions(theme);
                    break;
                  case 'ringtone':
                    _setAsRingtone(theme);
                    break;
                  case 'info':
                    if (song != null) {
                      _showSongInfo(song, theme);
                    }
                    break;
                }
              },
              color: theme.colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.more_horiz,
                    color: theme.colorScheme.onSurface,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'More',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'favorites',
                  child: Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Text('My Favorites (${favoritesService.favoriteSongs.length})'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      const Text('Add to Playlist'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'ringtone',
                  child: Row(
                    children: [
                      Icon(Icons.ring_volume, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      const Text('Set as Ringtone'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      const Text('Song Info'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(dynamic song, FavoritesService favoritesService) {
    favoritesService.toggleFavorite(song as Song);
    setState(() {
      _isFavorite = favoritesService.isFavorite(song.id);
    });
    _showSnackBar(_isFavorite ? 'Added to favorites' : 'Removed from favorites');
  }

  void _showFavoritesList(ThemeData theme, FavoritesService favoritesService) {
    final favoriteSongs = favoritesService.favoriteSongs;

    if (favoriteSongs.isEmpty) {
      _showSnackBar('No favorite songs yet');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'My Favorite Songs',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: favoriteSongs.length,
                itemBuilder: (context, index) {
                  final favSong = favoriteSongs[index];
                  return Card(
                    color: theme.colorScheme.surface,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.music_note, color: theme.colorScheme.primary, size: 20),
                      ),
                      title: Text(
                        favSong.title,
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        favSong.artist ?? 'Unknown',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle, color: theme.colorScheme.error, size: 22),
                        onPressed: () {
                          favoritesService.removeFavorite(favSong.id);
                          if (favSong.id == (context.read<AudioPlayerHandler>().currentSong?.id)) {
                            setState(() {
                              _isFavorite = false;
                            });
                          }
                          Navigator.pop(context);
                          _showSnackBar('Removed from favorites');
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        context.read<AudioPlayerHandler>().playSong(favSong);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistOptions(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add to Playlist',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ..._playlists.map((playlist) => ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Icon(Icons.playlist_play, color: theme.colorScheme.primary, size: 18),
              ),
              title: Text(
                playlist['name'],
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                '${playlist['songs'].length} songs',
                style: theme.textTheme.bodySmall,
              ),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Added to "${playlist['name']}"');
              },
            )),
            const Divider(height: 30),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.green.withOpacity(0.1),
                child: const Icon(Icons.add, color: Colors.green, size: 18),
              ),
              title: const Text('Create New Playlist'),
              onTap: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(theme);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(ThemeData theme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create New Playlist',
          style: theme.textTheme.titleLarge,
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter playlist name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _playlists.add({'name': controller.text, 'songs': []});
                });
                Navigator.pop(context);
                _showSnackBar('Playlist "${controller.text}" created');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _setAsRingtone(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Set as Ringtone',
          style: theme.textTheme.titleLarge,
        ),
        content: const Text('Set this song as your phone ringtone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Song set as ringtone (Demo)');
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showSongInfo(dynamic song, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          song.title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(theme, 'Artist', song.artist ?? 'Unknown'),
              const Divider(height: 16),
              _buildInfoRow(theme, 'Album', song.album ?? 'Unknown'),
              if (song.duration != null) ...[
                const Divider(height: 16),
                _buildInfoRow(theme, 'Duration', _formatDuration(song.duration)),
              ],
              if (song.audioPath != null) ...[
                const Divider(height: 16),
                _buildInfoRow(theme, 'Path', song.audioPath),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  void _showDeleteConfirmation(AudioPlayerHandler audioHandler, dynamic song, ThemeData theme, FavoritesService favoritesService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Song',
          style: theme.textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to delete "${song.title}" from your device?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_isFavorite) {
                favoritesService.removeFavorite(song.id);
                setState(() {
                  _isFavorite = false;
                });
              }
              _showSnackBar('Song deleted (Demo)');
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }
}