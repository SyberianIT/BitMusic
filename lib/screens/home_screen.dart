import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../services/player_service.dart';
import '../widgets/mini_player.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DatabaseService>().open();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final player = context.watch<PlayerService>();

    final screens = const [SearchScreen(), LibraryScreen()];

    Widget body = IndexedStack(
      index: _selectedIndex,
      children: screens,
    );

    if (isWide) {
      body = Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF0D0D1A),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: const _RailHeader(),
            selectedIconTheme: const IconThemeData(color: Color(0xFF7C4DFF)),
            selectedLabelTextStyle:
                const TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: Text('Поиск'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: Text('Музыка'),
              ),
            ],
          ),
          VerticalDivider(width: 1, color: Colors.white.withValues(alpha: 0.06)),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: body),
          if (player.currentTrack != null) const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              backgroundColor: const Color(0xFF0D0D1A),
              indicatorColor: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search, color: Color(0xFF7C4DFF)),
                  label: 'Поиск',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon:
                      Icon(Icons.library_music, color: Color(0xFF7C4DFF)),
                  label: 'Моя музыка',
                ),
              ],
            ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          const Text(
            'BitMusic',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
