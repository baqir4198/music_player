// screens/category_view_screen.dart
import 'package:flutter/material.dart';
import 'package:music_player/models/song.dart';
import 'package:music_player/widgets/folder_tile.dart';
import 'folder_songs_screen.dart';

class CategoryViewScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String itemType;

  const CategoryViewScreen({
    super.key,
    required this.title,
    required this.items,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sort items alphabetically with null safety
    final sortedItems = List<Map<String, dynamic>>.from(items);
    sortedItems.sort((a, b) {
      final aTitle = a['title'] as String? ?? '';
      final bTitle = b['title'] as String? ?? '';
      return aTitle.compareTo(bTitle);
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${sortedItems.length} ${sortedItems.length == 1 ? 'item' : 'items'}',
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
          // Global menu for the category
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'sort':
                  _showSortOptions(context);
                  break;
                case 'select':
                  _showSelectAll(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(Icons.sort, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Sort', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'select',
                child: Row(
                  children: [
                    Icon(Icons.select_all, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Select All', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: sortedItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(),
              size: 60,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No $title found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sortedItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = sortedItems[index];

          // Safely extract data with null checks
          final itemTitle = item['title'] as String? ?? 'Unknown';
          final itemSubtitle = item['subtitle'] as String? ?? '';
          final itemSongs = item['songs'] as List<Song>? ?? [];

          return FolderTile(
            title: itemTitle,
            subtitle: itemSubtitle,
            icon: _getIconForType(itemType),
            count: itemSongs.length,
            onTap: () {
              if (itemSongs.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderSongsScreen(
                      folderName: itemTitle,
                      songs: itemSongs,
                      folderType: _getFolderType(itemType),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No songs in this $itemType'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            },
            onMenuTap: () => _showFolderMenu(context, itemTitle, itemType, itemSongs),
          );
        },
      ),
    );
  }

  void _showFolderMenu(BuildContext context, String folderName, String type, List<Song> songs) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          folderName,
          style: theme.textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.play_arrow, color: theme.colorScheme.primary),
              title: const Text('Play All'),
              onTap: () {
                Navigator.pop(context);
                if (songs.isNotEmpty) {
                  // Navigate to now playing with first song
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderSongsScreen(
                        folderName: folderName,
                        songs: songs,
                        folderType: type,
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.shuffle, color: theme.colorScheme.primary),
              title: const Text('Shuffle Play'),
              onTap: () {
                Navigator.pop(context);
                if (songs.isNotEmpty) {
                  // Shuffle and play
                  final shuffledSongs = List<Song>.from(songs)..shuffle();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderSongsScreen(
                        folderName: '$folderName (Shuffled)',
                        songs: shuffledSongs,
                        folderType: type,
                      ),
                    ),
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.edit, color: theme.colorScheme.primary),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, folderName, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, folderName, type);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String currentName, String type) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rename $type',
          style: theme.textTheme.titleLarge,
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter new name',
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
                    content: Text('Renamed to "${controller.text}"'),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String folderName, String type) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete $type',
          style: theme.textTheme.titleLarge,
        ),
        content: Text('Are you sure you want to delete "$folderName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$folderName deleted'),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sort By',
          style: theme.textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Name (A to Z)'),
              onTap: () {
                Navigator.pop(context);
                // Implement sort logic here
              },
            ),
            ListTile(
              title: const Text('Name (Z to A)'),
              onTap: () {
                Navigator.pop(context);
                // Implement sort logic here
              },
            ),
            ListTile(
              title: const Text('Song Count'),
              onTap: () {
                Navigator.pop(context);
                // Implement sort logic here
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectAll(BuildContext context) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Select All feature coming soon'),
        duration: const Duration(seconds: 2),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'artist':
        return Icons.person;
      case 'album':
        return Icons.album;
      case 'folder':
        return Icons.folder;
      default:
        return Icons.music_note;
    }
  }

  IconData _getEmptyIcon() {
    switch (itemType) {
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

  String _getFolderType(String type) {
    switch (type) {
      case 'artist':
        return 'Artist';
      case 'album':
        return 'Album';
      case 'folder':
        return 'Folder';
      default:
        return 'Category';
    }
  }
}