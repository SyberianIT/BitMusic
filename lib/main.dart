import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/database_service.dart';
import 'services/deezer_service.dart';
import 'services/download_service.dart';
import 'services/eq_service.dart';
import 'services/player_service.dart';
import 'services/recognition_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();

  final dbService = DatabaseService();
  await dbService.open();

  final eqService = EqService();
  await eqService.loadSaved();

  final recognitionService = RecognitionService();
  await recognitionService.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeezerService()),
        ChangeNotifierProvider(create: (_) => DownloadService()),
        ChangeNotifierProvider.value(value: eqService),
        ChangeNotifierProvider(create: (_) => PlayerService(eqService)),
        ChangeNotifierProvider.value(value: dbService),
        ChangeNotifierProvider.value(value: recognitionService),
      ],
      child: const BitMusicApp(),
    ),
  );
}
