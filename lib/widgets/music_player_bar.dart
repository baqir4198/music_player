import 'package:flutter/material.dart';
import 'package:music_player/screens/now_playing_screen.dart';
import 'package:music_player/services/audio_player_handler.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';

class MusicPlayerBar extends StatefulWidget {
  const MusicPlayerBar({super.key});

  @override
  State<MusicPlayerBar> createState() => _MusicPlayerBarState();
}

class _MusicPlayerBarState extends State<MusicPlayerBar> {
  // Local state for UI updates
  bool _isPlaying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audioHandler = Provider.of<AudioPlayerHandler>(context);

    // Listen to playback state changes
    audioHandler.playbackState.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AudioPlayerHandler>(
      builder: (context, audioHandler, child) {
        final currentSong = audioHandler.currentSong;

        if (currentSong == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NowPlayingScreen(),
              ),
            );
          },
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Album art container
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: _getAlbumImage(currentSong),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Song info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentSong.artist,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Control buttons row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Previous button
                      IconButton(
                        icon: Icon(
                          Icons.skip_previous,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: audioHandler.skipToPrevious,
                        tooltip: 'Previous',
                      ),

                      // Play/Pause button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 22,
                            color: theme.colorScheme.onPrimary,
                          ),
                          onPressed: audioHandler.playPause,
                          padding: EdgeInsets.zero,
                          tooltip: _isPlaying ? 'Pause' : 'Play',
                        ),
                      ),

                      // Next button
                      IconButton(
                        icon: Icon(
                          Icons.skip_next,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: audioHandler.skipToNext,
                        tooltip: 'Next',
                      ),

                      // Stop button - changed to primary color with better tooltip
                      IconButton(
                        icon: Icon(
                          Icons.stop,
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () => audioHandler.stop(),
                        tooltip: 'Stop playback',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to get the correct image
  DecorationImage _getAlbumImage(Song song) {
    if (song.coverUrl != null) {
      return DecorationImage(
        image: NetworkImage(song.coverUrl!),
        fit: BoxFit.cover,
      );
    } else if (song.coverImage != null) {
      return DecorationImage(
        image: MemoryImage(song.coverImage!),
        fit: BoxFit.cover,
      );
    } else {
      return const DecorationImage(
        image: AssetImage('assets/images/default_album.jpg'),
        fit: BoxFit.cover,
      );
    }
  }
}