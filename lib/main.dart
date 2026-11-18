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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F14),
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
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFF9333EA),
          surface: Color(0xFF14141C),
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
    SavedMediaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF14141E).withOpacity(0.75),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
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
                    icon: CupertinoIcons.folder,
                    activeIcon: CupertinoIcons.folder_fill,
                    label: 'Vault',
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE50914).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: const Color(0xFFE50914).withOpacity(0.5), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFFE50914) : Colors.white54,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Screen 1: Extractor with Live Analysis, Dynamic Island style cards, and Haptic actions
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
      _statusMessage = 'Extracting stream metadata...';
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
      HapticFeedback.selectionClick();
    } catch (e) {
      setState(() {
        _statusMessage = 'Could not resolve stream. Check URL or network.';
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

  Future<void> _downloadStream(StreamInfo stream, String title, bool isAudioOnly) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadSpeed = 'Connecting...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final sanitized = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = isAudioOnly ? 'm4a' : 'mp4';
      final savePath = '${dir.path}/$sanitized.$ext';

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
          _downloadProgress = receivedBytes / totalBytes;
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
            backgroundColor: const Color(0xFF1E1E28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Downloaded: $sanitized.$ext',
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
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFF9333EA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'StreamVault',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'ProMotion Sideload Edition',
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.doc_on_clipboard, color: Colors.white70),
                onPressed: _pasteFromClipboard,
                tooltip: 'Paste Link',
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),

          const SizedBox(height: 24),

          // Search Bar Input
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(18),
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
              controller: _urlController,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Paste streaming link...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                prefixIcon: const Icon(CupertinoIcons.link, color: Colors.white38, size: 18),
                suffixIcon: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE50914),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.arrow_right, color: Colors.white, size: 14),
                  ),
                  onPressed: _fetchMedia,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (_) => _fetchMedia(),
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

          if (_isLoading) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2.5),
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

          // Active Download Progress Card
          if (_isDownloading) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF171724),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE50914).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE50914).withOpacity(0.15),
                    blurRadius: 20,
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
                        'ARCHIVING STREAM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE50914),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _downloadSpeed,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          ],

          // Video Result Card
          if (_videoMeta != null) ...[
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                        height: 210,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_videoMeta!.duration?.inMinutes ?? 0}:${((_videoMeta!.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _videoMeta!.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_videoMeta!.author} • ${_videoMeta!.engagement.viewCount} views',
                          style: const TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'SELECT RESOLUTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._videoStreams.map((stream) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(CupertinoIcons.film, color: Color(0xFFE50914), size: 18),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stream.videoQualityLabel,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            '${(stream.size.totalMegaBytes).toStringAsFixed(1)} MB',
                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(CupertinoIcons.play_circle_fill, color: Colors.white),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
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
                                        icon: const Icon(CupertinoIcons.arrow_down_circle_fill,
                                            color: Color(0xFFE50914)),
                                        onPressed: _isDownloading
                                            ? null
                                            : () => _downloadStream(stream, _videoMeta!.title, false),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                        ..._audioStreams.take(1).map((stream) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(CupertinoIcons.music_note, color: Colors.tealAccent, size: 18),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Audio Only (M4A / High Quality)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            '${(stream.size.totalMegaBytes).toStringAsFixed(1)} MB',
                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.arrow_down_circle_fill,
                                        color: Colors.tealAccent),
                                    onPressed: _isDownloading
                                        ? null
                                        : () => _downloadStream(stream, _videoMeta!.title, true),
                                  ),
                                ],
                              ),
                            )),
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

/// Screen 2: Vault with File Management & AirDrop Share
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
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    Text(
                      'Archived Local Files',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.arrow_2_circlepath, color: Colors.white70),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _loadLocalFiles();
                  },
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))))
          else if (_files.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.tray, size: 64, color: Colors.white.withOpacity(0.15)),
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
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAudio
                              ? Colors.tealAccent.withOpacity(0.1)
                              : const Color(0xFFE50914).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAudio ? CupertinoIcons.music_note : CupertinoIcons.play_rectangle_fill,
                          color: isAudio ? Colors.tealAccent : const Color(0xFFE50914),
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
                  ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.1, end: 0);
                },
              ),
            ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

/// Player Screen with ProMotion gesture controls & multi-speed selector
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black.withOpacity(0.8),
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
                : const CircularProgressIndicator(color: Color(0xFFE50914)),
      ),
    );
  }
}
