import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar style
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
      child: VyriaLegacyApp(),
    ),
  );
}

class VyriaLegacyApp extends StatelessWidget {
  const VyriaLegacyApp({super.key});

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

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Scroll to bottom
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

      // Update user message with correction and grade
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

        // Add points with animation
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
                        // Logo and Title
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
                        // Points Display
                        AnimatedBuilder(
                          animation: _pointsAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pointsAnimation.value * 0.2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade400,
                                      Colors.orange.shade400,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
                    // Language and Level Selectors
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
                        // Streak Display
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
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(
                                '$streak',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Chat Messages
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isTyping && index == 0) {
                            return const TypingIndicator();
                          }

                          final messageIndex = _isTyping ? index - 1 : index;
                          final message =
                              _messages[_messages.length - 1 - messageIndex];

                          return EnhancedMessageBubble(
                            message: message,
                            onLongPress: () =>
                                _showMessageOptions(context, message),
                          );
                        },
                      ),
              ),
              // Enhanced Input Area
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tips_and_updates_outlined),
                      color: Colors.amber,
                      onPressed: () => _showHint(context),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: Colors.white,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.indigo.shade200,
                  Colors.purple.shade200,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to practice ${ref.watch(selectedLanguageProvider)}?',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start with a greeting!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              _buildSuggestionChip('👋 Hello'),
              _buildSuggestionChip('📚 I want to learn'),
              _buildSuggestionChip('🎯 Practice with me'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _controller.text = text.replaceAll(RegExp(r'^[^\s]+ '), '');
        _sendMessage(_controller.text);
      },
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.shade300,
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
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose Language',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...[
              'Spanish',
              'French',
              'German',
              'Italian',
              'Japanese',
              'Chinese',
              'Korean'
            ].map((lang) => ListTile(
                  leading: Text(_getFlag(lang),
                      style: const TextStyle(fontSize: 24)),
                  title: Text(lang),
                  trailing: ref.watch(selectedLanguageProvider) == lang
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    ref.read(selectedLanguageProvider.notifier).state = lang;
                    Navigator.pop(context);
                    setState(() {
                      _messages.clear();
                      _apiMessages.clear();
                    });
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLevelSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose Level',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].map((level) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getLevelColor(level),
                    child: Text(
                      level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text('Level $level'),
                  subtitle: Text(_getLevelDescription(level)),
                  trailing: ref.watch(selectedLevelProvider) == level
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    ref.read(selectedLevelProvider.notifier).state = level;
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'A1':
      case 'A2':
        return Colors.green;
      case 'B1':
      case 'B2':
        return Colors.blue;
      case 'C1':
      case 'C2':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getLevelDescription(String level) {
    switch (level) {
      case 'A1':
        return 'Beginner - Basic phrases';
      case 'A2':
        return 'Elementary - Simple conversations';
      case 'B1':
        return 'Intermediate - Most situations';
      case 'B2':
        return 'Upper Intermediate - Complex topics';
      case 'C1':
        return 'Advanced - Fluent expression';
      case 'C2':
        return 'Mastery - Near-native';
      default:
        return '';
    }
  }

  void _showHint(BuildContext context) {
    final hints = {
      'Spanish': ['¿Cómo estás?', '¿Qué tal tu día?', '¿De dónde eres?'],
      'French': [
        'Comment vas-tu?',
        'Quel temps fait-il?',
        'Qu\'est-ce que tu aimes?'
      ],
      'German': [
        'Wie geht es dir?',
        'Woher kommst du?',
        'Was machst du gerne?'
      ],
      'Italian': ['Come stai?', 'Di dove sei?', 'Cosa ti piace fare?'],
      'Japanese': ['元気ですか？', '趣味は何ですか？', '好きな食べ物は？'],
      'Chinese': ['你好吗？', '你喜欢什么？', '你是哪里人？'],
      'Korean': ['어떻게 지내요?', '취미가 뭐예요?', '어디에서 왔어요?'],
    };

    final language = ref.read(selectedLanguageProvider);
    final hint =
        hints[language]?[math.Random().nextInt(3)] ?? 'Try a greeting!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lightbulb, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text('Try: "$hint"')),
          ],
        ),
        backgroundColor: Colors.indigo.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title: const Text('Copy text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
            ),
            if (message.correction != null) ...[
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Copy corrected version'),
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: message.correction!.corrected,
                  ));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Corrected text copied!')),
                  );
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Try again'),
              onTap: () {
                Navigator.pop(context);
                _controller.text = message.text;
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pointsAnimController.dispose();
    super.dispose();
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
  final VoidCallback? onLongPress;

  const EnhancedMessageBubble({
    super.key,
    required this.message,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Main message bubble
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: message.isUser
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        )
                      : null,
                  color: message.isUser ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: message.isUser
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: message.isUser
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: message.isUser ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),

              // Grade and Points Display
              if (message.grade != null && message.isUser) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Grade Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: message.grade!.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: message.grade!.color,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          message.grade!.letter,
                          style: TextStyle(
                            color: message.grade!.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Score
                      Text(
                        '${message.grade!.score}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Points earned
                      if (message.points > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${message.points}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Correction Display
              if (message.correction != null && message.isUser) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Corrected Version',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message.correction!.corrected,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (message.correction!.mistakes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Mistakes Found:',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...message.correction!.mistakes.map((mistake) =>
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _getMistakeIcon(mistake.type),
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 13,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: mistake.original,
                                                style: const TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  color: Colors.red,
                                                ),
                                              ),
                                              const TextSpan(text: ' → '),
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
                                            fontSize: 12,
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
                      if (message.correction!.improvements.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.tips_and_updates,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tips for Improvement',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ...message.correction!.improvements.map(
                                (tip) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '• $tip',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Timestamp
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMistakeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'grammar':
        return Icons.menu_book;
      case 'spelling':
        return Icons.spellcheck;
      case 'vocabulary':
        return Icons.abc;
      case 'punctuation':
        return Icons.edit;
      default:
        return Icons.error_outline;
    }
  }
}

// Enhanced Typing Indicator
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double value = ((_controller.value + index * 0.2) % 1.0);
                return Container(
                  margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                  child: Transform.translate(
                    offset: Offset(0, -4 * math.sin(value * math.pi)),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
