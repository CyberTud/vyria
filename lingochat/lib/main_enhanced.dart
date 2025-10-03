import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await dotenv.load();
  } catch (e) {
    print('Using default configuration');
  }

  runApp(
    const ProviderScope(
      child: VyriaEnhancedApp(),
    ),
  );
}

class VyriaEnhancedApp extends StatelessWidget {
  const VyriaEnhancedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vyria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFACC15),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const ChatScreen(),
    );
  }
}

// API Service
class ChatService {
  final Dio _dio;
  static final String baseUrl =
      dotenv.env['API_BASE_URL'] ?? 'https://vyria-1.onrender.com';

  ChatService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ));

  Future<ChatResponse> sendMessage(
      List<Map<String, String>> messages, String language, String level,
      {RoleplayScenario? roleplay, bool isFirstMessage = false}) async {
    try {
      final data = {
        'messages': messages,
        'language': language,
        'level': level,
      };

      if (roleplay != null) {
        data['roleplay'] = roleplay.toJson();
        data['isFirstMessage'] = isFirstMessage;
      }

      final response = await _dio.post('/chat', data: data);

      return ChatResponse.fromJson(response.data);
    } catch (e) {
      print('API Error: $e');
      throw Exception('Failed to send message');
    }
  }

  Future<Map<String, dynamic>> getLanguages() async {
    try {
      final response = await _dio.get('/languages');
      return response.data;
    } catch (e) {
      return {
        'languages': [
          {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸'},
          {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
        ],
        'levels': ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']
      };
    }
  }

  Future<List<RoleplayScenario>> getRoleplays(
      String language, String level) async {
    try {
      final response = await _dio.get('/roleplays', queryParameters: {
        'language': language,
        'level': level,
      });

      final scenarios = response.data['scenarios'] as List;
      return scenarios.map((s) => RoleplayScenario.fromJson(s)).toList();
    } catch (e) {
      print('Error fetching roleplays: $e');
      return [];
    }
  }
}

// Roleplay Scenario Model
class RoleplayScenario {
  final String id;
  final String title;
  final String scenario;
  final String character;
  final String setting;
  final String starter;
  final List<String> hints;

  RoleplayScenario({
    required this.id,
    required this.title,
    required this.scenario,
    required this.character,
    required this.setting,
    required this.starter,
    required this.hints,
  });

  factory RoleplayScenario.fromJson(Map<String, dynamic> json) {
    return RoleplayScenario(
      id: json['id'],
      title: json['title'],
      scenario: json['scenario'],
      character: json['character'],
      setting: json['setting'],
      starter: json['starter'],
      hints: List<String>.from(json['hints'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scenario': scenario,
      'character': character,
      'setting': setting,
    };
  }
}

// Enhanced Data Models
class ChatResponse {
  final String message;
  final CorrectionData? correction;
  final Grade? grade;
  final int points;

  ChatResponse({
    required this.message,
    this.correction,
    this.grade,
    this.points = 0,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      message: json['message'] as String,
      correction: json['correction'] != null
          ? CorrectionData.fromJson(json['correction'])
          : null,
      grade: json['grade'] != null ? Grade.fromJson(json['grade']) : null,
      points: json['points'] ?? 0,
    );
  }
}

class CorrectionData {
  final bool hasErrors;
  final String corrected;
  final List<Mistake> mistakes;
  final String feedback;
  final List<String> improvements;

  CorrectionData({
    required this.hasErrors,
    required this.corrected,
    required this.mistakes,
    required this.feedback,
    required this.improvements,
  });

  factory CorrectionData.fromJson(Map<String, dynamic> json) {
    return CorrectionData(
      hasErrors: json['hasErrors'] ?? false,
      corrected: json['corrected'] ?? '',
      mistakes: (json['mistakes'] as List<dynamic>?)
              ?.map((m) => Mistake.fromJson(m))
              .toList() ??
          [],
      feedback: json['feedback'] ?? '',
      improvements: List<String>.from(json['improvements'] ?? []),
    );
  }
}

class Mistake {
  final String type;
  final String original;
  final String correction;
  final String explanation;

  Mistake({
    required this.type,
    required this.original,
    required this.correction,
    required this.explanation,
  });

  factory Mistake.fromJson(Map<String, dynamic> json) {
    return Mistake(
      type: json['type'] ?? 'grammar',
      original: json['original'] ?? '',
      correction: json['correction'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }
}

class Grade {
  final String letter;
  final int score;
  final String feedback;

  Grade({
    required this.letter,
    required this.score,
    required this.feedback,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      letter: json['letter'] ?? 'B',
      score: json['score'] ?? 80,
      feedback: json['feedback'] ?? 'Good job!',
    );
  }

  Color get color {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.blue;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }
}

// Providers
final chatServiceProvider = Provider((ref) => ChatService());
final selectedLanguageProvider = StateProvider((ref) => 'Spanish');
final selectedLevelProvider = StateProvider((ref) => 'B1');
final totalPointsProvider = StateProvider((ref) => 0);
final streakProvider = StateProvider((ref) => 0);
final activeRoleplayProvider = StateProvider<RoleplayScenario?>((ref) => null);
final showHintsProvider = StateProvider((ref) => true);

// Enhanced Chat Screen
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  final _apiMessages = <Map<String, String>>[];
  bool _isTyping = false;
  bool _showRoleplays = false;
  List<RoleplayScenario> _roleplays = [];

  late AnimationController _pointsAnimController;
  late Animation<double> _pointsAnimation;

  @override
  void initState() {
    super.initState();
    _pointsAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pointsAnimation = CurvedAnimation(
      parent: _pointsAnimController,
      curve: Curves.elasticOut,
    );
    _loadRoleplays();
  }

  void _sendMessage(String text, {bool isFirstMessage = false}) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _apiMessages.add({'role': 'user', 'content': text});
    _controller.clear();

    HapticFeedback.lightImpact();

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    try {
      final service = ref.read(chatServiceProvider);
      final language = ref.read(selectedLanguageProvider);
      final level = ref.read(selectedLevelProvider);
      final activeRoleplay = ref.read(activeRoleplayProvider);

      final response = await service.sendMessage(
        _apiMessages,
        language,
        level,
        roleplay: activeRoleplay,
        isFirstMessage: isFirstMessage,
      );

      if ((response.correction != null || response.grade != null) &&
          _messages.isNotEmpty) {
        setState(() {
          _messages[_messages.length - 1] = ChatMessage(
            text: userMessage.text,
            isUser: true,
            timestamp: userMessage.timestamp,
            correction: response.correction,
            grade: response.grade,
            points: response.points,
          );
        });

        if (response.points > 0) {
          ref.read(totalPointsProvider.notifier).state += response.points;
          ref.read(streakProvider.notifier).state += 1;
          _pointsAnimController.forward(from: 0);
          HapticFeedback.mediumImpact();
        }
      }

      setState(() {
        _messages.add(ChatMessage(
          text: response.message,
          isUser: false,
          timestamp: DateTime.now(),
          translation: _extractTranslation(response.message, level),
        ));
        _isTyping = false;
      });

      _apiMessages.add({'role': 'assistant', 'content': response.message});
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '⚠️ Connection error. Please check if the server is running.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isTyping = false;
      });
    }
  }

  String? _extractTranslation(String message, String level) {
    // Extract English hints from parentheses for lower levels
    if (level == 'A1' || level == 'A2') {
      final regex = RegExp(r'\((.*?)\)');
      final matches = regex.allMatches(message);
      if (matches.isNotEmpty) {
        return matches.map((m) => m.group(1)).join(' • ');
      }
    }
    return null;
  }

  void _loadRoleplays() async {
    final service = ref.read(chatServiceProvider);
    final language = ref.read(selectedLanguageProvider);
    final level = ref.read(selectedLevelProvider);

    final scenarios = await service.getRoleplays(language, level);
    setState(() {
      _roleplays = scenarios;
    });
  }

  void _startRoleplay(RoleplayScenario roleplay) {
    ref.read(activeRoleplayProvider.notifier).state = roleplay;

    setState(() {
      _messages.clear();
      _apiMessages.clear();
      _showRoleplays = false;
      _messages.add(ChatMessage(
        text: roleplay.starter,
        isUser: false,
        timestamp: DateTime.now(),
        isRoleplayStarter: true,
        hints: roleplay.hints,
        translation: _extractTranslation(
            roleplay.starter, ref.read(selectedLevelProvider)),
      ));
    });

    _apiMessages.add({'role': 'assistant', 'content': roleplay.starter});

    HapticFeedback.mediumImpact();
  }

  void _endRoleplay() {
    ref.read(activeRoleplayProvider.notifier).state = null;
    setState(() {
      _messages.clear();
      _apiMessages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = ref.watch(selectedLanguageProvider);
    final selectedLevel = ref.watch(selectedLevelProvider);
    final totalPoints = ref.watch(totalPointsProvider);
    final streak = ref.watch(streakProvider);
    final activeRoleplay = ref.watch(activeRoleplayProvider);
    final showHints = ref.watch(showHintsProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vyria',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$selectedLanguage • Level $selectedLevel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pointsAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pointsAnimation.value * 0.2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade400,
                                      Colors.orange.shade400,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$totalPoints',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Controls Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelector(
                            icon: _getFlag(selectedLanguage),
                            label: selectedLanguage,
                            onTap: () => _showLanguageSelector(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSelector(
                            icon: '📚',
                            label: 'Level $selectedLevel',
                            onTap: () => _showLevelSelector(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Roleplay and Hints Controls
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showRoleplays = !_showRoleplays;
                              });
                              if (_showRoleplays) {
                                _loadRoleplays();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: activeRoleplay != null
                                    ? LinearGradient(
                                        colors: [
                                          Colors.green.shade400,
                                          Colors.teal.shade400
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.purple.shade400,
                                          Colors.pink.shade400
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    activeRoleplay != null
                                        ? Icons.theater_comedy
                                        : Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    activeRoleplay != null
                                        ? activeRoleplay.title
                                        : 'Start Roleplay',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (activeRoleplay != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _endRoleplay,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            ref.read(showHintsProvider.notifier).state =
                                !showHints;
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: showHints
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              showHints
                                  ? Icons.lightbulb
                                  : Icons.lightbulb_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Roleplay Selector
              if (_showRoleplays)
                Container(
                  height: 180,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _roleplays.length,
                    itemBuilder: (context, index) {
                      final roleplay = _roleplays[index];
                      return GestureDetector(
                        onTap: () => _startRoleplay(roleplay),
                        child: Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors
                                    .primaries[index % Colors.primaries.length]
                                    .shade300,
                                Colors
                                    .primaries[index % Colors.primaries.length]
                                    .shade500,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roleplay.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                roleplay.scenario,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  roleplay.character,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Chat Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0 && _isTyping) {
                      return const TypingIndicator();
                    }
                    final messageIndex = _isTyping ? index - 1 : index;
                    final message =
                        _messages[_messages.length - 1 - messageIndex];
                    return EnhancedMessageBubble(
                      message: message,
                      showHints: showHints,
                      currentLevel: selectedLevel,
                    );
                  },
                ),
              ),
              // Input Field
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: activeRoleplay != null
                              ? 'Reply to ${activeRoleplay.character}...'
                              : 'Type your message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(_controller.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        icon:
                            const Icon(Icons.send_rounded, color: Colors.white),
                        onPressed: () => _sendMessage(_controller.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelector({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFlag(String language) {
    final flags = {
      'Spanish': '🇪🇸',
      'French': '🇫🇷',
      'German': '🇩🇪',
      'Italian': '🇮🇹',
      'Portuguese': '🇵🇹',
      'Japanese': '🇯🇵',
      'Chinese': '🇨🇳',
      'Korean': '🇰🇷',
    };
    return flags[language] ?? '🌍';
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Language',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Spanish',
                  'French',
                  'German',
                  'Italian',
                  'Portuguese',
                  'Japanese',
                  'Chinese',
                  'Korean'
                ]
                    .map((lang) => GestureDetector(
                          onTap: () {
                            ref.read(selectedLanguageProvider.notifier).state =
                                lang;
                            Navigator.pop(context);
                            _loadRoleplays();
                          },
                          child: Chip(
                            label: Text('${_getFlag(lang)} $lang'),
                            backgroundColor:
                                ref.watch(selectedLanguageProvider) == lang
                                    ? const Color(0xFF6366F1)
                                    : Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: ref.watch(selectedLanguageProvider) == lang
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLevelSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Level',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']
                    .map((level) => GestureDetector(
                          onTap: () {
                            ref.read(selectedLevelProvider.notifier).state =
                                level;
                            Navigator.pop(context);
                            _loadRoleplays();
                          },
                          child: Chip(
                            label: Text('📚 Level $level'),
                            backgroundColor:
                                ref.watch(selectedLevelProvider) == level
                                    ? const Color(0xFF6366F1)
                                    : Colors.grey.shade200,
                            labelStyle: TextStyle(
                              color: ref.watch(selectedLevelProvider) == level
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Enhanced Chat Message Model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final CorrectionData? correction;
  final Grade? grade;
  final int points;
  final bool isError;
  final bool isRoleplayStarter;
  final String? translation;
  final List<String>? hints;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.correction,
    this.grade,
    this.points = 0,
    this.isError = false,
    this.isRoleplayStarter = false,
    this.translation,
    this.hints,
  });
}

// Enhanced Message Bubble
class EnhancedMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showHints;
  final String currentLevel;

  const EnhancedMessageBubble({
    super.key,
    required this.message,
    required this.showHints,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.isRoleplayStarter)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🎭 Roleplay Started',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      )
                    : message.isError
                        ? LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade600],
                          )
                        : LinearGradient(
                            colors: [Colors.white, Colors.grey.shade50],
                          ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser || message.isError
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ),
            // Show translation for AI messages if available
            if (!message.isUser && message.translation != null && showHints)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.translate, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        message.translation!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Show hints for roleplay starters
            if (message.hints != null && message.hints!.isNotEmpty && showHints)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          'Helpful phrases:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...message.hints!.map((hint) => Text(
                          '• $hint',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade700,
                          ),
                        )),
                  ],
                ),
              ),
            // Show correction and grade for user messages
            if (message.correction != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: message.grade?.color ?? Colors.grey,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: message.grade?.color ?? Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                message.grade?.letter ?? 'B',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${message.grade?.score ?? 0}%',
                              style: TextStyle(
                                color: message.grade?.color ?? Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (message.points > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${message.points} pts',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (message.correction!.hasErrors) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '✅ Corrected:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        message.correction!.corrected,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                      if (message.correction!.mistakes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '📝 Mistakes:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        ...message.correction!.mistakes.map((mistake) =>
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      mistake.type,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style:
                                                const TextStyle(fontSize: 11),
                                            children: [
                                              TextSpan(
                                                text: mistake.original,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                              const TextSpan(
                                                text: ' → ',
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                              TextSpan(
                                                text: mistake.correction,
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          mistake.explanation,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                    if (message.correction!.feedback.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        message.correction!.feedback,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Typing Indicator
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final value = (_animation.value - delay).clamp(0.0, 1.0);
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3 + value * 0.7),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
