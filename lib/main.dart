import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import 'models.dart';
import 'api_service.dart';
import 'player_screen.dart';

void main() {
  runApp(const SKVodsApp());
}

class SKVodsApp extends StatelessWidget {
  const SKVodsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SKVods',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF06060C),
        primaryColor: const Color(0xFF6366F1),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF0F0F1E),
          background: Color(0xFF06060C),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F1E),
          elevation: 0,
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF0F0F1E),
          elevation: 2,
        ),
        useMaterial3: true,
      ),
      home: const MainContainer(),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  // Global Lists shared across widgets
  List<Streamer> _streamers = [];
  List<Tag> _tags = [];
  List<LiveChannel> _liveChannels = [];
  bool _isLoadingMetaData = true;

  // Local persistence lists
  List<Video> _favorites = [];
  List<Video> _history = [];

  // Filter overrides for HomeScreen when navigate from other tabs
  String? _homeUserFilter;
  String? _homeTagFilter;
  String? _homeTitleFilter;

  @override
  void initState() {
    super.initState();
    _loadMetaData();
    _loadLocalData();
  }

  Future<void> _loadMetaData() async {
    try {
      final streamers = await ApiService.fetchStreamers();
      final tags = await ApiService.fetchTags();
      final liveChannels = await ApiService.fetchLiveChannels();

      if (mounted) {
        setState(() {
          _streamers = streamers;
          _tags = tags;
          _liveChannels = liveChannels;
          _isLoadingMetaData = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar dados iniciais: $e");
      if (mounted) {
        setState(() {
          _isLoadingMetaData = false;
        });
      }
    }
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final favsString = prefs.getString('skvods_favorites_list') ?? '[]';
    final histString = prefs.getString('skvods_history_list') ?? '[]';

    final List<dynamic> favsJson = json.decode(favsString);
    final List<dynamic> histJson = json.decode(histString);

    if (mounted) {
      setState(() {
        _favorites = favsJson.map((x) => Video.fromJson(x)).toList();
        _history = histJson.map((x) => Video.fromJson(x)).toList();
      });
    }
  }

  Future<void> _toggleFavorite(Video video) async {
    final prefs = await SharedPreferences.getInstance();
    final isFav = _favorites.any((v) => v.id == video.id);
    
    setState(() {
      if (isFav) {
        _favorites.removeWhere((v) => v.id == video.id);
      } else {
        _favorites.insert(0, video);
      }
    });

    await prefs.setString('skvods_favorites_list', json.encode(_favorites.map((v) => v.toJson()).toList()));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFav ? "Removido dos favoritos" : "Adicionado aos favoritos!"),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _addToHistory(Video video) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.removeWhere((v) => v.id == video.id);
      _history.insert(0, video);
      if (_history.length > 50) _history.removeLast();
    });

    await prefs.setString('skvods_history_list', json.encode(_history.map((v) => v.toJson()).toList()));
  }

  void _filterHomeByUser(String userId, String userName) {
    setState(() {
      _homeUserFilter = userId;
      _homeTagFilter = null;
      _homeTitleFilter = "Vídeos de $userName";
      _currentIndex = 0; // Go to Home tab
    });
  }

  void _filterHomeByTag(String slug, String tagName) {
    setState(() {
      _homeTagFilter = slug;
      _homeUserFilter = null;
      _homeTitleFilter = tagName;
      _currentIndex = 0; // Go to Home tab
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine which screen is shown
    Widget currentScreen;
    if (_isLoadingMetaData) {
      currentScreen = const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    } else {
      switch (_currentIndex) {
        case 0:
          currentScreen = HomeScreen(
            streamers: _streamers,
            liveChannels: _liveChannels,
            userFilter: _homeUserFilter,
            tagFilter: _homeTagFilter,
            titleFilter: _homeTitleFilter,
            onVideoTap: (video) {
              _addToHistory(video);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlayerScreen(video: video)),
              );
            },
            onClearFilters: () {
              setState(() {
                _homeUserFilter = null;
                _homeTagFilter = null;
                _homeTitleFilter = null;
              });
            },
          );
          break;
        case 1:
          currentScreen = LivesScreen(
            streamers: _streamers,
            onVideoTap: (video) {
              _addToHistory(video);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlayerScreen(video: video)),
              );
            },
          );
          break;
        case 2:
          currentScreen = SeriesScreen(
            tags: _tags,
            streamers: _streamers,
            onTagSelected: _filterHomeByTag,
          );
          break;
        case 3:
          currentScreen = ChannelsScreen(
            streamers: _streamers,
            onStreamerSelected: _filterHomeByUser,
          );
          break;
        case 4:
          currentScreen = LibraryScreen(
            favorites: _favorites,
            history: _history,
            onVideoTap: (video) {
              _addToHistory(video);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlayerScreen(video: video)),
              );
            },
            onToggleFavorite: _toggleFavorite,
          );
          break;
        default:
          currentScreen = const Center(child: Text("Tab Indisponível"));
      }
    }

    return Scaffold(
      body: currentScreen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
            // Reset filters when clicking navigation bar tabs directly
            if (idx == 0) {
              _homeUserFilter = null;
              _homeTagFilter = null;
              _homeTitleFilter = null;
            }
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Início"),
          NavigationDestination(icon: Icon(Icons.tv_outlined), selectedIcon: Icon(Icons.tv), label: "Lives"),
          NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie), label: "Séries"),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: "Canais"),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: "Biblioteca"),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET HELPER FOR BYPASSING HOTLINK PROTECTION ON IMAGES
// ============================================================================
class SKImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String fallbackUrl;

  const SKImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackUrl = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&q=80',
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Image.network(fallbackUrl, width: width, height: height, fit: fit);
    }
    
    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: const {'Referer': 'https://skvods.lol/'},
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: const Color(0xFF0F0F1E),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Image.network(fallbackUrl, width: width, height: height, fit: fit),
    );
  }
}

// ============================================================================
// 1. HOME SCREEN WIDGET
// ============================================================================
class HomeScreen extends StatefulWidget {
  final List<Streamer> streamers;
  final List<LiveChannel> liveChannels;
  final String? userFilter;
  final String? tagFilter;
  final String? titleFilter;
  final Function(Video) onVideoTap;
  final VoidCallback onClearFilters;

  const HomeScreen({
    super.key,
    required this.streamers,
    required this.liveChannels,
    this.userFilter,
    this.tagFilter,
    this.titleFilter,
    required this.onVideoTap,
    required this.onClearFilters,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Video> _videos = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;
  final int _limit = 12;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userFilter != widget.userFilter || oldWidget.tagFilter != widget.tagFilter) {
      setState(() {
        _currentPage = 1;
        _videos.clear();
      });
      _fetchVideos();
    }
  }

  Future<void> _fetchVideos() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.fetchVideos(
        page: _currentPage,
        limit: _limit,
        user: widget.userFilter,
        tag: widget.tagFilter,
        search: _searchQuery,
      );

      setState(() {
        _videos = res['videos'];
        final total = res['totalItems'] as int;
        
        // Mock pagination for tags/search
        if (widget.tagFilter != null || _searchQuery.isNotEmpty) {
          _totalPages = 1;
        } else {
          _totalPages = (total / _limit).ceil();
          if (_totalPages < 1) _totalPages = 1;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Erro ao buscar vídeos: $e");
    }
  }

  String _formatDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final pad = (n) => n < 10 ? '0$n' : '$n';
    return h > 0 ? '$h:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = widget.userFilter != null || widget.tagFilter != null || _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleFilter ?? 'Início', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (hasActiveFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: Color(0xFF6366F1)),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _currentPage = 1;
                });
                widget.onClearFilters();
                _fetchVideos();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Pesquisar vídeos ou streamers...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _currentPage = 1;
                          });
                          _fetchVideos();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF0F0F1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1A1A35)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6366F1)),
                ),
              ),
              onSubmitted: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _currentPage = 1;
                });
                _fetchVideos();
              },
            ),
          ),

          // 2. Active Live Channels Banner
          if (widget.liveChannels.isNotEmpty && !hasActiveFilter)
            SizedBox(
              height: 75,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.liveChannels.length,
                itemBuilder: (context, index) {
                  final ch = widget.liveChannels[index];
                  // Find avatar URL from streamers list
                  final match = widget.streamers.firstWhere(
                    (s) => s.name.toLowerCase() == ch.name.toLowerCase(),
                    orElse: () => Streamer(id: '', name: ch.name, image: ''),
                  );

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C0D17),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipOval(
                              child: SKImage(
                                url: match.image.isNotEmpty ? match.image : null,
                                width: 38,
                                height: 38,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              match.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              ch.title.length > 20 ? '${ch.title.substring(0, 20)}...' : ch.title,
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            ),

          // 3. Videos Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : _videos.isEmpty
                    ? const Center(child: Text("Nenhum vídeo encontrado"))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: _videos.length,
                        itemBuilder: (context, idx) {
                          final v = _videos[idx];
                          final streamer = widget.streamers.firstWhere(
                            (s) => s.id == v.user,
                            orElse: () => Streamer(id: '', name: v.userDisplayName ?? 'Streamer', image: ''),
                          );

                          return InkWell(
                            onTap: () => widget.onVideoTap(v),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFF1A1A35)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        SKImage(url: v.poster),
                                        Positioned(
                                          bottom: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                                            child: Text(
                                              _formatDuration(v.duration),
                                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.between,
                                          children: [
                                            Text(
                                              streamer.name,
                                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                                            ),
                                            Text(
                                              "${v.views ?? 0} views",
                                              style: const TextStyle(fontSize: 9, color: Colors.white54),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 4. Pagination (Only when not filtering by tag/search)
          if (_totalPages > 1 && !hasActiveFilter)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF0F0F1E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() => _currentPage--);
                            _fetchVideos();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A35)),
                    child: const Text("Anterior"),
                  ),
                  Text("Página $_currentPage de $_totalPages", style: const TextStyle(fontSize: 12)),
                  ElevatedButton(
                    onPressed: _currentPage < _totalPages
                        ? () {
                            setState(() => _currentPage++);
                            _fetchVideos();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A35)),
                    child: const Text("Próxima"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. LIVES SCREEN WIDGET
// ============================================================================
class LivesScreen extends StatefulWidget {
  final List<Streamer> streamers;
  final Function(Video) onVideoTap;

  const LivesScreen({super.key, required this.streamers, required this.onVideoTap});

  @override
  State<LivesScreen> createState() => _LivesScreenState();
}

class _LivesScreenState extends State<LivesScreen> {
  List<Video> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLives();
  }

  Future<void> _fetchLives() async {
    try {
      final res = await ApiService.fetchVideos(tag: 'live');
      setState(() {
        _videos = res['videos'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Erro ao buscar lives: $e");
    }
  }

  String _formatDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final pad = (n) => n < 10 ? '0$n' : '$n';
    return h > 0 ? '$h:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lives Recentes", style: TextStyle(fontWeight: FontWeight.bold))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _videos.isEmpty
              ? const Center(child: Text("Nenhuma live gravada encontrada"))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, idx) {
                    final v = _videos[idx];
                    final streamer = widget.streamers.firstWhere(
                      (s) => s.id == v.user,
                      orElse: () => Streamer(id: '', name: v.userDisplayName ?? 'Streamer', image: ''),
                    );

                    return InkWell(
                      onTap: () => widget.onVideoTap(v),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF1A1A35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  SKImage(url: v.poster),
                                  Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        _formatDuration(v.duration),
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.between,
                                    children: [
                                      Text(
                                        streamer.name,
                                        style: const TextStyle(fontSize: 10, color: Colors.white60),
                                      ),
                                      Text(
                                        "${v.views ?? 0} views",
                                        style: const TextStyle(fontSize: 9, color: Colors.white54),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================================
// 3. SERIES SCREEN WIDGET
// ============================================================================
class SeriesScreen extends StatelessWidget {
  final List<Tag> tags;
  final List<Streamer> streamers;
  final Function(String, String) onTagSelected;

  const SeriesScreen({
    super.key,
    required this.tags,
    required this.streamers,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Filter tags that represent TV Shows / Series
    final seriesList = tags.where((t) => t.season != null || t.slug.contains('-s')).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Séries", style: TextStyle(fontWeight: FontWeight.bold))),
      body: seriesList.isEmpty
          ? const Center(child: Text("Nenhuma série catalogada encontrada"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: seriesList.length,
              itemBuilder: (context, index) {
                final tag = seriesList[index];
                
                // Fetch creators
                final creators = tag.users
                        ?.map((id) => streamers.firstWhere((s) => s.id == id, orElse: () => Streamer(id: '', name: '', image: '')))
                        .where((s) => s.name.isNotEmpty)
                        .map((s) => s.name)
                        .join(', ') ??
                    'Streamer';

                return Card(
                  color: const Color(0xFF0F0F1E),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF1A1A35)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(tag.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Temporada ${tag.season ?? 1} &bull; ${tag.videoCount ?? 0} Episódios\nCriador: $creators",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF6366F1)),
                    onTap: () => onTagSelected(tag.slug, tag.name),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// 4. CHANNELS SCREEN WIDGET
// ============================================================================
class ChannelsScreen extends StatelessWidget {
  final List<Streamer> streamers;
  final Function(String, String) onStreamerSelected;

  const ChannelsScreen({super.key, required this.streamers, required this.onStreamerSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Canais", style: TextStyle(fontWeight: FontWeight.bold))),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemCount: streamers.length,
        itemBuilder: (context, idx) {
          final s = streamers[idx];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1A1A35)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onStreamerSelected(s.id, s.name),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: SKImage(
                      url: s.image,
                      width: 70,
                      height: 70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  // Social badges mini row
                  if (s.socials != null && s.socials!.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: s.socials!.keys.take(2).map((key) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            key.toUpperCase(),
                            style: const TextStyle(fontSize: 8, color: Colors.white70),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 5. LIBRARY SCREEN (FAVORITES & HISTORY)
// ============================================================================
class LibraryScreen extends StatelessWidget {
  final List<Video> favorites;
  final List<Video> history;
  final Function(Video) onVideoTap;
  final Function(Video) onToggleFavorite;

  const LibraryScreen({
    super.key,
    required this.favorites,
    required this.history,
    required this.onVideoTap,
    required this.onToggleFavorite,
  });

  String _formatDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final pad = (n) => n < 10 ? '0$n' : '$n';
    return h > 0 ? '$h:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Sua Biblioteca", style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Favoritos"),
              Tab(text: "Histórico"),
            ],
            indicatorColor: Color(0xFF6366F1),
          ),
        ),
        body: TabBarView(
          children: [
            // Favorites view
            favorites.isEmpty
                ? const Center(child: Text("Nenhum vídeo favoritado ainda"))
                : _buildVideosList(context, favorites),
            
            // History view
            history.isEmpty
                ? const Center(child: Text("Nenhum histórico de reprodução"))
                : _buildVideosList(context, history),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosList(BuildContext context, List<Video> list) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final v = list[index];
        final isFavorite = favorites.any((fav) => fav.id == v.id);

        return Card(
          color: const Color(0xFF0F0F1E),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF1A1A35)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SKImage(url: v.poster),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.black80, borderRadius: BorderRadius.circular(3)),
                        child: Text(_formatDuration(v.duration), style: const TextStyle(fontSize: 8)),
                      ),
                    )
                  ],
                ),
              ),
            ),
            title: Text(
              v.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                v.userDisplayName ?? "Streamer",
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : Colors.grey,
              ),
              onPressed: () => onToggleFavorite(v),
            ),
            onTap: () => onVideoTap(v),
          ),
        );
      },
    );
  }
}
