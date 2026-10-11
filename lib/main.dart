import 'package:flutter/material.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.play_circle_fill, color: Colors.red, size: 30),
            SizedBox(width: 6),
            Text('YouTube', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
        ),
        body: ListView.builder(
          itemCount: 10,
          itemBuilder: (c, n) => Column(children: [
            AspectRatio(
                aspectRatio: 16 / 9, child: Container(color: Colors.grey[800])),
            const ListTile(
              leading: CircleAvatar(),
              title: Text('Video title'),
              subtitle: Text('Channel • 1M views'),
            ),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.explore), label: 'Shorts'),
            NavigationDestination(icon: Icon(Icons.subscriptions), label: 'Subscriptions'),
            NavigationDestination(icon: Icon(Icons.video_library), label: 'You'),
          ],
        ),
      );
}
