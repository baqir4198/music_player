import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:music_player/models/song.dart';
import 'package:music_player/screens/home_screen.dart';
import 'package:music_player/services/audio_player_handler.dart';
import 'package:music_player/services/favorites_service.dart';
import 'package:music_player/services/theme_service.dart';
import 'package:music_player/theme/app_theme.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up audio session
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // Initialize audio service with notification color
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music_player.channel',
      androidNotificationChannelName: 'Music Player',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      notificationColor: const Color(0xFF9C27B0),
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidNotificationClickStartsActivity: true,
    ),
  );

  runApp(MyApp(audioHandler: audioHandler));
}

class MyApp extends StatelessWidget {
  final AudioPlayerHandler audioHandler;

  const MyApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AudioPlayerHandler>.value(value: audioHandler),
        ChangeNotifierProvider(create: (context) => ThemeService()),
        ChangeNotifierProvider(create: (context) => FavoritesService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Music Player',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getLightTheme(themeService.accentColor),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}