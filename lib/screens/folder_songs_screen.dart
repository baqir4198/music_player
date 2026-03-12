// screens/folder_songs_screen.dart
import 'package:flutter/material.dart';
import 'package:music_player/models/song.dart';
import 'package:music_player/services/audio_player_handler.dart'; // Changed import
import 'package:music_player/widgets/song_tile.dart';
import 'package:provider/provider.dart';
import 'now_playing_screen.dart';

class FolderSongsScreen extends StatelessWidget {
  final String folderName;
  final List<Song> songs;
  final String folderType;

  const FolderSongsScreen({
    super.key,
    required this.folderName,
    required this.songs,
    required this.folderType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              folderName,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$folderType • ${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (songs.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'play_all':
                    _playAllSongs(context);
                    break;
                  case 'shuffle_all':
                    _shuffleAllSongs(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'play_all',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow, color: theme.colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      const Text('Play All'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'shuffle_all',
                  child: Row(
                    children: [
                      Icon(Icons.shuffle, color: theme.colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      const Text('Shuffle All'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: songs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(),
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No songs in this $folderType',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: songs.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 72,
          color: theme.dividerColor,
        ),
        itemBuilder: (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            onTap: () {
              final audioHandler = Provider.of<AudioPlayerHandler>(context, listen: false);
              audioHandler.playSong(song);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NowPlayingScreen(),
                ),
              );
            },
            onDelete: () => _showDeleteConfirmation(context, song),
            onAddToPlaylist: () => _showAddToPlaylist(context, song),
            onShare: () => _shareSong(context, song),
            onSongInfo: () => _showSongInfo(context, song),
          );
        },
      ),
    );
  }

  void _playAllSongs(BuildContext context) {
    if (songs.isEmpty) return;

    final audioHandler = Provider.of<AudioPlayerHandler>(context, listen: false);
    audioHandler.playSong(songs.first);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NowPlayingScreen(),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing all songs from $folderName'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _shuffleAllSongs(BuildContext context) {
    if (songs.isEmpty) return;

    final shuffledSongs = List<Song>.from(songs)..shuffle();
    final audioHandler = Provider.of<AudioPlayerHandler>(context, listen: false);
    audioHandler.playSong(shuffledSongs.first);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NowPlayingScreen(),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shuffling songs from $folderName'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Song song) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Song',
          style: theme.textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to delete "${song.title}"?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${song.title} deleted'),
                  backgroundColor: theme.colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context, Song song) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add to Playlist',
          style: theme.textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.favorite, color: Colors.red),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added to Favorites'),
                    backgroundColor: theme.colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.access_time, color: theme.colorScheme.primary),
              title: const Text('Recently Played'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added to Recently Played'),
                    backgroundColor: theme.colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add, color: Colors.green),
              title: const Text('Create New Playlist'),
              onTap: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(context, song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, Song song) {
    final theme = Theme.of(context);
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
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playlist "${controller.text}" created and song added'),
                    backgroundColor: theme.colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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

  void _shareSong(BuildContext context, Song song) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing ${song.title}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSongInfo(BuildContext context, Song song) {
    final theme = Theme.of(context);

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
              _buildInfoRow(context, 'Artist', song.artist ?? 'Unknown'),
              const Divider(height: 16),
              _buildInfoRow(context, 'Album', song.album ?? 'Unknown'),
              if (song.duration != null) ...[
                const Divider(height: 16),
                _buildInfoRow(context, 'Duration', _formatDuration(song.duration!)),
              ],
              if (song.audioPath != null) ...[
                const Divider(height: 16),
                _buildInfoRow(context, 'Path', song.audioPath!),
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

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  IconData _getEmptyIcon() {
    switch (folderType.toLowerCase()) {
      case 'artist':
        return Icons.person_off;
      case 'album':
        return Icons.album;
      case 'folder':
        return Icons.folder_off;
      default:
        return Icons.music_off;
    }
  }
}