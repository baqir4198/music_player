import 'dart:io';
import 'package:flutter/material.dart';
import 'package:music_player/models/song.dart';
import 'package:music_player/services/audio_player_handler.dart'; // Changed import
import 'package:music_player/services/favorites_service.dart';
import 'package:music_player/services/local_music_service.dart';
import 'package:music_player/services/permission_service.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/music_player_bar.dart';
import '../widgets/song_tile.dart';
import '../widgets/folder_tile.dart';
import '../widgets/category_card.dart';
import '../widgets/app_drawer.dart';
import 'now_playing_screen.dart';
import 'folder_songs_screen.dart';
import 'category_view_screen.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LocalMusicService _localMusicService = LocalMusicService();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<Song> _localSongs = [];
  bool _isLoading = false;
  bool _hasPermission = false;
  bool _isScanning = false;
  bool _isDataLoaded = false;
  bool _isDeleting = false;
  bool _isRefreshing = false;
  int _removedCount = 0;

  final ScrollController _allSongsScrollController = ScrollController();
  final ScrollController _localMusicScrollController = ScrollController();

  Map<String, List<Song>> _artistFolders = {};
  Map<String, List<Song>> _albumFolders = {};
  List<String> _folderPaths = [];
  Map<String, List<Song>> _folderStructure = {};

  int _artistCount = 0;
  int _albumCount = 0;
  int _folderCount = 0;
  int _totalSongs = 0;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Playlists (Favorites moved to service)
  List<Map<String, dynamic>> _userPlaylists = [];

  late List<Map<String, dynamic>> _categories;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionAndLoad();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to favorites changes
    final favoritesService = Provider.of<FavoritesService>(context);
    favoritesService.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    final favoritesService = Provider.of<FavoritesService>(context, listen: false);
    favoritesService.removeListener(_onFavoritesChanged);
    _tabController.dispose();
    _searchController.dispose();
    _allSongsScrollController.dispose();
    _localMusicScrollController.dispose();
    super.dispose();
  }

  void _onFavoritesChanged() {
    // Rebuild categories when favorites change
    if (mounted) {
      setState(() {
        _buildCategories();
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<Song> _filterSongs(List<Song> songs, String query) {
    if (query.isEmpty) return songs;
    return songs.where((song) {
      final titleLower = song.title.toLowerCase();
      final artistLower = song.artist?.toLowerCase() ?? '';
      final albumLower = song.album?.toLowerCase() ?? '';
      final queryLower = query.toLowerCase();
      return titleLower.contains(queryLower) ||
          artistLower.contains(queryLower) ||
          albumLower.contains(queryLower);
    }).toList();
  }

  String _decodeFolderName(String path) {
    try {
      final folderName = path.split('/').last;
      return Uri.decodeComponent(folderName);
    } catch (e) {
      return path.split('/').last;
    }
  }

  Future<void> _onRefresh() async {
    await _refreshLibrary();
  }

  Future<void> _refreshLibrary() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final songs = await _localMusicService.scanLocalSongs();
      if (!mounted) return;

      _localSongs = songs;
      _totalSongs = songs.length;

      await _verifyAndCleanMissingFiles(showMessage: false);

      await Future(() {
        _organizeSongsIntoFolders();
        _updateCategoryStats();
        _buildCategories();
      });

      final audioHandler = Provider.of<AudioPlayerHandler>(context, listen: false);
      await audioHandler.setPlaylist(_localSongs);

    } catch (e) {
      debugPrint('Error refreshing library: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _verifyAndCleanMissingFiles({bool showMessage = false}) async {
    debugPrint('=== Verifying files exist ===');

    List<Song> songsToRemove = [];

    for (var song in _localSongs) {
      if (song.isLocal && song.audioPath != null) {
        String cleanPath = song.audioPath!;
        if (cleanPath.startsWith('file://')) {
          cleanPath = cleanPath.replaceFirst('file://', '');
        }

        final file = File(cleanPath);
        final exists = await file.exists();

        if (!exists) {
          songsToRemove.add(song);
          debugPrint('Missing: ${song.title}');
        }
      }
    }

    if (songsToRemove.isNotEmpty) {
      debugPrint('Removing ${songsToRemove.length} missing songs');

      setState(() {
        _localSongs.removeWhere((song) => songsToRemove.contains(song));
        _removedCount = songsToRemove.length;
      });

      final audioHandler = Provider.of<AudioPlayerHandler>(context, listen: false);
      for (var song in songsToRemove) {
        audioHandler.removeSong(song);
      }

      _organizeSongsIntoFolders();
      _updateCategoryStats();
      _buildCategories();
    }
  }

  Future<void> _checkPermissionAndLoad() async {
    setState(() => _isLoading = true);

    bool granted = await _audioQuery.permissionsStatus();
    if (!granted) {
      granted = await _audioQuery.permissionsRequest();
    }

    _hasPermission = granted;

    if (_hasPermission && !_isDataLoaded) {
      await _loadDataInBackground();
    }

    if (mounted) setState(() {
      _isLoading = false;
      _isDataLoaded = true;
    });
  }

  Future<void> _loadDataInBackground() async {
    final songs = await _localMusicService.scanLocalSongs();
    if (!mounted) return;

    _localSongs = songs;
    _totalSongs = songs.length;

    await _verifyAndCleanMissingFiles(showMessage: false);

    await Future(() {
      _organizeSongsIntoFolders();
      _updateCategoryStats();
      _buildCategories();
    });

    final audioHandler = Provider.of<AudioPlayerHandler>(context, listen: false);
    await audioHandler.setPlaylist(_localSongs);
  }

  Future<void> _scanLocalSongs() async {
    if (_isScanning) return;
    _isScanning = true;
    try {
      final songs = await _localMusicService.scanLocalSongs();
      if (!mounted) return;

      await Future.microtask(() {
        if (mounted) {
          _localSongs = songs;
          _totalSongs = songs.length;
        }
      });

    } catch (e) {
      debugPrint('Error scanning local songs: $e');
    }
    _isScanning = false;
  }

  void _organizeSongsIntoFolders() {
    _artistFolders = {};
    for (var song in _localSongs) {
      final artist = song.artist ?? 'Unknown Artist';
      _artistFolders.putIfAbsent(artist, () => []).add(song);
    }

    _albumFolders = {};
    for (var song in _localSongs) {
      final album = song.album ?? 'Unknown Album';
      _albumFolders.putIfAbsent(album, () => []).add(song);
    }

    _folderStructure = {};
    for (var song in _localSongs) {
      if (song.audioPath != null) {
        final uri = Uri.parse(song.audioPath!);
        final path = uri.path;
        final folderPath = path.substring(0, path.lastIndexOf('/'));
        _folderStructure.putIfAbsent(folderPath, () => []).add(song);
      }
    }
    _folderPaths = _folderStructure.keys.toList();
  }

  void _updateCategoryStats() {
    _artistCount = _artistFolders.length;
    _albumCount = _albumFolders.length;
    _folderCount = _folderPaths.length;
  }

  void _buildCategories() {
    final favoritesService = Provider.of<FavoritesService>(context, listen: false);

    _categories = [
      {
        'title': 'Artists',
        'icon': Icons.person,
        'color': Colors.blue,
        'count': _artistCount,
        'type': 'artists',
        'subtitle': '$_artistCount ${_artistCount == 1 ? 'artist' : 'artists'}',
      },
      {
        'title': 'Albums',
        'icon': Icons.album,
        'color': Colors.green,
        'count': _albumCount,
        'type': 'albums',
        'subtitle': '$_albumCount ${_albumCount == 1 ? 'album' : 'albums'}',
      },
      {
        'title': 'Folders',
        'icon': Icons.folder,
        'color': Colors.orange,
        'count': _folderCount,
        'type': 'folders',
        'subtitle': '$_folderCount ${_folderCount == 1 ? 'folder' : 'folders'}',
      },
      {
        'title': 'Favorites',
        'icon': Icons.favorite,
        'color': Colors.red,
        'count': favoritesService.favoriteSongs.length,
        'type': 'favorites',
        'subtitle': '${favoritesService.favoriteSongs.length} ${favoritesService.favoriteSongs.length == 1 ? 'song' : 'songs'}',
      },
      {
        'title': 'My Playlists',
        'icon': Icons.playlist_play,
        'color': Colors.purple,
        'count': _userPlaylists.length,
        'type': 'playlists',
        'subtitle': '${_userPlaylists.length} ${_userPlaylists.length == 1 ? 'playlist' : 'playlists'}',
      },
      {
        'title': 'Genres',
        'icon': Icons.music_note,
        'color': Colors.purple,
        'count': 0,
        'type': 'genres',
        'subtitle': 'Coming soon',
      },
      {
        'title': 'Recently Added',
        'icon': Icons.access_time,
        'color': Colors.teal,
        'count': _localSongs.length > 20 ? 20 : _localSongs.length,
        'type': 'recent',
        'subtitle': 'Last 20 songs',
      },
    ];
  }

  List<Map<String, dynamic>> _getFilteredCategories() {
    if (_searchQuery.isEmpty) return _categories;
    return _categories.where((category) {
      final title = category['title'].toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);
    try {
      bool granted = await _audioQuery.permissionsRequest();
      _hasPermission = granted;
      if (_hasPermission && !_isDataLoaded) {
        await _loadDataInBackground();
      } else {
        PermissionService.showPermissionDialog(context);
      }
    } catch (e) {
      debugPrint('Permission error: $e');
      _hasPermission = false;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _navigateToCategory(String type) {
    switch (type) {
      case 'artists':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryViewScreen(
              title: 'Artists',
              items: _artistFolders.entries.map((entry) {
                return {
                  'title': entry.key,
                  'subtitle': '${entry.value.length} ${entry.value.length == 1 ? 'song' : 'songs'}',
                  'songs': entry.value,
                  'type': 'artist',
                };
              }).toList(),
              itemType: 'artist',
            ),
          ),
        );
        break;
      case 'albums':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryViewScreen(
              title: 'Albums',
              items: _albumFolders.entries.map((entry) {
                final artist = entry.value.isNotEmpty ? entry.value.first.artist : 'Unknown Artist';
                return {
                  'title': entry.key,
                  'subtitle': '$artist • ${entry.value.length} ${entry.value.length == 1 ? 'song' : 'songs'}',
                  'songs': entry.value,
                  'type': 'album',
                };
              }).toList(),
              itemType: 'album',
            ),
          ),
        );
        break;
      case 'folders':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryViewScreen(
              title: 'Folders',
              items: _folderPaths.map((path) {
                final songs = _folderStructure[path]!;
                final decodedName = _decodeFolderName(path);
                return {
                  'title': decodedName,
                  'subtitle': '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                  'songs': songs,
                  'type': 'folder',
                };
              }).toList(),
              itemType: 'folder',
            ),
          ),
        );
        break;
      case 'favorites':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FavoritesScreen(),
          ),
        );
        break;
      case 'playlists':
        _showPlaylistsList();
        break;
      case 'recent':
        final recentSongs = _localSongs.length > 20
            ? _localSongs.sublist(0, 20)
            : _localSongs;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FolderSongsScreen(
              folderName: 'Recently Added',
              songs: recentSongs,
              folderType: 'Recent',
            ),
          ),
        );
        break;
      default:
        _showComingSoonDialog();
        break;
    }
  }

  void _showPlaylistsList() {
    final theme = Theme.of(context);

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
              'My Playlists',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _userPlaylists.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_play, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No playlists yet',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a playlist from the "More" menu',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _userPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = _userPlaylists[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.playlist_play, color: theme.colorScheme.primary),
                      ),
                      title: Text(playlist['name']),
                      subtitle: Text('${playlist['songs'].length} songs'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _userPlaylists.removeAt(index);
                            _buildCategories();
                          });
                          Navigator.pop(context);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderSongsScreen(
                              folderName: playlist['name'],
                              songs: playlist['songs'],
                              folderType: 'Playlist',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showCreatePlaylistDialog(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Create New Playlist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text('This feature is under development.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkAndRequestManageStoragePermission() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = deviceInfo.version.sdkInt;

    debugPrint('Android SDK version: $sdkInt');

    if (sdkInt >= 30) {
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      final status = await Permission.manageExternalStorage.request();

      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text('Storage permission is permanently denied. Please enable it in app settings.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return false;
      }
      return false;
    } else {
      if (await Permission.storage.isGranted) {
        return true;
      }
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<void> _deleteSongPermanently(BuildContext dialogContext, Song song, AudioPlayerHandler audioHandler) async {
    if (Navigator.canPop(dialogContext)) {
      Navigator.pop(dialogContext);
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      bool deleted = false;
      String message = '';

      if (song.isLocal && song.audioPath != null && song.audioPath!.isNotEmpty) {
        final hasPermission = await _checkAndRequestManageStoragePermission();

        if (!hasPermission) {
          setState(() {
            _isDeleting = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission required to delete files'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        String cleanPath = song.audioPath!;
        if (cleanPath.startsWith('file://')) {
          cleanPath = cleanPath.replaceFirst('file://', '');
        }

        final file = File(cleanPath);

        if (await file.exists()) {
          try {
            await file.delete();
            deleted = true;
            message = '${song.title} permanently deleted from device';
          } catch (e) {
            if (e is PathNotFoundException) {
              deleted = true;
              message = '${song.title} removed (file already deleted)';
            } else {
              message = 'Error deleting file: $e';
            }
          }
        } else {
          deleted = true;
          message = '${song.title} removed (file not found)';
        }
      } else {
        message = '${song.title} removed from library';
        deleted = true;
      }

      setState(() {
        _localSongs.removeWhere((s) => s.id == song.id);
        _buildCategories();
      });

      // Remove from favorites service
      final favoritesService = Provider.of<FavoritesService>(context, listen: false);
      favoritesService.removeFavorite(song.id);

      audioHandler.removeSong(song);

      _organizeSongsIntoFolders();
      _updateCategoryStats();

      setState(() {
        _isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: deleted ? Colors.green : Colors.orange,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Song song, AudioPlayerHandler audioHandler) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Song'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${song.title}"?'),
            if (song.isLocal) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will permanently delete the file from your device',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deleteSongPermanently(dialogContext, song, audioHandler),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context, Song song) {
    final theme = Theme.of(context);
    final favoritesService = Provider.of<FavoritesService>(context, listen: false);

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
              leading: const Icon(Icons.favorite, color: Colors.red),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pop(context);
                favoritesService.toggleFavorite(song);
                _showSnackBar('Added to Favorites');
              },
            ),
            ..._userPlaylists.map((playlist) => ListTile(
              leading: Icon(Icons.playlist_play, color: theme.colorScheme.primary),
              title: Text(playlist['name']),
              subtitle: Text('${playlist['songs'].length} songs'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  playlist['songs'].add(song);
                });
                _showSnackBar('Added to "${playlist['name']}"');
              },
            )),
            const Divider(height: 30),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.green),
              title: const Text('Create New Playlist'),
              onTap: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(context, song);
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

  void _showCreatePlaylistDialog(BuildContext context, Song? song) {
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
                setState(() {
                  _userPlaylists.add({
                    'name': controller.text,
                    'songs': song != null ? [song] : [],
                  });
                  _buildCategories();
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

  void _addToPlaylist(Song song, String playlistName) {
    _showSnackBar('Added to "$playlistName"');
  }

  Future<void> _shareSong(BuildContext context, Song song) async {
    try {
      if (song.audioPath == null || song.audioPath!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No audio file available to share'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String filePath = song.audioPath!;

      if (filePath.startsWith('file://')) {
        filePath = filePath.replaceFirst('file://', '');
      }

      debugPrint('Attempting to share file: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio file not found on device'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Check out this song: ${song.title} by ${song.artist ?? "Unknown"}',
        subject: 'Song: ${song.title}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sharing ${song.title}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );

    } catch (e) {
      debugPrint('Error sharing file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing song'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSongInfo(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(song.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Artist', song.artist ?? 'Unknown'),
              _buildInfoRow('Album', song.album ?? 'Unknown'),
              if (song.duration != null)
                _buildInfoRow('Duration', _formatDuration(song.duration!)),
              if (song.audioPath != null)
                _buildInfoRow('Path', song.audioPath!),
              _buildInfoRow('Type', song.isLocal ? 'Local File' : 'Online'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<bool> _onWillPop() async {
    if (_tabController.index == 0) {
      if (_allSongsScrollController.hasClients) {
        if (_allSongsScrollController.offset > 0) {
          _allSongsScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          return false;
        }
      }
    } else if (_tabController.index == 1) {
      if (_localMusicScrollController.hasClients) {
        if (_localMusicScrollController.offset > 0) {
          _localMusicScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        drawer: const AppDrawer(),
        body: Stack(
          children: [
            Column(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(theme),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'All Songs'),
                          Tab(text: 'Categories'),
                        ],
                        labelColor: theme.colorScheme.primary,
                        unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.5),
                        indicatorColor: theme.colorScheme.primary,
                        indicatorWeight: 3,
                        labelStyle: theme.textTheme.labelLarge,
                        unselectedLabelStyle: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllSongs(theme),
                      _buildLocalMusicView(theme),
                    ],
                  ),
                ),
                const SafeArea(
                  child: MusicPlayerBar(),
                ),
              ],
            ),
            if (_isDeleting)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Deleting...',
                        style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      color: theme.colorScheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, size: 28, color: theme.colorScheme.primary),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              if (!_isSearching)
                Text(
                  'Music Player',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary, size: 22),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear, color: theme.colorScheme.primary, size: 22),
                        onPressed: _stopSearch,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                    autofocus: true,
                  ),
                ),
              if (!_isSearching)
                IconButton(
                  icon: Icon(Icons.search, size: 24, color: theme.colorScheme.primary),
                  onPressed: _startSearch,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (!_isSearching && _localSongs.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$_totalSongs ${_totalSongs == 1 ? 'song' : 'songs'} • $_artistCount ${_artistCount == 1 ? 'artist' : 'artists'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllSongs(ThemeData theme) {
    return Consumer<AudioPlayerHandler>(
      builder: (context, audioHandler, child) {
        final displaySongs = _filterSongs(audioHandler.playlist, _searchQuery);

        if (displaySongs.isEmpty && _searchQuery.isNotEmpty) {
          return _buildEmptySearchResult(theme);
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.background,
          child: ListView.separated(
            controller: _allSongsScrollController,
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            itemCount: displaySongs.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 72,
              color: theme.dividerColor,
            ),
            itemBuilder: (context, index) {
              final song = displaySongs[index];
              return SongTile(
                song: song,
                onTap: () {
                  audioHandler.playSong(song);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NowPlayingScreen(),
                    ),
                  );
                },
                onDelete: () => _showDeleteConfirmation(context, song, audioHandler),
                onAddToPlaylist: () => _showAddToPlaylist(context, song),
                onShare: () => _shareSong(context, song),
                onSongInfo: () => _showSongInfo(context, song),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLocalMusicView(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      );
    }

    if (!_hasPermission) {
      return _buildPermissionRequired(theme);
    }

    if (_localSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 60, color: theme.colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'No local songs found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    final filteredCategories = _getFilteredCategories();

    if (filteredCategories.isEmpty && _searchQuery.isNotEmpty) {
      return _buildEmptySearchResult(theme);
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.background,
      child: SingleChildScrollView(
        controller: _localMusicScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: FutureBuilder(
          future: Future.delayed(Duration.zero),
          builder: (context, snapshot) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: filteredCategories.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final category = filteredCategories[index];
                return CategoryCard(
                  title: category['title'],
                  icon: category['icon'],
                  color: category['color'],
                  count: category['count'],
                  subtitle: category['subtitle'],
                  onTap: () => _navigateToCategory(category['type']),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptySearchResult(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: theme.colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'No categories found for "$_searchQuery"',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequired(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 60, color: theme.colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Permission Required',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Allow access to your music files',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Grant Permission'),
            )
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}