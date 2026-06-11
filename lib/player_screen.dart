import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'api_service.dart';

class PlayerScreen extends StatefulWidget {
  final Video video;

  const PlayerScreen({super.key, required this.video});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _isPlayerLoading = false;
  String? _error;

  List<StreamSource> _streams = [];
  StreamSource? _activeStream;
  List<InternetArchiveFile> _iaFiles = [];

  @override
  void initState() {
    super.initState();
    _loadStreamDetails();
  }

  Future<void> _loadStreamDetails() async {
    try {
      // Fetch stream sources
      final streams = await ApiService.fetchStreamSources(widget.video.id);
      
      // Fetch IA files
      final iaFiles = await ApiService.fetchInternetArchiveFiles(widget.video.id);

      if (mounted) {
        setState(() {
          _streams = streams;
          _iaFiles = iaFiles;
          _isLoading = false;
        });

        if (streams.isNotEmpty) {
          // Select default stream (prefer HLS source first, then any HLS, then first stream)
          final defaultStream = streams.firstWhere(
            (s) => s.type == 'hls' && s.quality == 'source',
            orElse: () => streams.firstWhere(
              (s) => s.type == 'hls',
              orElse: () => streams.first,
            ),
          );
          _initializePlayer(defaultStream);
        } else {
          setState(() {
            _error = "Nenhuma fonte de transmissão disponível para este vídeo.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Erro ao carregar fontes: $e";
        });
      }
    }
  }

  Future<void> _initializePlayer(StreamSource stream, {Duration? startPosition}) async {
    if (mounted) {
      setState(() {
        _isPlayerLoading = true;
        _activeStream = stream;
      });
    }

    // Clean previous controllers
    await _disposePlayer();

    try {
      final uri = Uri.parse(stream.url);
      _videoPlayerController = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: ApiService.headers,
      );

      await _videoPlayerController!.initialize();

      if (mounted) {
        if (startPosition != null) {
          await _videoPlayerController!.seekTo(startPosition);
        }

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          aspectRatio: 16 / 9,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF6366F1),
            handleColor: const Color(0xFF8B5CF6),
            bufferedColor: Colors.white24,
            backgroundColor: Colors.white10,
          ),
          placeholder: Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          ),
        );

        setState(() {
          _isPlayerLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlayerLoading = false;
          _error = "Falha ao inicializar o player de vídeo: $e";
        });
      }
    }
  }

  Future<void> _disposePlayer() async {
    _chewieController?.dispose();
    _chewieController = null;
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  void _switchStream(StreamSource stream) {
    if (_activeStream == stream) return;
    
    // Save current position to resume playback
    final currentPos = _videoPlayerController?.value.position ?? Duration.zero;
    _initializePlayer(stream, startPosition: currentPos);
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m < 10 ? '0$m' : '$m';
    final ss = s < 10 ? '0$s' : '$s';
    
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }

  String _formatTimestamp(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final pad = (int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06060C),
      appBar: AppBar(
        title: Text(widget.video.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF0F0F1E),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _loadStreamDetails();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                          ),
                          child: const Text("Tentar Novamente"),
                        )
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Video Player View
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_chewieController != null)
                                Chewie(controller: _chewieController!)
                              else if (_isPlayerLoading)
                                const CircularProgressIndicator(color: Color(0xFF6366F1))
                              else
                                const Text("Player indisponível", style: TextStyle(color: Colors.white54)),
                              if (_isPlayerLoading && _chewieController != null)
                                Container(
                                  color: Colors.black45,
                                  child: const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
                                )
                            ],
                          ),
                        ),
                      ),

                      // 2. Video Meta Information
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (widget.video.tag ?? 'VOD').toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  "${widget.video.views ?? 0} views",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(widget.video.duration),
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.video.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            if (widget.video.description != null && widget.video.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F0F1E),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF1A1A35)),
                                ),
                                child: Text(
                                  widget.video.description!,
                                  style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 3. Servers / Qualities Selector
                      _buildSectionHeader("Servidores / Qualidades", Icons.dns),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _streams.map((st) {
                            final isSelected = _activeStream == st;
                            return ChoiceChip(
                              label: Text("${st.type.toUpperCase()} (${st.quality})"),
                              selected: isSelected,
                              onSelected: (_) => _switchStream(st),
                              selectedColor: const Color(0xFF6366F1).withOpacity(0.25),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFF8B5CF6) : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              backgroundColor: const Color(0xFF0F0F1E),
                              checkmarkColor: const Color(0xFF8B5CF6),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1A1A35),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // 4. IMDb Movies Timestamps (Jumper!)
                      if (widget.video.imdb != null && widget.video.imdb!.isNotEmpty) ...[
                        _buildSectionHeader("Filmes na Live", Icons.bookmark_outline),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: widget.video.imdb!.keys.length,
                          itemBuilder: (context, idx) {
                            final imdbId = widget.video.imdb!.keys.elementAt(idx);
                            final timestampObj = widget.video.imdb![imdbId]!;
                            final movieData = widget.video.imdbData?[imdbId];
                            final movieName = movieData?.brTitle ?? movieData?.primaryTitle ?? imdbId;

                            return Card(
                              color: const Color(0xFF0F0F1E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFF1A1A35)),
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatTimestamp(timestampObj.timestamp),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  movieName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                                ),
                                subtitle: movieData?.averageRating != null
                                    ? Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${movieData!.averageRating}/10",
                                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                                          ),
                                        ],
                                      )
                                    : null,
                                trailing: const Icon(Icons.play_circle_outline, color: Color(0xFF6366F1)),
                                onTap: () async {
                                  if (_videoPlayerController != null) {
                                    final target = Duration(seconds: timestampObj.timestamp);
                                    await _videoPlayerController!.seekTo(target);
                                    _videoPlayerController!.play();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Pulando para ${_formatTimestamp(timestampObj.timestamp)} - $movieName"),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ],

                      // 5. Internet Archive Files
                      if (_iaFiles.isNotEmpty) ...[
                        _buildSectionHeader("Arquivos do Acervo", Icons.cloud_download_outlined),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _iaFiles.length,
                          itemBuilder: (context, index) {
                            final file = _iaFiles[index];
                            final sizeMB = file.size != '0'
                                ? (int.parse(file.size) / (1024 * 1024)).toStringAsFixed(1)
                                : 'Desc';

                            // Construct original download link
                            final fileUrl =
                                "https://archive.org/download/video_caveiragameslive_2026-06-10_00-28-05_${widget.video.id}/${file.name}";

                            return Card(
                              color: const Color(0xFF0F0F1E),
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFF1A1A35)),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.description, color: Colors.grey),
                                title: Text(
                                  file.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  "$sizeMB MB &bull; Format: ${file.format}",
                                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                                ),
                                trailing: const Icon(Icons.open_in_new, color: Color(0xFF6366F1), size: 18),
                                onTap: () async {
                                  final uri = Uri.parse(fileUrl);
                                  if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                                    // link opened
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Não foi possível abrir o link")),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
