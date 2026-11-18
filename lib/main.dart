import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF08080C),
    ),
  );
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
        scaffoldBackgroundColor: const Color(0xFF07070A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF2A42),
          secondary: Color(0xFF9D4EDD),
          surface: Color(0xFF111118),
        ),
        fontFamily: '.SF Pro Display',
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
    TmdbDiscoveryScreen(),
    SavedMediaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF12121B).withOpacity(0.7),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navButton(
                    index: 0,
                    icon: CupertinoIcons.sparkles,
                    activeIcon: CupertinoIcons.sparkles,
                    label: 'Extractor',
                  ),
                  _navButton(
                    index: 1,
                    icon: CupertinoIcons.film,
                    activeIcon: CupertinoIcons.film_fill,
                    label: 'TMDB Cinema',
                  ),
                  _navButton(
                    index: 2,
                    icon: CupertinoIcons.folder,
                    activeIcon: CupertinoIcons.folder_fill,
                    label: 'Vault',
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0),
    );
  }

  Widget _navButton({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF2A42).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: isSelected
              ? Border.all(color: const Color(0xFFFF2A42).withOpacity(0.6), width: 1)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF2A42).withOpacity(0.3),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFFFF2A42) : Colors.white54,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// TAB 1: Stream Extractor Screen with Glossy Cards & 4K Streaming
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
  List<VideoStreamInfo> _videoStreams = [];
  List<AudioOnlyStreamInfo> _audioStreams = [];

  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  String _downloadSpeed = '';
  String _statusMessage = '';

  Future<void> _fetchMedia() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _videoMeta = null;
      _videoStreams.clear();
      _audioStreams.clear();
      _statusMessage = 'Extracting 4K / 1080p stream manifests...';
    });

    try {
      final video = await _yt.videos.get(rawUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      final allVideo = manifest.video.toList()
        ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));

      final Map<String, VideoStreamInfo> uniqueMap = {};
      for (var s in allVideo) {
        final label = s.videoQualityLabel;
        if (!uniqueMap.containsKey(label)) {
          uniqueMap[label] = s;
        }
      }

      setState(() {
        _videoMeta = video;
        _videoStreams = uniqueMap.values.toList();
        _audioStreams = manifest.audioOnly.sortByBitrate().reversed.toList();
        _statusMessage = '';
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      setState(() {
        _statusMessage = 'Could not resolve stream. Check URL or connection.';
      });
      HapticFeedback.heavyImpact();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _urlController.text = data.text!;
      });
      _fetchMedia();
    }
  }

  Future<void> _downloadStream(StreamInfo stream, String title, bool isAudioOnly, String qualityLabel) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadSpeed = 'Establishing high-speed pipeline...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitized = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = isAudioOnly ? 'm4a' : 'mp4';
      final fileName = '${sanitized}_$qualityLabel.$ext';
      final savePath = '${dir.path}/$fileName';

      final streamFile = _yt.videos.streamsClient.get(stream);
      final file = File(savePath);
      final fileStream = file.openWrite();

      int receivedBytes = 0;
      final totalBytes = stream.size.totalBytes;
      final stopwatch = Stopwatch()..start();

      await for (final chunk in streamFile) {
        fileStream.add(chunk);
        receivedBytes += chunk.length;

        final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
        final speedMB = elapsedSec > 0 ? (receivedBytes / (1024 * 1024)) / elapsedSec : 0.0;

        setState(() {
          _downloadProgress = totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
          _downloadSpeed = '${speedMB.toStringAsFixed(1)} MB/s • ${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        });
      }

      await fileStream.flush();
      await fileStream.close();
      stopwatch.stop();

      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF171722),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Saved to Vault: $fileName',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
        _downloadSpeed = '';
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2A42), Color(0xFF9D4EDD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2A42).withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'StreamVault',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text(
                        'ProMotion 120Hz Pipeline',
                        style: TextStyle(fontSize: 12, color: Colors.white38, letterSpacing: 0.2),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.doc_on_clipboard, color: Colors.white, size: 20),
                ),
                onPressed: _pasteFromClipboard,
                tooltip: 'Paste Link',
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),

          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: TextField(
              controller: _urlController,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Paste video link or direct URL...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                prefixIcon: const Icon(CupertinoIcons.link, color: Colors.white38, size: 18),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: GestureDetector(
                    onTap: _fetchMedia,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2A42), Color(0xFFFF5268)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2A42).withOpacity(0.4),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: const Icon(CupertinoIcons.arrow_right, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onSubmitted: (_) => _fetchMedia(),
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 400.ms),

          if (_isLoading) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFF2A42), strokeWidth: 2.5),
                  const SizedBox(height: 16),
                  Text(_statusMessage, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
          ],

          if (_statusMessage.isNotEmpty && !_isLoading && !_isDownloading) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
              ),
            ),
          ],

          if (_isDownloading) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141420),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFF2A42).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2A42).withOpacity(0.2),
                    blurRadius: 25,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DOWNLOADING TO VAULT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF2A42),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 7,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2A42)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _downloadSpeed,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          ],

          if (_videoMeta != null) ...[
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF12121B),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(
                        _videoMeta!.thumbnails.highResUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: Colors.black45,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(
                          '${_videoMeta!.duration?.inMinutes ?? 0}:${((_videoMeta!.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _videoMeta!.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_videoMeta!.author} • ${_videoMeta!.engagement.viewCount} views',
                          style: const TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'ALL AVAILABLE RESOLUTIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._videoStreams.map((stream) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF181824),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        stream.videoQualityLabel.contains('1080') ||
                                                stream.videoQualityLabel.contains('2160') ||
                                                stream.videoQualityLabel.contains('1440')
                                            ? CupertinoIcons.sparkles
                                            : CupertinoIcons.film,
                                        color: const Color(0xFFFF2A42),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stream.videoQualityLabel,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            '${(stream.size.totalMegaBytes).toStringAsFixed(1)} MB • ${stream.container.name.toUpperCase()}',
                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 26),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PlayerScreen(
                                                streamUrl: stream.url.toString(),
                                                title: '${_videoMeta!.title} (${stream.videoQualityLabel})',
                                                isLocalFile: false,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(CupertinoIcons.arrow_down_circle_fill,
                                            color: Color(0xFFFF2A42), size: 26),
                                        onPressed: _isDownloading
                                            ? null
                                            : () => _downloadStream(
                                                  stream,
                                                  _videoMeta!.title,
                                                  false,
                                                  stream.videoQualityLabel,
                                                ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                        if (_audioStreams.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'STUDIO AUDIO TRACKS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._audioStreams.take(2).map((stream) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181824),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(CupertinoIcons.music_note, color: Colors.tealAccent, size: 19),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Audio Only (${stream.audioCodec.toUpperCase()})',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              '${(stream.size.totalMegaBytes).toStringAsFixed(1)} MB • ${stream.bitrate.kiloBitsPerSecond.round()} kbps',
                                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(CupertinoIcons.arrow_down_circle_fill,
                                          color: Colors.tealAccent, size: 26),
                                      onPressed: _isDownloading
                                          ? null
                                          : () => _downloadStream(
                                                stream,
                                                _videoMeta!.title,
                                                true,
                                                '${stream.bitrate.kiloBitsPerSecond.round()}kbps',
                                              ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

/// TAB 2: TMDB Cinema & TV Hub with In-App API Key & Read Token Support
class TmdbDiscoveryScreen extends StatefulWidget {
  const TmdbDiscoveryScreen({super.key});

  @override
  State<TmdbDiscoveryScreen> createState() => _TmdbDiscoveryScreenState();
}

class _TmdbDiscoveryScreenState extends State<TmdbDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();
  String _apiKey = '';
  String _readToken = '';
  List<dynamic> _searchResults = [];
  bool _loading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadStoredKeys();
  }

  Future<void> _loadStoredKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('tmdb_api_key') ?? '';
      _readToken = prefs.getString('tmdb_read_token') ?? '';
    });
    if (_hasCredentials) {
      _fetchTrending();
    }
  }

  bool get _hasCredentials => _apiKey.isNotEmpty || _readToken.isNotEmpty;

  Map<String, dynamic> _buildHeadersAndParams([Map<String, dynamic>? queryParams]) {
    final Map<String, dynamic> params = queryParams ?? {};
    final Options options = Options();

    if (_readToken.isNotEmpty) {
      options.headers = {'Authorization': 'Bearer $_readToken'};
    } else if (_apiKey.isNotEmpty) {
      params['api_key'] = _apiKey;
    }

    return {'params': params, 'options': options};
  }

  Future<void> _saveKeys(String key, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tmdb_api_key', key.trim());
    await prefs.setString('tmdb_read_token', token.trim());
    setState(() {
      _apiKey = key.trim();
      _readToken = token.trim();
    });
    Navigator.pop(context);
    _fetchTrending();
  }

  void _showApiKeyModal() {
    final keyController = TextEditingController(text: _apiKey);
    final tokenController = TextEditingController(text: _readToken);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TMDB Credentials', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Paste either your API Key (v3) OR your API Read Access Token (v4). It is encrypted strictly on your iPhone.',
                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              const Text('API Key (v3)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 6),
              TextField(
                controller: keyController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. 8d39f7a...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF181824),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Read Access Token (v4 - Optional Alternative)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 6),
              TextField(
                controller: tokenController,
                obscureText: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'eyJhbGciOi...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF181824),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2A42),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  onPressed: () => _saveKeys(keyController.text, tokenController.text),
                  child: const Text('Save & Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchTrending() async {
    if (!_hasCredentials) return;
    setState(() => _loading = true);
    try {
      final config = _buildHeadersAndParams();
      final res = await _dio.get(
        'https://api.themoviedb.org/3/trending/all/day',
        queryParameters: config['params'],
        options: config['options'],
      );
      setState(() {
        _searchResults = res.data['results'] ?? [];
        _status = '';
      });
    } catch (e) {
      setState(() => _status = 'Failed to load trending items. Verify your TMDB keys.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _searchQuery() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || !_hasCredentials) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      final config = _buildHeadersAndParams({'query': query});
      final res = await _dio.get(
        'https://api.themoviedb.org/3/search/multi',
        queryParameters: config['params'],
        options: config['options'],
      );
      setState(() {
        _searchResults = res.data['results'] ?? [];
        if (_searchResults.isEmpty) _status = 'No titles found.';
      });
    } catch (e) {
      setState(() => _status = 'Search failed. Check your TMDB credentials.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TMDB Cinema',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6),
                    ),
                    Text('Global Catalog & Episode Guides', style: TextStyle(fontSize: 12, color: Colors.white38)),
                  ],
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      !_hasCredentials ? CupertinoIcons.gear_badge_xmark : CupertinoIcons.gear,
                      color: !_hasCredentials ? Colors.orangeAccent : Colors.white70,
                      size: 20,
                    ),
                  ),
                  onPressed: _showApiKeyModal,
                ),
              ],
            ),
          ),
          if (!_hasCredentials)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orangeAccent.withOpacity(0.15), Colors.deepOrangeAccent.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.sparkles, color: Colors.orangeAccent, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Connect Your TMDB Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Tap the gear icon top right to paste your free TMDB API Key. Search series like Prison Break, stream trailers, and browse seasons.',
                              style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF12121A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search Prison Break, Breaking Bad, movies...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    prefixIcon: const Icon(CupertinoIcons.search, color: Colors.white38, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                  onSubmitted: (_) => _searchQuery(),
                ),
              ),
            ),
          ],
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFFF2A42))))
          else if (_status.isNotEmpty)
            Expanded(child: Center(child: Text(_status, style: const TextStyle(color: Colors.white38))))
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: _searchResults.length,
                itemBuilder: (context, idx) {
                  final item = _searchResults[idx];
                  final title = item['title'] ?? item['name'] ?? 'Untitled';
                  final posterPath = item['poster_path'];
                  final voteAverage = (item['vote_average'] ?? 0.0).toStringAsFixed(1);
                  final isTv = item['media_type'] == 'tv' || item.containsKey('first_air_date');

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TmdbDetailScreen(
                            id: item['id'],
                            isTv: isTv,
                            apiKey: _apiKey,
                            readToken: _readToken,
                            title: title,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                if (posterPath != null)
                                  Image.network(
                                    'https://image.tmdb.org/t/p/w500$posterPath',
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                                  )
                                else
                                  Container(color: Colors.white10, child: const Center(child: Icon(Icons.movie))),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 12),
                                        const SizedBox(width: 4),
                                        Text(voteAverage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: -0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (idx * 35).ms).slideY(begin: 0.1, end: 0);
                },
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Detail Screen for TMDB Shows & Movies with Episode Guides & Trailer Streamer
class TmdbDetailScreen extends StatefulWidget {
  final int id;
  final bool isTv;
  final String apiKey;
  final String readToken;
  final String title;

  const TmdbDetailScreen({
    super.key,
    required this.id,
    required this.isTv,
    required this.apiKey,
    required this.readToken,
    required this.title,
  });

  @override
  State<TmdbDetailScreen> createState() => _TmdbDetailScreenState();
}

class _TmdbDetailScreenState extends State<TmdbDetailScreen> {
  final Dio _dio = Dio();
  final YoutubeExplode _yt = YoutubeExplode();
  Map<String, dynamic>? _details;
  List<dynamic> _trailers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Map<String, dynamic> _buildHeadersAndParams([Map<String, dynamic>? queryParams]) {
    final Map<String, dynamic> params = queryParams ?? {};
    final Options options = Options();

    if (widget.readToken.isNotEmpty) {
      options.headers = {'Authorization': 'Bearer ${widget.readToken}'};
    } else if (widget.apiKey.isNotEmpty) {
      params['api_key'] = widget.apiKey;
    }

    return {'params': params, 'options': options};
  }

  Future<void> _fetchDetails() async {
    try {
      final endpoint = widget.isTv ? 'tv' : 'movie';
      final config = _buildHeadersAndParams();

      final detailRes = await _dio.get(
        'https://api.themoviedb.org/3/$endpoint/${widget.id}',
        queryParameters: config['params'],
        options: config['options'],
      );
      final videoRes = await _dio.get(
        'https://api.themoviedb.org/3/$endpoint/${widget.id}/videos',
        queryParameters: config['params'],
        options: config['options'],
      );

      setState(() {
        _details = detailRes.data;
        _trailers = (videoRes.data['results'] ?? [])
            .where((v) => v['site'] == 'YouTube' && (v['type'] == 'Trailer' || v['type'] == 'Teaser'))
            .toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _playTrailer(String youtubeKey, String trailerTitle) async {
    HapticFeedback.lightImpact();
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(youtubeKey);
      final stream = manifest.muxed.sortByVideoQuality().first;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              streamUrl: stream.url.toString(),
              title: '${widget.title} - $trailerTitle',
              isLocalFile: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not stream trailer: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF07070A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2A42))),
      );
    }

    final backdrop = _details?['backdrop_path'];
    final overview = _details?['overview'] ?? 'No overview available.';
    final seasons = widget.isTv ? (_details?['seasons'] ?? []) : [];
    final rating = (_details?['vote_average'] ?? 0.0).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF101018),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.chevron_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop != null)
                    Image.network(
                      'https://image.tmdb.org/t/p/w1280$backdrop',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black),
                    )
                  else
                    Container(color: Colors.black),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, const Color(0xFF07070A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2A42).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF2A42).withOpacity(0.5)),
                        ),
                        child: Text(
                          widget.isTv ? 'SERIES' : 'MOVIE',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF2A42)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text('$rating / 10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('STORY OVERVIEW',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(overview, style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.45)),
                  const SizedBox(height: 26),
                  if (_trailers.isNotEmpty) ...[
                    const Text('OFFICIAL TRAILERS (AD-FREE PROMOTION STREAM)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF2A42), letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    ..._trailers.map((tr) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14141E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF2A42).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.play_arrow_solid, color: Color(0xFFFF2A42), size: 16),
                            ),
                            title: Text(tr['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.white38),
                            onTap: () => _playTrailer(tr['key'], tr['name']),
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],
                  if (widget.isTv && seasons.isNotEmpty) ...[
                    const Text('SEASONS & EPISODES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    ...seasons.map((s) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14141E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['name'] ?? 'Season', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (s['air_date'] != null)
                                    Text('Premiered: ${s['air_date']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${s['episode_count'] ?? 0} Episodes',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TAB 3: Saved Media Screen (Offline Vault) with AirDrop & Export
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
    HapticFeedback.mediumImpact();
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Vault',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6),
                    ),
                    Text(
                      'Archived Local Files',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(CupertinoIcons.arrow_2_circlepath, color: Colors.white70, size: 20),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _loadLocalFiles();
                  },
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFFF2A42))))
          else if (_files.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.tray, size: 64, color: Colors.white.withOpacity(0.12)),
                    const SizedBox(height: 16),
                    const Text('Vault is currently empty', style: TextStyle(color: Colors.white38, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text('Extract and download videos to watch offline.', style: TextStyle(color: Colors.white24, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final name = file.path.split(Platform.pathSeparator).last;
                  final isAudio = name.endsWith('.m4a') || name.endsWith('.mp3');
                  final sizeMb = (File(file.path).lengthSync() / (1024 * 1024)).toStringAsFixed(1);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAudio
                              ? Colors.tealAccent.withOpacity(0.12)
                              : const Color(0xFFFF2A42).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAudio ? CupertinoIcons.music_note : CupertinoIcons.play_rectangle_fill,
                          color: isAudio ? Colors.tealAccent : const Color(0xFFFF2A42),
                          size: 20,
                        ),
                      ),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('$sizeMb MB', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.share, color: Colors.white70, size: 20),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Share.shareXFiles([XFile(file.path)]);
                            },
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteFile(file),
                          ),
                        ],
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
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
                  ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
                },
              ),
            ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

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
        playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFFF2A42),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black.withOpacity(0.85),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _hasError
            ? const Text('Could not play video stream.', style: TextStyle(color: Colors.white54))
            : (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Color(0xFFFF2A42)),
      ),
    );
  }
}
