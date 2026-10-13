import 'dart:ui';
import 'package:flutter/cupertino.dart';

// Put this file in lib/ios_shell.dart, then in main.dart use:
//   runApp(const IosApp());
// Replace the placeholder pages with your real Home/Search/Trending/Library screens.

class IosApp extends StatelessWidget {
  const IosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF000000),
        primaryColor: Color(0xFFFF0000), // YouTube red
        barBackgroundColor: Color(0xFF000000),
      ),
      home: IosShell(),
    );
  }
}

class IosShell extends StatefulWidget {
  const IosShell({super.key});

  @override
  State<IosShell> createState() => _IosShellState();
}

class _IosShellState extends State<IosShell> {
  int _tab = 0;

  // TODO: swap these for your real screens.
  final _pages = const [
    _Placeholder('Home'),
    _Placeholder('Search'),
    _Placeholder('Trending'),
    _Placeholder('Library'),
  ];

  static const _items = [
    (CupertinoIcons.house_fill, 'Home'),
    (CupertinoIcons.search, 'Search'),
    (CupertinoIcons.flame_fill, 'Trending'),
    (CupertinoIcons.square_stack_fill, 'Library'),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          // IndexedStack keeps each tab alive (no reload = smoother, less network).
          Positioned.fill(child: IndexedStack(index: _tab, children: _pages)),
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: _FloatingBar(
              index: _tab,
              items: _items,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingBar extends StatelessWidget {
  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onTap;
  const _FloatingBar(
      {required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xCC1C1C1E),
            border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].$1,
                          size: 24,
                          color: i == index
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF8E8E93)),
                      const SizedBox(height: 2),
                      Text(items[i].$2,
                          style: TextStyle(
                              fontSize: 10,
                              color: i == index
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF8E8E93))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(title),
          backgroundColor: const Color(0xFF000000),
          border: null,
        ),
        const SliverFillRemaining(
          child: Center(child: Text('Coming soon')),
        ),
      ],
    );
  }
}
