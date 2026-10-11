import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  int tab = 0;
  bool searching = false;
  bool loading = false;
  final ctrl = TextEditingController();
  List<Video> videos = [];

  @override
  void initState() {
    super.initState();
    load('trending');
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

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: searching
              ? TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Search YouTube', border: InputBorder.none),
                  onSubmitted: (q) => load(q),
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
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : videos.isEmpty
                ? const Center(child: Text('No videos. Check internet.'))
                : ListView.builder(
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
                              placeholder: (c, u) => Container(color: Colors.grey[850]),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.explore), label: 'Shorts'),
            NavigationDestination(icon: Icon(Icons.subscriptions), label: 'Subscriptions'),
            NavigationDestination(icon: Icon(Icons.video_library), label: 'You'),
          ],
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
  late final controller = VideoController(player);
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
      // 360p+ is smooth on low-end phones
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
            AspectRatio(aspectRatio: 16 / 9, child: Video(controller: controller)),
            if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
            ListTile(
              title: Text(widget.v.title),
              subtitle: Text('${widget.v.author} • ${widget.v.engagement.viewCount} views'),
            ),
          ]),
        ),
      );
}
