import 'package:flutter/material.dart';
import 'package:music_player/services/theme_service.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Music Player',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customize your experience',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Theme Colors Section
                _buildSectionTitle(theme, 'Theme Colors'),
                const SizedBox(height: 8),
                _buildColorOptions(context, theme, themeService),

                const Divider(height: 32),

                // Icon Styles Section
                _buildSectionTitle(theme, 'Icon Styles'),
                const SizedBox(height: 8),
                _buildIconStyleOptions(context, theme, themeService),

                const Divider(height: 32),

                // Other Settings
                _buildSectionTitle(theme, 'Other Settings'),
                ListTile(
                  leading: Icon(Icons.library_music, color: theme.colorScheme.primary),
                  title: const Text('Library'),
                  subtitle: const Text('Manage your music library'),
                  onTap: () {
                    // Navigate to library settings
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.playlist_play, color: theme.colorScheme.primary),
                  title: const Text('Playlists'),
                  subtitle: const Text('Manage your playlists'),
                  onTap: () {
                    // Navigate to playlist settings
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: theme.colorScheme.primary),
                  title: const Text('Settings'),
                  subtitle: const Text('App preferences'),
                  onTap: () {
                    // Navigate to general settings
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Text(
              'Version 1.0.0',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildColorOptions(BuildContext context, ThemeData theme, ThemeService themeService) {
    final colors = [
      {'color': Colors.deepPurple, 'name': 'Purple'},
      {'color': Colors.blue, 'name': 'Blue'},
      {'color': Colors.green, 'name': 'Green'},
      {'color': Colors.red, 'name': 'Red'},
      {'color': Colors.orange, 'name': 'Orange'},
      {'color': Colors.pink, 'name': 'Pink'},
      {'color': Colors.teal, 'name': 'Teal'},
      {'color': Colors.indigo, 'name': 'Indigo'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: colors.map((colorItem) {
          final isSelected = themeService.accentColor == colorItem['color'];
          return InkWell(
            onTap: () async {
              await themeService.setThemeColor(colorItem['color'] as Color);
              if (context.mounted) {
                Navigator.pop(context); // Close drawer
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Theme changed to ${colorItem['name']}'),
                    backgroundColor: theme.colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: colorItem['color'] as Color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: (colorItem['color'] as Color).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIconStyleOptions(BuildContext context, ThemeData theme, ThemeService themeService) {
    final styles = [
      {'style': 'modern', 'icon': Icons.play_circle_filled, 'name': 'Modern', 'desc': 'Filled circle icons'},
      {'style': 'classic', 'icon': Icons.play_arrow, 'name': 'Classic', 'desc': 'Simple outlined icons'},
      {'style': 'vibrant', 'icon': Icons.play_circle, 'name': 'Vibrant', 'desc': 'Bold with shadows'},
      {'style': 'minimal', 'icon': Icons.play_arrow_outlined, 'name': 'Minimal', 'desc': 'Simple outlined'},
    ];

    return Column(
      children: styles.map((style) {
        final isSelected = themeService.themeStyle == style['style'];
        return ListTile(
          leading: Icon(
            style['icon'] as IconData,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
          title: Text(
            style['name'] as String,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(style['desc'] as String),
          trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
          onTap: () async {
            await themeService.setThemeStyle(style['style'] as String);
            if (context.mounted) {
              Navigator.pop(context); // Close drawer
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Icon style changed to ${style['name']}'),
                  backgroundColor: theme.colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      }).toList(),
    );
  }
}