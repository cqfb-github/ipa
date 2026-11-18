import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StreamVaultApp());
}

class StreamVaultApp extends StatelessWidget {
  const StreamVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF18181F),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    ExtractorScreen(),
    SavedMediaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF14141B),
        indicatorColor: const Color(0xFFE50914).withOpacity(0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(CupertinoIcons.arrow_down_circle),
            selectedIcon: Icon(CupertinoIcons.arrow_down_circle_fill, color: Colors.white),
            label: 'Extract & Stream',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.folder),
            selectedIcon: Icon(CupertinoIcons.folder_fill, color: Colors.white),
            label: 'Offline Library',
          ),
        ],
      ),
    );
  }
}

/// Screen 1: URL Extractor, Direct Streamer & Downloader
class ExtractorScreen extends StatefulWidget {
  const ExtractorScreen({super.key});

  @override
  State<ExtractorScreen> createState() => _ExtractorScreenState();
}

class _ExtractorScreenState extends State<ExtractorScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  
  bool _isLoading = false;
  Video? _videoMeta;
  List<MuxedStreamInfo> _videoStreams = [];
  List<AudioOnlyStreamInfo> _audioStreams = [];

  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  String _statusMessage = '';

  Future<void> _fetchMedia() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _videoMeta = null;
      _videoStreams.clear();
      _audioStreams.clear();
      _statusMessage = 'Analyzing stream source...';
    });

    try {
      final video = await _yt.videos.get(rawUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      setState(() {
        _videoMeta = video;
        _videoStreams = manifest.muxed.sortByVideoQuality().toList();
        _audioStreams = manifest.audioOnly.toList();
        _statusMessage = '';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to load video: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadStream(StreamInfo stream, String title, bool isAudioOnly) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Preparing download...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = isAudioOnly ? 'm4a' : 'mp4';
      final savePath = '${dir.path}/$sanitizedTitle.$ext';

      final streamFile = _yt.videos.streamsClient.get(stream);
      final file = File(savePath);
      final fileStream = file.openWrite();

      int receivedBytes = 0;
      final totalBytes = stream.size.totalBytes;

      await for (final chunk in streamFile) {
        fileStream.add(chunk);
        receivedBytes += chunk.length;
        setState(() {
          _downloadProgress = receivedBytes / totalBytes;
          _statusMessage = 'Downloading: ${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        });
      }

      await fileStream.flush();
      await fileStream.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to library: $sanitizedTitle.$ext'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
        _statusMessage = '';
      });
    }
  }

  @override
  void dispose() {
    _yt.close();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.play_rectangle_fill, color: Color(0xFFE50914)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'StreamVault',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  Text(
                    'Ad-Free Stream & Offline Archiver',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'Paste video link or direct URL...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E1E28),
              suffixIcon: IconButton(
                icon: const Icon(CupertinoIcons.arrow_right_circle_fill, color: Color(0xFFE50914)),
                onPressed: _fetchMedia,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _fetchMedia(),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 30),
            const Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
          ],
          if (_statusMessage.isNotEmpty && !_isLoading && !_isDownloading) ...[
            const SizedBox(height: 16),
            Text(_statusMessage, style: const TextStyle(color: Colors.orangeAccent)),
          ],
          if (_isDownloading) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF181822),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
                  ),
                ],
              ),
            ),
          ],
          if (_videoMeta != null) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _videoMeta!.thumbnails.highResUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.black38,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _videoMeta!.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Author: ${_videoMeta!.author} • Duration: ${_videoMeta!.duration?.inMinutes ?? 0}m',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Available Streams (Download / Play)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            ..._videoStreams.map((stream) => Card(
                  color: const Color(0xFF1E1E28),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(CupertinoIcons.film, color: Color(0xFFE50914)),
                    title: Text('${stream.videoQualityLabel} (Video + Audio)'),
                    subtitle: Text('${(stream.size.totalMegaBytes).toStringAsFixed(1)} MB • ${stream.container.name}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.play_circle, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  streamUrl: stream.url.toString(),
                                  title: _videoMeta!.title,
                                  isLocalFile: false,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.arrow_down_to_line, color: Color(0xFFE50914)),
                          onPressed: _isDownloading
                              ? null
                              : () => _downloadStream(stream, _videoMeta!.title, false),
                        ),
                      ],
                    ),
                  ),
                )),
            ..._audioStreams.take(2).map((stream) => Card(
                  color: const Color(0xFF1E1E28),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(CupertinoIcons.music_note, color: Colors.tealAccent),
                    title: Text('Audio Only (${stream.audioCodec})'),
                    subtitle: Text('${(stream.size.totalMegaBytes).toStringAsFixed(1)} MB'),
                    trailing: IconButton(
                      icon: const Icon(CupertinoIcons.arrow_down_to_line, color: Colors.tealAccent),
                      onPressed: _isDownloading
                          ? null
                          : () => _downloadStream(stream, _videoMeta!.title, true),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

/// Screen 2: Offline Stored Files Library
class SavedMediaScreen extends StatefulWidget {
  const SavedMediaScreen({super.key});

  @override
  State<SavedMediaScreen> createState() => _SavedMediaScreenState();
}

class _SavedMediaScreenState extends State<SavedMediaScreen> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalFiles();
  }

  Future<void> _loadLocalFiles() async {
    setState(() => _loading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      final validFiles = entities.where((e) {
        final path = e.path.toLowerCase();
        return path.endsWith('.mp4') || path.endsWith('.m4a') || path.endsWith('.mp3');
      }).toList();

      setState(() {
        _files = validFiles;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    try {
      await file.delete();
      _loadLocalFiles();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Offline Library',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.refresh),
                  onPressed: _loadLocalFiles,
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_files.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No archived videos yet.', style: TextStyle(color: Colors.white38)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final name = file.path.split(Platform.pathSeparator).last;
                  final sizeMb = (File(file.path).lengthSync() / (1024 * 1024)).toStringAsFixed(1);

                  return Card(
                    color: const Color(0xFF1E1E28),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: const Icon(CupertinoIcons.film_fill, color: Color(0xFFE50914)),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$sizeMb MB'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.share),
                            onPressed: () {
                              Share.shareXFiles([XFile(file.path)]);
                            },
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                            onPressed: () => _deleteFile(file),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              streamUrl: file.path,
                              title: name,
                              isLocalFile: true,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Video Player Screen with Picture-in-Picture & Speed Control
class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final bool isLocalFile;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    required this.isLocalFile,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.isLocalFile) {
        _videoController = VideoPlayerController.file(File(widget.streamUrl));
      } else {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
      }

      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio > 0 ? _videoController.value.aspectRatio : 16 / 9,
        playbackSpeeds: [0.5, 1.0, 1.25, 1.5, 2.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFE50914),
          handleColor: Colors.white,
          backgroundColor: Colors.white24,
        ),
      );
      setState(() {});
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: _hasError
            ? const Text('Could not play video stream.', style: TextStyle(color: Colors.white))
            : (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Color(0xFFE50914)),
      ),
    );
  }
}
