import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';

final yt = YoutubeExplode();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              surfaceTintColor: Colors.transparent),
        ),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  bool searching = false;
  bool loading = false;
  String chip = 'Trending';
  final ctrl = TextEditingController();
  List<Video> videos = [];
  static const chips = ['Trending', 'Music', 'Gaming', 'News', 'Live', 'Sports', 'Movies'];

  @override
  void initState() {
    super.initState();
    load('trending today');
  }

  Future<void> load(String q) async {
    setState(() => loading = true);
    try {
      videos = (await yt.search.search(q)).toList();
    } catch (e) {
      videos = [];
    }
    if (mounted) setState(() => loading = false);
  }

  void pick(String c) {
    setState(() => chip = c);
    load(c == 'Trending' ? 'trending today' : c);
  }

  void showCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (_) => const Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.video_call), title: Text('Create a Short')),
        ListTile(leading: Icon(Icons.upload), title: Text('Upload a video')),
        ListTile(leading: Icon(Icons.sensors), title: Text('Go live')),
      ]),
    );
  }

  Widget feed() => Column(children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (c, i) => ChoiceChip(
              label: Text(chips[i]),
              selected: chip == chips[i],
              selectedColor: Colors.white,
              labelStyle: TextStyle(color: chip == chips[i] ? Colors.black : Colors.white),
              onSelected: (_) => pick(chips[i]),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : videos.isEmpty
                  ? const Center(child: Text('No videos. Check internet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: videos.length,
                      itemBuilder: (c, n) {
                        final v = videos[n];
                        return InkWell(
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => Watch(v: v))),
                          child: Column(children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: CachedNetworkImage(
                                imageUrl: v.thumbnails.mediumResUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                memCacheWidth: 480,
                                placeholder: (c, u) => Container(color: Colors.grey[900]),
                              ),
                            ),
                            ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${v.author} • ${v.engagement.viewCount} views'),
                            ),
                          ]),
                        );
                      },
                    ),
        ),
      ]);

  @override
  Widget build(BuildContext c) => Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: searching
              ? TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Search YouTube', border: InputBorder.none),
                  onSubmitted: (q) {
                    setState(() => chip = '');
                    load(q);
                  },
                )
              : const Row(children: [
                  Icon(Icons.play_circle_fill, color: Colors.red, size: 30),
                  SizedBox(width: 6),
                  Text('YouTube', style: TextStyle(fontWeight: FontWeight.bold)),
                ]),
          actions: [
            IconButton(
              icon: Icon(searching ? Icons.close : Icons.search),
              onPressed: () => setState(() => searching = !searching),
            ),
          ],
        ),
        body: tab == 0 ? feed() : const Center(child: Text('Coming soon')),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              height: 64,
              backgroundColor: const Color(0xFF1C1C1E),
              indicatorColor: Colors.white24,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              selectedIndex: tab,
              onDestinationSelected: (i) {
                if (i == 2) {
                  showCreate();
                } else {
                  setState(() => tab = i);
                }
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.explore), label: 'Shorts'),
                NavigationDestination(icon: Icon(Icons.add_circle_outline, size: 34), label: 'Create'),
                NavigationDestination(icon: Icon(Icons.subscriptions), label: 'Subscriptions'),
                NavigationDestination(icon: Icon(Icons.video_library), label: 'You'),
              ],
            ),
          ),
        ),
      );
}

class Watch extends StatefulWidget {
  final Video v;
  const Watch({super.key, required this.v});
  @override
  State<Watch> createState() => _WatchState();
}

class _WatchState extends State<Watch> {
  final player = Player();
  late final controller = mkv.VideoController(player);
  String? error;

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    try {
      final m = await yt.videos.streamsClient.getManifest(widget.v.id);
      final list = m.muxed.toList()
        ..sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
      final s = list.firstWhere((x) => x.videoResolution.height >= 360, orElse: () => list.last);
      await player.open(Media(s.url.toString()));
    } catch (e) {
      if (mounted) setState(() => error = 'Cannot play: $e');
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            AspectRatio(aspectRatio: 16 / 9, child: mkv.Video(controller: controller)),
            if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
            ListTile(
              title: Text(widget.v.title),
              subtitle: Text('${widget.v.author} • ${widget.v.engagement.viewCount} views'),
            ),
          ]),
        ),
      );
}
