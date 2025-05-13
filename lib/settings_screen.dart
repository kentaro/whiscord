import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _whisperApiKeyController = TextEditingController();
  final _discordWebhookUrlController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _whisperApiKeyController.text = prefs.getString('whisper_api_key') ?? '';
      _discordWebhookUrlController.text =
          prefs.getString('discord_webhook_url') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whisper_api_key', _whisperApiKeyController.text);
    await prefs.setString(
      'discord_webhook_url',
      _discordWebhookUrlController.text,
    );

    setState(() {
      _isLoading = false;
    });

    // 設定が保存されたことを通知
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('設定を保存しました', style: GoogleFonts.jetBrainsMono()),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
    );
  }

  @override
  void dispose() {
    _whisperApiKeyController.dispose();
    _discordWebhookUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
              'SETTINGS',
              style: GoogleFonts.spaceMono(
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideX(begin: -0.2, end: 0, curve: Curves.easeOutQuad),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.secondary,
        ),
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
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FFFF)),
              )
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                              'API設定',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideX(begin: -0.1, end: 0),
                        const SizedBox(height: 16),
                        GlassmorphicContainer(
                              width: double.infinity,
                              height: 80,
                              borderRadius: 15,
                              blur: 15,
                              alignment: Alignment.center,
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
                                  ).colorScheme.secondary.withOpacity(0.5),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.5),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: TextFormField(
                                  controller: _whisperApiKeyController,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Whisper API キー',
                                    labelStyle: GoogleFonts.jetBrainsMono(
                                      color: Colors.white70,
                                    ),
                                    border: InputBorder.none,
                                    helperText: '',
                                    helperStyle: GoogleFonts.jetBrainsMono(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                  ),
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'APIキーを入力してください';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 100.ms)
                            .slideY(begin: 0.1, end: 0),
                        Text(
                          'OpenAIのAPIキーを入力',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                              'Discord設定',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 200.ms)
                            .slideX(begin: -0.1, end: 0),
                        const SizedBox(height: 16),
                        GlassmorphicContainer(
                              width: double.infinity,
                              height: 80,
                              borderRadius: 15,
                              blur: 15,
                              alignment: Alignment.center,
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
                                  ).colorScheme.tertiary.withOpacity(0.5),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.5),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: TextFormField(
                                  controller: _discordWebhookUrlController,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Discord Webhook URL',
                                    labelStyle: GoogleFonts.jetBrainsMono(
                                      color: Colors.white70,
                                    ),
                                    border: InputBorder.none,
                                    helperText: '',
                                    helperStyle: GoogleFonts.jetBrainsMono(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Webhook URLを入力してください';
                                    }
                                    if (!value.startsWith(
                                      'https://discord.com/api/webhooks/',
                                    )) {
                                      return '正しいDiscord Webhook URLを入力してください';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 300.ms)
                            .slideY(begin: 0.1, end: 0),
                        Text(
                          'DiscordのWebhook URLを入力',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 32),
                        GestureDetector(
                              onTap: _saveSettings,
                              child: GlassmorphicContainer(
                                width: double.infinity,
                                height: 60,
                                borderRadius: 15,
                                blur: 15,
                                alignment: Alignment.center,
                                border: 1,
                                linearGradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF8A2BE2).withOpacity(0.2),
                                    const Color(0xFF00FFFF).withOpacity(0.2),
                                  ],
                                ),
                                borderGradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context).colorScheme.secondary,
                                    Theme.of(context).colorScheme.primary,
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '保存',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 400.ms)
                            .scaleXY(begin: 0.9, end: 1.0),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
