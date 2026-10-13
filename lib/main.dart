import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final yt = YoutubeExplode();
const kBlack = Color(0xFF000000);
const kGrey = Color(0xFF8E8E93);
const kWhite = Color(0xFFFFFFFF);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const CupertinoApp(
    debugShowCheckedModeBanner: false,
    theme: CupertinoThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBlack,
      primaryColor: Color(0xFFFF0000),
    ),
    home: Shell(),
  ));
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  static const icons = [
    (CupertinoIcons.house_fill, 'Home'),
    (CupertinoIcons.search, 'Search'),
    (CupertinoIcons.flame_fill, 'Trending'),
    (CupertinoIcons.square_stack_fill, 'Library'),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(children: [
        Positioned.fill(
          child: IndexedStack(index: tab, children: const [
            FeedPage('Home', 'popular videos today'),
            SearchPage(),
            FeedPage('Trending', 'trending now'),
            LibraryPage(),
          ]),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          child: ClipRRect(
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
                    for (var i = 0; i < icons.length; i++)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => tab = i),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icons[i].$1, size: 24, color: i == tab ? kWhite : kGrey),
                          Text(icons[i].$2,
                              style: TextStyle(fontSize: 10, color: i == tab ? kWhite : kGrey)),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

Future<List<Video>> searchVideos(String q) async =>
    (await yt.search.search(q)).toList();

class FeedPage extends StatefulWidget {
  final String title, query;
  const FeedPage(this.title, this.query, {super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late Future<List<Video>> f = searchVideos(widget.query);

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      CupertinoSliverNavigationBar(
          largeTitle: Text(widget.title), backgroundColor: kBlack, border: null),
      CupertinoSliverRefreshControl(onRefresh: () async {
        final n = searchVideos(widget.query);
        setState(() => f = n);
        await n;
      }),
      VideoSliver(f),
      const SliverToBoxAdapter(child: SizedBox(height: 110)),
    ]);
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Future<List<Video>>? f;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      const CupertinoSliverNavigationBar(
          largeTitle: Text('Search'), backgroundColor: kBlack, border: null),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CupertinoSearchTextField(onSubmitted: (q) {
            if (q.trim().isNotEmpty) setState(() => f = searchVideos(q));
          }),
        ),
      ),
      if (f != null) VideoSliver(f!),
      const SliverToBoxAdapter(child: SizedBox(height: 110)),
    ]);
  }
}

class VideoSliver extends StatelessWidget {
  final Future<List<Video>> future;
  const VideoSliver(this.future, {super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Video>>(
      future: future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CupertinoActivityIndicator())));
        }
        if (s.hasError || s.data == null) {
          return const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: Text('Could not load. Pull down to retry.',
                          style: TextStyle(color: kGrey)))));
        }
        final list = s.data!;
        return SliverList.builder(
            itemCount: list.length, itemBuilder: (_, i) => VideoTile(list[i]));
      },
    );
  }
}

String fmt(Duration? d) => d == null
    ? ''
    : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class VideoTile extends StatelessWidget {
  final Video v;
  const VideoTile(this.v, {super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.push(
          context, CupertinoPageRoute(builder: (_) => PlayerPage(v))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(v.thumbnails.mediumResUrl,
              fit: BoxFit.cover,
              cacheWidth: 480,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1C1C1E))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: kWhite, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${v.author} · ${fmt(v.duration)}',
                style: const TextStyle(color: kGrey, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class PlayerPage extends StatefulWidget {
  final Video v;
  const PlayerPage(this.v, {super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final player = Player();
  late final controller = mkv.VideoController(player);
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await yt.videos.streamsClient.getManifest(widget.v.id);
      final url = m.muxed.withHighestBitrate().url.toString();
      await player.open(Media(url));
    } catch (e) {
      if (mounted) setState(() => err = 'Could not play this video.');
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
          backgroundColor: kBlack, middle: Text(widget.v.title, maxLines: 1)),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: err != null
                ? Center(child: Text(err!, style: const TextStyle(color: kGrey)))
                : mkv.Video(controller: controller),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.v.title,
                  style: const TextStyle(
                      color: kWhite, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(widget.v.author, style: const TextStyle(color: kGrey)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      const CupertinoSliverNavigationBar(
          largeTitle: Text('Library'), backgroundColor: kBlack, border: null),
      const SliverFillRemaining(
          child: Center(
              child: Text('Google sign-in and saved videos: next step',
                  style: TextStyle(color: kGrey)))),
    ]);
  }
}
