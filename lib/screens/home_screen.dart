import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../widgets/mini_player.dart';
import 'library_screen.dart';
import 'recognition_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 0 = Search, 1 = Library  (nav index 1 is the Shazam button — modal, not a tab)
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  // Nav bar has 3 items: Search | [Mic] | Library
  // Items 0 and 2 map to screen 0 and 1. Item 1 opens modal.
  int get _navIndex => _selectedIndex == 0 ? 0 : 2;

  void _onNavTap(int navIdx) {
    if (navIdx == 1) {
      // Shazam-style modal
      Navigator.of(context).push(RecognitionScreen.route());
      return;
    }
    setState(() => _selectedIndex = navIdx == 0 ? 0 : 1);
  }

  // Nav bar has 3 items: Search | [Mic] | Library
  // Items 0 and 2 map to screen 0 and 1. Item 1 opens modal.
  int get _navIndex => _selectedIndex == 0 ? 0 : 2;

  void _onNavTap(int navIdx) {
    if (navIdx == 1) {
      // Shazam-style modal
      Navigator.of(context).push(RecognitionScreen.route());
      return;
    }
    setState(() => _selectedIndex = navIdx == 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final player = context.watch<PlayerService>();

    Widget body = IndexedStack(
      index: _selectedIndex,
      children: const [SearchScreen(), LibraryScreen()],
    );

    if (isWide) {
      body = Row(
        children: [
          _WideRail(
            selectedIndex: _selectedIndex,
            onSearch: () => setState(() => _selectedIndex = 0),
            onLibrary: () => setState(() => _selectedIndex = 1),
            onShazam: () => Navigator.of(context).push(RecognitionScreen.route()),
          ),
          VerticalDivider(
              width: 1,
              color: Colors.white.withValues(alpha: 0.06)),
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
      bottomNavigationBar: isWide ? null : _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return NavigationBar(
      backgroundColor: const Color(0xFF0D0D1A),
      indicatorColor: Colors.transparent,
      selectedIndex: _navIndex,
      onDestinationSelected: _onNavTap,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search, color: Color(0xFF7C4DFF)),
          label: 'Поиск',
        ),
        NavigationDestination(
          icon: _ShazamButton(mini: true),
          label: 'Распознать',
        ),
        const NavigationDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music, color: Color(0xFF7C4DFF)),
          label: 'Музыка',
        ),
      ],
    );
  }
}

// ─── Wide rail ────────────────────────────────────────────────────────────────

class _WideRail extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onShazam;

  const _WideRail({
    required this.selectedIndex,
    required this.onSearch,
    required this.onLibrary,
    required this.onShazam,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          const SizedBox(height: 52),
          // Logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)]),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                  blurRadius: 14,
                )
              ],
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 32),
          _RailItem(
            icon: Icons.search_outlined,
            activeIcon: Icons.search,
            label: 'Поиск',
            selected: selectedIndex == 0,
            onTap: onSearch,
          ),
          const SizedBox(height: 8),
          _RailItem(
            icon: Icons.library_music_outlined,
            activeIcon: Icons.library_music,
            label: 'Музыка',
            selected: selectedIndex == 1,
            onTap: onLibrary,
          ),
          const Spacer(),
          // Shazam button at bottom of rail
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: GestureDetector(
              onTap: onShazam,
              child: _ShazamButton(mini: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(selected ? activeIcon : icon,
                color: selected ? const Color(0xFF7C4DFF) : Colors.white38,
                size: 26),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: selected ? const Color(0xFF7C4DFF) : Colors.white24,
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─── Shazam-style mic button ──────────────────────────────────────────────────

class _ShazamButton extends StatelessWidget {
  final bool mini;
  const _ShazamButton({required this.mini});

  @override
  Widget build(BuildContext context) {
    final size = mini ? 36.0 : 48.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9966FF), Color(0xFF7C4DFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.55),
            blurRadius: mini ? 10 : 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.mic_rounded, color: Colors.white, size: mini ? 18 : 24),
    );
  }
}
