import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const TinyBrowserApp());
}

enum _BrowserMenuAction {
  customizeUserAgent,
  showBookmarks,
  showHistory,
  setHome,
  clearHistory,
  clearBookmarks,
  pictureInPicture,
}

class TinyBrowserApp extends StatelessWidget {
  const TinyBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiny Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BrowserScreen(),
    );
  }
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final TextEditingController _urlCtrl =
      TextEditingController(text: 'https://www.google.com');
  final FocusNode _addressFocusNode = FocusNode();
  bool _canGoBack = false;
  bool _canGoForward = false;
  int _progress = 0; // 0-100
  String _currentUrl = 'https://www.google.com';
  String _homeUrl = 'https://www.google.com';
  static const int _historyLimit = 50;
  final List<String> _history = <String>[];
  final Set<String> _bookmarks = <String>{};
  bool _isBookmarked = false;

  // Media playback state
  bool _isMediaPlaying = false;
  bool _hasMedia = false;
  String _mediaTitle = '';
  String _mediaArtist = '';
  Timer? _mediaCheckTimer;
  static const MethodChannel _pipChannel = MethodChannel('com.browser.flut/pip');

  final Map<String, String> _userAgentOptions = {
    'Default': '',
    'Chrome Desktop':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'Safari on iPhone':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1',
  };
  String _currentUserAgent = 'Default';

  @override
  void initState() {
    super.initState();
    _setupMediaDetection();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgentOptions[_currentUserAgent] ?? '')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            _mediaCheckTimer?.cancel();
            setState(() {
              _progress = 0;
              _currentUrl = url;
              _isBookmarked = _bookmarks.contains(url);
              _hasMedia = false;
              _isMediaPlaying = false;
              _mediaTitle = '';
              _mediaArtist = '';
            });
            if (!_addressFocusNode.hasFocus && _urlCtrl.text != url) {
              _urlCtrl.text = url;
            }
          },
          onPageFinished: (url) async {
            final back = await _controller.canGoBack();
            final fwd = await _controller.canGoForward();
            if (!mounted) return;
            setState(() {
              _canGoBack = back;
              _canGoForward = fwd;
              _progress = 100;
              _currentUrl = url;
              _isBookmarked = _bookmarks.contains(url);
              _history.remove(url);
              _history.insert(0, url);
              if (_history.length > _historyLimit) {
                _history.removeRange(_historyLimit, _history.length);
              }
            });
            if (!_addressFocusNode.hasFocus && _urlCtrl.text != url) {
              _urlCtrl.text = url;
            }
            // Inject media detection script after page loads
            _injectMediaDetectionScript();
            _startMediaCheckTimer();
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.description)),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  void _showUserAgentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Customize User Agent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _userAgentOptions.keys.map((String key) {
              return ListTile(
                title: Text(key),
                leading: Radio<String>(
                  value: key,
                  groupValue: _currentUserAgent,
                  onChanged: (String? value) {
                    setState(() {
                      _currentUserAgent = value!;
                      _controller.setUserAgent(_userAgentOptions[value] ?? '');
                      _controller.reload();
                    });
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  setState(() {
                    _currentUserAgent = key;
                    _controller.setUserAgent(_userAgentOptions[key] ?? '');
                    _controller.reload();
                  });
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _setupMediaDetection() {
    // Setup is called in initState
  }

  void _injectMediaDetectionScript() {
    const script = '''
      (function() {
        if (window.mediaDetectionInjected) return;
        window.mediaDetectionInjected = true;
        
        // Detect video and audio elements
        function detectMedia() {
          const videos = document.querySelectorAll('video');
          const audios = document.querySelectorAll('audio');
          let hasMedia = videos.length > 0 || audios.length > 0;
          let isPlaying = false;
          let title = '';
          let artist = '';
          
          // Check video elements
          for (const video of videos) {
            if (!video.paused && !video.ended) {
              isPlaying = true;
            }
            if (video.title) title = video.title;
            if (document.title) title = document.title || title;
          }
          
          // Check audio elements
          for (const audio of audios) {
            if (!audio.paused && !audio.ended) {
              isPlaying = true;
            }
            if (audio.title) title = audio.title;
            if (document.title) title = document.title || title;
          }
          
          // Try to get YouTube video info
          if (window.location.hostname.includes('youtube.com') || 
              window.location.hostname.includes('youtu.be')) {
            try {
              const ytPlayer = document.querySelector('#movie_player');
              if (ytPlayer) {
                const ytData = ytPlayer.getVideoData ? ytPlayer.getVideoData() : null;
                if (ytData && ytData.video_id) {
                  hasMedia = true;
                  title = ytData.title || document.title || '';
                  artist = ytData.author || '';
                  isPlaying = ytPlayer.getPlayerState ? 
                    (ytPlayer.getPlayerState() === 1) : isPlaying;
                }
              }
            } catch (e) {}
          }
          
          // Listen for media events
          const allMedia = [...videos, ...audios];
          allMedia.forEach(media => {
            media.addEventListener('play', () => {
              window.flutter_inappwebview?.callHandler('onMediaPlay');
            });
            media.addEventListener('pause', () => {
              window.flutter_inappwebview?.callHandler('onMediaPause');
            });
            media.addEventListener('ended', () => {
              window.flutter_inappwebview?.callHandler('onMediaEnded');
            });
          });
          
          return {
            hasMedia: hasMedia,
            isPlaying: isPlaying,
            title: title || document.title || '',
            artist: artist
          };
        }
        
        // Expose function globally
        window.getMediaState = detectMedia;
        
        // Check media state periodically
        setInterval(() => {
          const state = detectMedia();
          if (window.flutter_mediaCallback) {
            window.flutter_mediaCallback(state);
          }
        }, 1000);
        
        // Initial check
        setTimeout(() => detectMedia(), 500);
      })();
    ''';
    _controller.runJavaScript(script);
  }

  void _startMediaCheckTimer() {
    _mediaCheckTimer?.cancel();
    _mediaCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final result = await _controller.runJavaScriptReturningResult(
          '(function() { try { const state = window.getMediaState ? window.getMediaState() : null; return state ? JSON.stringify(state) : null; } catch(e) { return null; } })()',
        );
        
        if (result != null && result != 'null' && result.toString() != 'null') {
          final String resultStr = result.toString();
          String jsonStr = resultStr;
          
          // Remove surrounding quotes if present
          if (resultStr.startsWith('"') && resultStr.endsWith('"')) {
            jsonStr = resultStr.substring(1, resultStr.length - 1)
                .replaceAll('\\"', '"')
                .replaceAll('\\\\', '\\')
                .replaceAll('\\n', '\n')
                .replaceAll('\\r', '\r');
          }
          
          final mediaState = _parseMediaState(jsonStr);
          if (mounted) {
            setState(() {
              _hasMedia = mediaState['hasMedia'] ?? false;
              _isMediaPlaying = mediaState['isPlaying'] ?? false;
              _mediaTitle = mediaState['title'] ?? '';
              _mediaArtist = mediaState['artist'] ?? '';
            });
          }
        } else {
          // No media detected
          if (mounted) {
            setState(() {
              _hasMedia = false;
              _isMediaPlaying = false;
            });
          }
        }
      } catch (e) {
        // Silently handle errors
      }
    });
  }

  Map<String, dynamic> _parseMediaState(String jsonStr) {
    try {
      // Try to parse as JSON first
      bool hasMedia = false;
      bool isPlaying = false;
      String title = '';
      String artist = '';
      
      // Extract hasMedia
      final hasMediaMatch = RegExp(r'"hasMedia"\s*:\s*(true|false)').firstMatch(jsonStr);
      if (hasMediaMatch != null) {
        hasMedia = hasMediaMatch.group(1) == 'true';
      }
      
      // Extract isPlaying
      final isPlayingMatch = RegExp(r'"isPlaying"\s*:\s*(true|false)').firstMatch(jsonStr);
      if (isPlayingMatch != null) {
        isPlaying = isPlayingMatch.group(1) == 'true';
      }
      
      // Extract title - handle escaped quotes
      final titleMatch = RegExp(r'"title"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(jsonStr);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.replaceAll('\\"', '"').replaceAll('\\\\', '\\') ?? '';
      }
      
      // Extract artist - handle escaped quotes
      final artistMatch = RegExp(r'"artist"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(jsonStr);
      if (artistMatch != null) {
        artist = artistMatch.group(1)?.replaceAll('\\"', '"').replaceAll('\\\\', '\\') ?? '';
      }
      
      return {
        'hasMedia': hasMedia,
        'isPlaying': isPlaying,
        'title': title,
        'artist': artist,
      };
    } catch (e) {
      return {'hasMedia': false, 'isPlaying': false, 'title': '', 'artist': ''};
    }
  }

  Future<void> _toggleMediaPlayback() async {
    try {
      const script = '''
        (function() {
          const videos = document.querySelectorAll('video');
          const audios = document.querySelectorAll('audio');
          let found = false;
          
          // Try to control video elements
          for (const video of videos) {
            if (video.paused) {
              video.play();
              found = true;
            } else {
              video.pause();
              found = true;
            }
            break;
          }
          
          // Try to control audio elements
          if (!found) {
            for (const audio of audios) {
              if (audio.paused) {
                audio.play();
              } else {
                audio.pause();
              }
              break;
            }
          }
          
          // Try YouTube controls
          if (window.location.hostname.includes('youtube.com') || 
              window.location.hostname.includes('youtu.be')) {
            try {
              const ytPlayer = document.querySelector('#movie_player');
              if (ytPlayer) {
                if (ytPlayer.getPlayerState && ytPlayer.getPlayerState() === 1) {
                  ytPlayer.pauseVideo();
                } else {
                  ytPlayer.playVideo();
                }
              }
            } catch (e) {}
          }
        })();
      ''';
      await _controller.runJavaScript(script);
      // Refresh media state after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        _injectMediaDetectionScript();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not control media playback')),
        );
      }
    }
  }

  Future<void> _enterPictureInPicture() async {
    try {
      final result = await _pipChannel.invokeMethod<bool>('enterPictureInPicture');
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entering Picture-in-Picture mode')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Picture-in-Picture not available')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PIP Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _mediaCheckTimer?.cancel();
    _urlCtrl.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  bool _isHttpScheme(String? scheme) => scheme == 'http' || scheme == 'https';

  Uri _buildSearchUri(String query) {
    return Uri.https('duckduckgo.com', '/', {'q': query});
  }

  Future<void> _loadUri(Uri uri) async {
    await _controller.loadRequest(uri);
    if (!mounted) return;
    setState(() {
      _progress = 0;
      _currentUrl = uri.toString();
      _isBookmarked = _bookmarks.contains(_currentUrl);
    });
    if (!_addressFocusNode.hasFocus) {
      _urlCtrl.text = uri.toString();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _loadFromField() async {
    var input = _urlCtrl.text.trim();
    if (input.isEmpty) return;
    final directUri = Uri.tryParse(input);
    if (directUri != null && _isHttpScheme(directUri.scheme)) {
      await _loadUri(directUri);
      return;
    }

    final prefixedUri = Uri.tryParse('https://$input');
    if (prefixedUri != null && prefixedUri.host.isNotEmpty) {
      await _loadUri(prefixedUri);
      return;
    }

    final searchUri = _buildSearchUri(input);
    await _loadUri(searchUri);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching for "$input"')),
    );
  }

  Future<void> _loadHome() async {
    final uri = Uri.tryParse(_homeUrl);
    if (uri != null && _isHttpScheme(uri.scheme)) {
      await _loadUri(uri);
    }
  }

  void _setCurrentAsHome() {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null || !_isHttpScheme(uri.scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot set non-HTTP(S) page as home.')),
      );
      return;
    }
    setState(() {
      _homeUrl = _currentUrl;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Home page updated.')),
    );
  }

  void _toggleBookmark() {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null || !_isHttpScheme(uri.scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only HTTP(S) pages can be bookmarked.')),
      );
      return;
    }
    setState(() {
      if (_bookmarks.contains(_currentUrl)) {
        _bookmarks.remove(_currentUrl);
        _isBookmarked = false;
      } else {
        _bookmarks.add(_currentUrl);
        _isBookmarked = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked ? 'Added to bookmarks.' : 'Removed from bookmarks.',
        ),
      ),
    );
  }

  void _showBookmarksSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        final bookmarks = _bookmarks.toList()..sort();
        if (bookmarks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('No bookmarks yet.'),
            ),
          );
        }
        return ListView.separated(
          itemCount: bookmarks.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final url = bookmarks[index];
            return ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                final uri = Uri.tryParse(url);
                if (uri != null && _isHttpScheme(uri.scheme)) {
                  _loadUri(uri);
                }
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove bookmark',
                onPressed: () {
                  setState(() {
                    _bookmarks.remove(url);
                    _isBookmarked = _bookmarks.contains(_currentUrl);
                  });
                  Navigator.of(ctx).pop();
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        if (_history.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('History is empty.'),
            ),
          );
        }
        return ListView.separated(
          itemCount: _history.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final url = _history[index];
            final host = Uri.tryParse(url)?.host ?? url;
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                final uri = Uri.tryParse(url);
                if (uri != null && _isHttpScheme(uri.scheme)) {
                  _loadUri(uri);
                }
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove from history',
                onPressed: () {
                  setState(() {
                    _history.removeAt(index);
                  });
                  Navigator.of(ctx).pop();
                },
              ),
            );
          },
        );
      },
    );
  }

  void _clearHistory() {
    if (_history.isEmpty) return;
    setState(() {
      _history.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('History cleared.')),
    );
  }

  void _clearBookmarks() {
    if (_bookmarks.isEmpty) return;
    setState(() {
      _bookmarks.clear();
      _isBookmarked = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmarks cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: SafeArea(
            bottom: false,
            child: Container(
              height: 40,
              alignment: Alignment.center,
              child: TextField(
                controller: _urlCtrl,
                focusNode: _addressFocusNode,
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _loadFromField(),
                decoration: InputDecoration(
                  hintText: 'Enter URL',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _canGoBack
                  ? () async {
                      await _controller.goBack();
                    }
                  : null,
              tooltip: 'Back',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _canGoForward
                  ? () async {
                      await _controller.goForward();
                    }
                  : null,
              tooltip: 'Forward',
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined),
              onPressed: _loadHome,
              tooltip: 'Home',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _controller.reload();
              },
              tooltip: 'Reload',
            ),
            IconButton(
              icon: Icon(
                _isBookmarked ? Icons.star : Icons.star_border,
                color: _isBookmarked ? Colors.amber : null,
              ),
              onPressed: _toggleBookmark,
              tooltip: _isBookmarked ? 'Remove bookmark' : 'Add bookmark',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_right_outlined),
              onPressed: _loadFromField,
              tooltip: 'Go',
            ),
            if (_hasMedia)
              IconButton(
                icon: Icon(_isMediaPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _toggleMediaPlayback,
                tooltip: _isMediaPlaying ? 'Pause' : 'Play',
              ),
            if (_hasMedia)
              IconButton(
                icon: const Icon(Icons.picture_in_picture),
                onPressed: _enterPictureInPicture,
                tooltip: 'Picture-in-Picture',
              ),
            PopupMenuButton<_BrowserMenuAction>(
              onSelected: (value) {
                switch (value) {
                  case _BrowserMenuAction.customizeUserAgent:
                    _showUserAgentDialog();
                    break;
                  case _BrowserMenuAction.showBookmarks:
                    _showBookmarksSheet();
                    break;
                  case _BrowserMenuAction.showHistory:
                    _showHistorySheet();
                    break;
                  case _BrowserMenuAction.setHome:
                    _setCurrentAsHome();
                    break;
                  case _BrowserMenuAction.clearHistory:
                    _clearHistory();
                    break;
                  case _BrowserMenuAction.clearBookmarks:
                    _clearBookmarks();
                    break;
                  case _BrowserMenuAction.pictureInPicture:
                    _enterPictureInPicture();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<_BrowserMenuAction>(
                  value: _BrowserMenuAction.customizeUserAgent,
                  child: Text('Customize User Agent'),
                ),
                const PopupMenuItem<_BrowserMenuAction>(
                  value: _BrowserMenuAction.showBookmarks,
                  child: Text('Bookmarks'),
                ),
                const PopupMenuItem<_BrowserMenuAction>(
                  value: _BrowserMenuAction.showHistory,
                  child: Text('History'),
                ),
                const PopupMenuItem<_BrowserMenuAction>(
                  value: _BrowserMenuAction.setHome,
                  child: Text('Set Current As Home'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<_BrowserMenuAction>(
                  value: _BrowserMenuAction.pictureInPicture,
                  enabled: _hasMedia,
                  child: const Text('Picture-in-Picture'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<_BrowserMenuAction>(
                  value: _BrowserMenuAction.clearHistory,
                  enabled: _history.isNotEmpty,
                  child: const Text('Clear History'),
                ),
                PopupMenuItem<_BrowserMenuAction>(
                  value: _BrowserMenuAction.clearBookmarks,
                  enabled: _bookmarks.isNotEmpty,
                  child: const Text('Clear Bookmarks'),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Column(
          children: [
            if (_progress < 100)
              LinearProgressIndicator(value: _progress / 100),
            if (_hasMedia && (_mediaTitle.isNotEmpty || _mediaArtist.isNotEmpty))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_isMediaPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _toggleMediaPlayback,
                      tooltip: _isMediaPlaying ? 'Pause' : 'Play',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_mediaTitle.isNotEmpty)
                            Text(
                              _mediaTitle,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (_mediaArtist.isNotEmpty)
                            Text(
                              _mediaArtist,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture),
                      onPressed: _enterPictureInPicture,
                      tooltip: 'Picture-in-Picture',
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SafeArea(
                top: false,
                child: WebViewWidget(controller: _controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
