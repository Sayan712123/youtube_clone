import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

final yt = YoutubeExplode();
late SharedPreferences prefs;

// One shared player: keeps playing when you leave the video page.
final player = Player();
final videoController = mkv.VideoController(player);
final ValueNotifier<Video?> nowPlaying = ValueNotifier(null);
final ValueNotifier<int?> nowHeight = ValueNotifier(null);
final ValueNotifier<bool> pipMode = ValueNotifier(false);
const pipChannel = MethodChannel('pip');
int watchCount = 0;

Future<void> pip(String m, [dynamic a]) async {
  try {
    await pipChannel.invokeMethod(m, a);
  } catch (_) {}
}

final Map<String, Future<StreamManifest>> manifests = {};
Future<StreamManifest> manifestFor(VideoId id) => manifests.putIfAbsent(
    id.value, () => yt.videos.streamsClient.getManifest(id));
void prefetch(Video v) {
  manifestFor(v.id).then((_) {}, onError: (_) {
    manifests.remove(v.id.value);
  });
}

List<Map<String, dynamic>> getHistory() => (prefs.getStringList('history') ?? [])
    .map((e) => jsonDecode(e) as Map<String, dynamic>)
    .toList();

void addHistory(Video v) {
  final list = (prefs.getStringList('history') ?? [])
      .where((e) => (jsonDecode(e) as Map)['id'] != v.id.value)
      .toList();
  list.insert(
      0,
      jsonEncode({
        'id': v.id.value,
        't': v.title,
        'a': v.author,
        'th': v.thumbnails.mediumResUrl,
      }));
  if (list.length > 200) list.removeRange(200, list.length);
  prefs.setStringList('history', list);
}

List<String> getRecent() => prefs.getStringList('recent') ?? [];
void addRecent(String q) {
  final l = getRecent()..remove(q);
  l.insert(0, q);
  if (l.length > 20) l.removeRange(20, l.length);
  prefs.setStringList('recent', l);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  pipChannel.setMethodCallHandler((call) async {
    if (call.method == 'pipChanged') {
      pipMode.value = call.arguments == true;
    }
  });
  runApp(const App());
}

String fmt(Duration? d) {
  if (d == null) return 'LIVE';
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
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

class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 30,
          height: 21,
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 6),
        const Text('YouTube',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5)),
      ]);
}

class VideoCard extends StatelessWidget {
  final Video v;
  final bool replace;
  const VideoCard({super.key, required this.v, this.replace = false});
  @override
  Widget build(BuildContext c) => InkWell(
        onTapDown: (_) => prefetch(v),
        onTap: () {
          final r = MaterialPageRoute(builder: (_) => Watch(v: v));
          if (replace) {
            Navigator.pushReplacement(c, r);
          } else {
            Navigator.push(c, r);
          }
        },
        child: Column(children: [
          Stack(children: [
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
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                child: Text(fmt(v.duration),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${v.author} • ${v.engagement.viewCount} views'),
            trailing: const Icon(Icons.more_vert),
          ),
        ]),
      );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<Video?>(
        valueListenable: nowPlaying,
        builder: (c, v, _) {
          if (v == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                    c, MaterialPageRoute(builder: (_) => Watch(v: v))),
                child: Row(children: [
                  SizedBox(
                    width: 90,
                    height: 56,
                    child: CachedNetworkImage(
                      imageUrl: v.thumbnails.mediumResUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(v.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  StreamBuilder<bool>(
                    stream: player.stream.playing,
                    initialData: player.state.playing,
                    builder: (c, s) => IconButton(
                      icon: Icon((s.data ?? false) ? Icons.pause : Icons.play_arrow),
                      onPressed: () => player.playOrPause(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      player.stop();
                      nowPlaying.value = null;
                      nowHeight.value = null;
                    },
                  ),
                ]),
              ),
            ),
          );
        },
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  bool loading = false;
  List<Video> videos = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      videos = (await yt.search.search('trending today')).toList();
      for (final v in videos.take(3)) {
        prefetch(v);
      }
    } catch (e) {
      videos = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Widget feed() => loading
      ? const Center(child: CircularProgressIndicator())
      : videos.isEmpty
          ? const Center(child: Text('No videos. Check internet.'))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 160),
                itemCount: videos.length,
                itemBuilder: (c, n) => VideoCard(v: videos[n]),
              ),
            );

  Widget bodyFor() {
    switch (tab) {
      case 0:
        return feed();
      case 1:
        return const Center(child: Text('Shorts coming soon'));
      case 2:
        return const SubsTab();
      default:
        return const LibraryTab();
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Logo(),
          actions: [
            IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SearchPage())),
            ),
            IconButton(icon: const Icon(Icons.account_circle_outlined), onPressed: () {}),
          ],
        ),
        body: bodyFor(),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          const MiniPlayer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                height: 68,
                backgroundColor: const Color(0xFF1C1C1E),
                indicatorColor: Colors.white24,
                selectedIndex: tab,
                onDestinationSelected: (i) => setState(() => tab = i),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.slow_motion_video), label: 'Shorts'),
                  NavigationDestination(icon: Icon(Icons.subscriptions_outlined), selectedIcon: Icon(Icons.subscriptions), label: 'Subscriptions'),
                  NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Library'),
                ],
              ),
            ),
          ),
        ]),
      );
}

class SubsTab extends StatelessWidget {
  const SubsTab({super.key});
  @override
  Widget build(BuildContext c) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.subscriptions_outlined, size: 80, color: Colors.white54),
          const SizedBox(height: 12),
          const Text("Don't miss new videos",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Sign in to see updates from your favorite channels'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sign in'),
          ),
        ]),
      );
}

class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});
  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 160),
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
          const ListTile(leading: Icon(Icons.watch_later_outlined), title: Text('Watch later'), trailing: Icon(Icons.chevron_right)),
          const ListTile(leading: Icon(Icons.thumb_up_outlined), title: Text('Liked videos'), trailing: Icon(Icons.chevron_right)),
          const ListTile(leading: Icon(Icons.playlist_play), title: Text('Playlist'), trailing: Icon(Icons.chevron_right)),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext c) {
    final items = getHistory();
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              prefs.remove('history');
              setState(() {});
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No history yet'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) {
                final m = items[i];
                return ListTile(
                  leading: SizedBox(
                    width: 110,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: m['th'] as String,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                      ),
                    ),
                  ),
                  title: Text(m['t'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(m['a'] as String),
                  onTap: () async {
                    try {
                      final v = await yt.videos.get(VideoId(m['id'] as String));
                      if (!mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => Watch(v: v)));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Cannot open video')));
                    }
                  },
                );
              },
            ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void note(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext c) {
    final current = prefs.getInt('quality') ?? 360;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        const ListTile(
          title: Text('Default video quality',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Uses the nearest quality available for each video'),
        ),
        for (final q in [144, 240, 360, 480, 720])
          ListTile(
            title: Text('${q}p'),
            subtitle: q == 360 ? const Text('Recommended for low-end phones') : null,
            trailing: current == q ? const Icon(Icons.check, color: Colors.red) : null,
            onTap: () {
              prefs.setInt('quality', q);
              setState(() {});
            },
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Clear watch history'),
          onTap: () {
            prefs.remove('history');
            note('Watch history cleared');
          },
        ),
        ListTile(
          leading: const Icon(Icons.search_off),
          title: const Text('Clear search history'),
          onTap: () {
            prefs.remove('recent');
            note('Search history cleared');
          },
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Clear image cache'),
          onTap: () async {
            await DefaultCacheManager().emptyCache();
            note('Image cache cleared');
          },
        ),
      ]),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ctrl = TextEditingController();
  final stt = SpeechToText();
  bool listening = false;
  bool loading = false;
  List<Video>? results;

  Future<void> submit(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    addRecent(q);
    ctrl.text = q;
    setState(() => loading = true);
    try {
      results = (await yt.search.search(q)).toList();
    } catch (e) {
      results = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> voice() async {
    if (listening) {
      await stt.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final ok = await stt.initialize(onStatus: (s) {
      if ((s == 'done' || s == 'notListening') && mounted) {
        setState(() => listening = false);
      }
    });
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice search not available. Allow the microphone.')));
      }
      return;
    }
    setState(() => listening = true);
    await stt.listen(onResult: (r) {
      ctrl.text = r.recognizedWords;
      if (r.finalResult) {
        setState(() => listening = false);
        submit(r.recognizedWords);
      }
    });
  }

  @override
  void dispose() {
    stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Search YouTube', border: InputBorder.none),
            onSubmitted: submit,
          ),
          actions: [
            IconButton(
              icon: Icon(listening ? Icons.mic : Icons.mic_none, color: listening ? Colors.red : null),
              onPressed: voice,
            ),
            IconButton(icon: const Icon(Icons.tune), onPressed: () {}),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : results != null
                ? ListView.builder(
                    itemCount: results!.length,
                    itemBuilder: (c, n) => VideoCard(v: results![n]),
                  )
                : ListView(
                    children: [
                      for (final q in getRecent())
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(q),
                          trailing: const Icon(Icons.north_west, size: 18),
                          onTap: () => submit(q),
                        ),
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
  List<MuxedStreamInfo> streams = [];
  int? height;
  bool loadingInfo = true;
  bool buffering = false;
  String? error;
  List<Video> related = [];
  bool loadingRelated = true;
  StreamSubscription? bufSub;
  StreamSubscription? playSub;

  @override
  void initState() {
    super.initState();
    watchCount++;
    bufSub = player.stream.buffering.listen((b) {
      if (mounted) setState(() => buffering = b);
    });
    playSub = player.stream.playing.listen((p) => pip('auto', p));
    pip('auto', player.state.playing);
    start();
    loadRelated();
  }

  MuxedStreamInfo pick(int target) {
    final l = [...streams]
      ..sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
    final ok = l.where((s) => s.videoResolution.height <= target).toList();
    return ok.isEmpty ? l.first : ok.last;
  }

  Future<void> start() async {
    final same = nowPlaying.value?.id == widget.v.id;
    try {
      final m = await manifestFor(widget.v.id);
      streams = m.muxed.toList();
      if (streams.isEmpty) throw 'No playable stream';
      if (same && nowHeight.value != null) {
        height = nowHeight.value;
      } else {
        final s = pick(prefs.getInt('quality') ?? 360);
        height = s.videoResolution.height;
        nowHeight.value = height;
        nowPlaying.value = widget.v;
        addHistory(widget.v);
        await player.open(Media(s.url.toString()));
      }
    } catch (e) {
      manifests.remove(widget.v.id.value);
      if (mounted) setState(() => error = 'Cannot play: $e');
    }
    if (mounted) setState(() => loadingInfo = false);
  }

  Future<void> changeQuality(MuxedStreamInfo s) async {
    final pos = player.state.position;
    setState(() {
      height = s.videoResolution.height;
      loadingInfo = true;
    });
    nowHeight.value = height;
    await player.open(Media(s.url.toString(), start: pos));
    if (mounted) setState(() => loadingInfo = false);
  }

  void showQuality() {
    final l = [...streams]
      ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(
            title: Text('Video quality', style: TextStyle(fontWeight: FontWeight.bold))),
        for (final s in l)
          ListTile(
            title: Text('${s.videoResolution.height}p'),
            trailing: s.videoResolution.height == height ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.pop(context);
              changeQuality(s);
            },
          ),
      ]),
    );
  }

  Future<void> loadRelated() async {
    try {
      var r = (await yt.videos.getRelatedVideos(widget.v))?.toList() ?? [];
      if (r.isEmpty) r = (await yt.search.search(widget.v.title)).toList();
      related = r.where((x) => x.id != widget.v.id).toList();
    } catch (e) {
      related = [];
    }
    if (mounted) setState(() => loadingRelated = false);
  }

  @override
  void dispose() {
    bufSub?.cancel();
    playSub?.cancel();
    watchCount--;
    if (watchCount <= 0) pip('auto', false);
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<bool>(
        valueListenable: pipMode,
        builder: (c, inPip, _) {
          if (inPip) {
            return Scaffold(body: mkv.Video(controller: videoController));
          }
          return Scaffold(
            body: SafeArea(
              child: Column(children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    mkv.Video(controller: videoController),
                    if (loadingInfo)
                      CachedNetworkImage(
                        imageUrl: widget.v.thumbnails.mediumResUrl,
                        fit: BoxFit.cover,
                      ),
                    if (loadingInfo || buffering)
                      const Center(child: CircularProgressIndicator()),
                  ]),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(child: Text(error!)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            error = null;
                            loadingInfo = true;
                          });
                          start();
                        },
                        child: const Text('Retry'),
                      ),
                    ]),
                  ),
                ListTile(
                  title: Text(widget.v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${widget.v.author} • ${widget.v.engagement.viewCount} views'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt),
                      onPressed: () => pip('enter'),
                    ),
                    if (streams.isNotEmpty)
                      TextButton.icon(
                        onPressed: showQuality,
                        icon: const Icon(Icons.settings, size: 18),
                        label: Text('${height ?? ''}p'),
                      ),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: loadingRelated
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: related.length,
                          itemBuilder: (c, n) => VideoCard(v: related[n], replace: true),
                        ),
                ),
              ]),
            ),
          );
        },
      );
}
