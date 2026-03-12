import 'package:flutter/material.dart';
import 'package:music_player/services/audio_player_handler.dart'; // Changed import
import 'package:provider/provider.dart';
import '../models/song.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final Function? onDelete;
  final Function? onAddToPlaylist;
  final Function? onShare;
  final Function? onSongInfo;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onDelete,
    this.onAddToPlaylist,
    this.onShare,
    this.onSongInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioHandler = Provider.of<AudioPlayerHandler>(context); // Changed to AudioPlayerHandler
    final isCurrentSong = audioHandler.currentSong?.id == song.id;

    return ListTile(
      leading: Hero(
        tag: 'album-art-${song.id}',
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.primary.withOpacity(0.1),
            image: _getCoverImage(),
          ),
          child: song.coverUrl == null && song.coverImage == null
              ? Icon(Icons.music_note, color: theme.colorScheme.primary)
              : null,
        ),
      ),
      title: Text(
        song.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
          color: isCurrentSong ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isCurrentSong
              ? theme.colorScheme.primary.withOpacity(0.7)
              : theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Playing indicator
          if (isCurrentSong && audioHandler.isPlaying) // Changed to isPlaying
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                size: 12,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          const SizedBox(width: 8),

          // Duration
          Text(
            audioHandler.formatDuration(song.duration), // Changed to audioHandler
            style: theme.textTheme.bodySmall?.copyWith(
              color: isCurrentSong
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 4),

          // Three-dot menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isCurrentSong
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
              size: 20,
            ),
            onSelected: (value) {
              switch (value) {
                case 'playlist':
                  if (onAddToPlaylist != null) onAddToPlaylist!();
                  break;
                case 'share':
                  if (onShare != null) onShare!();
                  break;
                case 'info':
                  if (onSongInfo != null) onSongInfo!();
                  break;
                case 'delete':
                  if (onDelete != null) onDelete!();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Add to Playlist', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Share', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Song Info', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: theme.colorScheme.error, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  DecorationImage? _getCoverImage() {
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
    }
    return null;
  }
}