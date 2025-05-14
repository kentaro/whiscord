import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WhiscordApp());
}

class WhiscordApp extends StatelessWidget {
  const WhiscordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whiscord',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF8A2BE2), // ビビッドなパープル
          secondary: const Color(0xFF00FFFF), // サイバーなシアン
          tertiary: const Color(0xFFFF00FF), // ネオンピンク
          background: const Color(0xFF121212), // ダークグレー
          surface: const Color(0xFF1E1E1E), // ダークサーフェス
          error: const Color(0xFFFF3D71), // モダンなエラーカラー
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF8A2BE2),
          secondary: const Color(0xFF00FFFF),
          tertiary: const Color(0xFFFF00FF),
          background: const Color(0xFF121212),
          surface: const Color(0xFF1E1E1E),
          error: const Color(0xFFFF3D71),
        ),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const RecorderScreen(),
    );
  }
}

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen>
    with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder(
    logLevel: Level.debug,
  );
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isRecorderReady = false;
  String _recordingPath = '';
  String _recognizedText = '';
  String _status = '準備中';

  // アニメーション用コントローラー
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // 設定値
  String _whisperApiKey = '';
  String _discordWebhookUrl = '';

  // 共有インテント処理用
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initRecorder();

    // アニメーションコントローラーの初期化
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);

    // 起動処理（ショートカット検出と共有リスナー初期化を含む）
    _checkForShortcutLaunch();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _whisperApiKey = prefs.getString('whisper_api_key') ?? '';
      _discordWebhookUrl = prefs.getString('discord_webhook_url') ?? '';

      if (_whisperApiKey.isEmpty || _discordWebhookUrl.isEmpty) {
        _status = '設定が必要です';
      }
    });
  }

  Future<void> _initRecorder() async {
    // マイク権限を要求
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() {
        _status = 'マイク権限が必要です';
      });
      return;
    }

    // オーディオセッションを初期化
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );

    try {
      await _recorder.openRecorder();
      _isRecorderReady = true; // レコーダー準備完了フラグを設定
      setState(() {
        if (_whisperApiKey.isNotEmpty && _discordWebhookUrl.isNotEmpty) {
          _status = '録音する準備ができました';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'レコーダー初期化エラー: $e';
      });
    }
  }

  void _initSharedContentListener() {
    try {
      print("共有リスナーを初期化中...");

      // 共有完了後にリセット（先にリセットしておく）
      try {
        ReceiveSharingIntent.instance.reset();
      } catch (e) {
        print("リセットエラー: $e");
      }

      // アプリ起動中に共有を受け取った場合
      _intentDataStreamSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(
            (List<SharedMediaFile> value) {
              print("共有されたメディア数: ${value.length}");
              if (value.isNotEmpty) {
                final String path = value.first.path;
                print("共有されたメディアパス: $path");
                if (path.endsWith('.mp3') ||
                    path.endsWith('.mp4') ||
                    path.endsWith('.m4a') ||
                    path.endsWith('.wav') ||
                    path.endsWith('.aac')) {
                  _processSharedAudio(path);
                } else {
                  setState(() {
                    _status = '非対応のファイル形式です: $path';
                  });
                }
              }
            },
            onError: (err) {
              print("共有エラー: $err");
              setState(() {
                _status = '共有エラー: $err';
              });
            },
          );

      // アプリが閉じられた状態から起動された場合は慎重に処理
      try {
        ReceiveSharingIntent.instance.getInitialMedia().then(
          (List<SharedMediaFile> value) {
            print("初期共有メディア数: ${value.length}");
            if (value.isNotEmpty) {
              final String path = value.first.path;
              print("初期共有メディアパス: $path");
              if (path.endsWith('.mp3') ||
                  path.endsWith('.mp4') ||
                  path.endsWith('.m4a') ||
                  path.endsWith('.wav') ||
                  path.endsWith('.aac')) {
                _processSharedAudio(path);
              } else {
                setState(() {
                  _status = '非対応のファイル形式です: $path';
                });
              }
            }
          },
          onError: (error) {
            print("初期共有メディア取得エラー: $error");
          },
        );
      } catch (e) {
        print("初期共有メディア処理エラー: $e");
      }
    } catch (e) {
      print("共有リスナー初期化エラー: $e");
    }
  }

  Future<void> _processSharedAudio(String filePath) async {
    print("共有された音声ファイルを処理: $filePath");

    if (_whisperApiKey.isEmpty || _discordWebhookUrl.isEmpty) {
      print("APIキーまたはWebhook URLが設定されていません");
      _navigateToSettings();
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = '共有された音声を処理中...';
      _recordingPath = filePath; // 共有されたファイルを使用
    });

    // 音声ファイルの確認
    final audioFile = File(filePath);
    if (await audioFile.exists()) {
      final fileSize = await audioFile.length();
      print("共有されたファイルサイズ: ${fileSize / 1024} KB");

      if (fileSize < 20000) {
        setState(() {
          _status = 'ファイルが小さすぎます（$fileSize バイト）';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _status =
            '共有された音声ファイルを処理中...（サイズ: ${(fileSize / 1024).toStringAsFixed(2)} KB）';
      });

      // 既存の音声認識処理を呼び出し
      await _transcribeAudio();
    } else {
      print("共有されたファイルが存在しません: $filePath");
      setState(() {
        _status = '共有されたファイルが見つかりません: $filePath';
        _isProcessing = false;
      });
    }
  }

  Future<void> _startRecording() async {
    if (_whisperApiKey.isEmpty || _discordWebhookUrl.isEmpty) {
      _navigateToSettings();
      return;
    }

    // isOpenの代わりに_isRecorderReadyフラグを使用
    if (!_isRecorderReady) {
      await _initRecorder();
      if (!_isRecorderReady) {
        setState(() {
          _status = 'レコーダーを準備できませんでした';
        });
        return;
      }
    }

    if (_recorder.isRecording) return;

    try {
      // 一時ファイルのパスを取得
      final tempDir = await getTemporaryDirectory();
      _recordingPath =
          '${tempDir.path}/temp_recording.mp4'; // wavからmp4に変更（互換性のため）

      // 録音を開始
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacMP4, // PCM16からAACに変更（より一般的なフォーマット）
        bitRate: 64000, // ビットレート設定
        sampleRate: 44100, // サンプルレート設定
      );

      setState(() {
        _isRecording = true;
        _status = '録音中...マイクに向かって話してください';
        _recognizedText = '';
      });
    } catch (e) {
      setState(() {
        _status = '録音エラー: $e';
      });
      // 録音中にエラーが発生した場合、フラグをリセットして再初期化を試みる
      _isRecorderReady = false;
    }
  }

  Future<void> _stopRecording() async {
    if (!_recorder.isRecording) return;

    // 録音を停止
    final recordingResult = await _recorder.stopRecorder();

    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _status = '音声を処理中...';
    });

    // 録音ファイルの確認
    final audioFile = File(_recordingPath);
    if (await audioFile.exists()) {
      final fileSize = await audioFile.length();
      // 録音ファイルのサイズチェック - 閾値を上げて短すぎる録音を排除
      if (fileSize < 20000) {
        // 約2-3秒未満と思われる短い録音
        setState(() {
          _status = '録音が短すぎます（$fileSize バイト）。もう少し長く話してください';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _status =
            '音声を処理中...（録音ファイル: $recordingResult, サイズ: ${(fileSize / 1024).toStringAsFixed(2)} KB）';
      });
    } else {
      setState(() {
        _status = '録音ファイルが作成されませんでした。再試行してください。';
        _isProcessing = false;
      });
      return;
    }

    // Whisper APIで音声認識
    await _transcribeAudio();
  }

  Future<void> _transcribeAudio() async {
    if (_whisperApiKey.isEmpty) {
      setState(() {
        _status = 'Whisper API キーが設定されていません';
        _isProcessing = false;
      });
      return;
    }

    try {
      // 音声ファイルの準備
      final audioFile = File(_recordingPath);
      if (!await audioFile.exists()) {
        setState(() {
          _status = '録音ファイルが見つかりません';
          _isProcessing = false;
        });
        return;
      }

      final fileBytes = await audioFile.readAsBytes();

      // Whisper APIにリクエスト
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );

      request.headers.addAll({'Authorization': 'Bearer $_whisperApiKey'});

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: 'audio.mp4',
          contentType: MediaType('audio', 'mp4'),
        ),
      );

      request.fields['model'] = 'whisper-1';
      request.fields['language'] = 'ja';
      request.fields['response_format'] = 'json';

      setState(() {
        _status = 'Whisper APIで音声認識中...';
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseBody);
        final transcription = jsonResponse['text'] as String;

        // 認識結果の信頼性チェック
        if (transcription.isEmpty ||
            transcription.contains('ご視聴ありがとうございました') ||
            transcription.contains('チャンネル登録') ||
            transcription.contains('高評価') ||
            transcription.contains('お願いします') ||
            transcription.contains('ご覧いただき') ||
            transcription.length < 3) {
          setState(() {
            _status = '音声認識に失敗しました。もう一度お試しください。';
            _isProcessing = false;
          });
          return;
        }

        setState(() {
          _recognizedText = transcription;
          _status =
              '認識完了: "${transcription.substring(0, transcription.length > 20 ? 20 : transcription.length)}${transcription.length > 20 ? "..." : ""}"';
        });

        // Discordに送信
        await _sendToDiscord(transcription);
      } else {
        setState(() {
          _status = '音声認識エラー: ${response.statusCode}';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = '処理エラー: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _sendToDiscord(String text) async {
    if (_discordWebhookUrl.isEmpty) {
      setState(() {
        _status = 'Discord Webhook URLが設定されていません';
        _isProcessing = false;
      });
      return;
    }

    try {
      setState(() {
        _status = 'Discordに送信中...';
      });

      // Discordにメッセージを送信
      final response = await http.post(
        Uri.parse(_discordWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'content': text}),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        setState(() {
          _status = 'Discordに送信完了!';
          _isProcessing = false;
        });
      } else {
        setState(() {
          _status = 'Discord送信エラー: ${response.statusCode}';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Discord送信エラー: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );

    // 設定画面から戻ってきたら設定を再読み込み
    await _loadSettings();
  }

  // ショートカットから起動されたかチェック
  Future<void> _checkForShortcutLaunch() async {
    bool launchedFromShortcut = false;

    try {
      const platform = MethodChannel('com.example.whiscord/shortcuts');
      final String? action = await platform.invokeMethod<String>(
        'getShortcutAction',
      );

      if (action != null && action.isNotEmpty) {
        print('ショートカットから起動: $action');
        launchedFromShortcut = true;

        if (action == 'record') {
          // 短い遅延を入れて、UIが完全に読み込まれた後に録音を開始
          Future.delayed(const Duration(milliseconds: 500), () {
            _startRecording();
          });
        } else if (action == 'settings') {
          // 設定画面を開く
          Future.delayed(const Duration(milliseconds: 500), () {
            _navigateToSettings();
          });
        }
      }
    } catch (e) {
      print('ショートカット処理エラー: $e');
    }

    // ショートカットから起動された場合と通常起動の場合で処理を分ける
    if (launchedFromShortcut) {
      // ショートカットから起動された場合はすぐに共有リスナーを初期化しない
      // （必要に応じて後でユーザーアクションに対応して初期化する）
      print('ショートカットから起動されたため、共有リスナーは初期化しません');
    } else {
      // 通常起動の場合は500ms後に共有リスナーを初期化
      Future.delayed(const Duration(milliseconds: 500), () {
        _initSharedContentListener();
      });
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _animationController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
                  'WHISCORD',
                  style: GoogleFonts.spaceMono(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                )
                .animate()
                .fadeIn(duration: 600.ms)
                .slideX(begin: -0.2, end: 0, curve: Curves.easeOutQuad),
            const SizedBox(width: 8),
            Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        _isRecording
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .fadeIn(duration: 300.ms)
                .then()
                .fadeOut(delay: 500.ms, duration: 500.ms)
                .fadeIn(duration: 300.ms),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: _navigateToSettings,
              )
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms)
              .scale(delay: 300.ms, duration: 400.ms),
        ],
      ),
      body: Stack(
        children: [
          // 背景のグラデーションとエフェクト
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF121212),
                  const Color(0xFF1E1E1E),
                  Color(0xFF121212).withOpacity(0.9),
                ],
              ),
            ),
          ),

          // メインコンテンツ
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ステータステキスト
                  GlassmorphicContainer(
                        width: double.infinity,
                        height: 50,
                        borderRadius: 15,
                        blur: 20,
                        alignment: Alignment.center,
                        border: 1,
                        linearGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF8A2BE2).withOpacity(0.1),
                            const Color(0xFF00FFFF).withOpacity(0.05),
                          ],
                        ),
                        borderGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF8A2BE2).withOpacity(0.3),
                            const Color(0xFF00FFFF).withOpacity(0.3),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _status,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: -0.2, end: 0),

                  const SizedBox(height: 24),

                  // 認識テキスト表示
                  if (_recognizedText.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '認識テキスト',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                        const SizedBox(height: 12),
                        GlassmorphicContainer(
                              width: double.infinity,
                              height: 160,
                              borderRadius: 20,
                              blur: 15,
                              border: 1,
                              linearGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.1),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                              borderGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.secondary.withOpacity(0.3),
                                  Theme.of(
                                    context,
                                  ).colorScheme.tertiary.withOpacity(0.3),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SingleChildScrollView(
                                  child: Text(
                                    _recognizedText,
                                    style: GoogleFonts.notoSans(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 300.ms)
                            .slideY(begin: 0.1, end: 0),
                      ],
                    ),

                  const Spacer(),

                  // マイク録音ボタン
                  AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isRecording ? _pulseAnimation.value : 1.0,
                            child: GestureDetector(
                              onTap:
                                  _isProcessing
                                      ? null
                                      : (_isRecording
                                          ? _stopRecording
                                          : _startRecording),
                              child: GlassmorphicContainer(
                                width: 80,
                                height: 80,
                                borderRadius: 40,
                                blur: 20,
                                alignment: Alignment.center,
                                border: 1.5,
                                linearGradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors:
                                      _isRecording
                                          ? [
                                            const Color(
                                              0xFFFF416C,
                                            ).withOpacity(0.3),
                                            const Color(
                                              0xFFFF4B2B,
                                            ).withOpacity(0.3),
                                          ]
                                          : [
                                            Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withOpacity(0.3),
                                            Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.3),
                                          ],
                                ),
                                borderGradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors:
                                      _isRecording
                                          ? [
                                            const Color(0xFFFF416C),
                                            const Color(0xFFFF4B2B),
                                          ]
                                          : [
                                            Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ],
                                ),
                                child: Icon(
                                  _isRecording ? Icons.stop_rounded : Icons.mic,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                      .animate()
                      .fadeIn(duration: 1000.ms)
                      .scaleXY(begin: 0.8, end: 1.0),

                  const SizedBox(height: 20),

                  // ステータステキスト
                  Text(
                    _isRecording ? 'Recording...' : '',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 1.0,
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // 処理中インジケータ
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF00FFFF),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _status,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
