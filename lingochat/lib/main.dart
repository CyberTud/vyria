import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'ui/animated_background.dart';
import 'ui/animated_mascot.dart';

const primaryColor = Color(0xFFFACC15);
const primaryAccent = Color(0xFFF97316);

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
    debugPrint('Using default configuration');
  }

  runApp(
    const ProviderScope(
      child: VyriaApp(),
    ),
  );
}

class VyriaApp extends StatelessWidget {
  const VyriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vyria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const SetupScreen(),
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
    List<Map<String, String>> messages,
    String language,
    String level, {
    RoleplayScenario? roleplay,
    bool isFirstMessage = false,
  }) async {
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
      debugPrint('API Error: $e');
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
    String language,
    String level,
  ) async {
    try {
      final response = await _dio.get('/roleplays', queryParameters: {
        'language': language,
        'level': level,
      });

      final scenarios = response.data['scenarios'] as List;
      return scenarios.map((s) => RoleplayScenario.fromJson(s)).toList();
    } catch (e) {
      debugPrint('Error fetching roleplays: $e');
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
  final String? translation;
  final String? hint;

  ChatResponse({
    required this.message,
    this.correction,
    this.grade,
    this.points = 0,
    this.translation,
    this.hint,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      message: json['message'] as String,
      correction: json['correction'] != null
          ? CorrectionData.fromJson(json['correction'])
          : null,
      grade: json['grade'] != null ? Grade.fromJson(json['grade']) : null,
      points: json['points'] ?? 0,
      translation: json['translation'] as String?,
      hint: json['hint'] as String?,
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

class LanguageOption {
  LanguageOption({
    required this.code,
    required this.name,
    required this.flag,
    required this.fact,
  });

  final String code;
  final String name;
  final String flag;
  final String fact;
}

class LevelOption {
  LevelOption({
    required this.code,
    required this.name,
    required this.description,
  });

  final String code;
  final String name;
  final String description;
}

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  bool _loading = true;
  bool _roleplaysLoading = false;
  String? _error;
  List<LanguageOption> _languages = [];
  List<LevelOption> _levels = [];
  List<RoleplayScenario> _roleplays = [];
  LanguageOption? _selectedLanguage;
  LevelOption? _selectedLevel;
  RoleplayScenario? _selectedRoleplay;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(chatServiceProvider);
      final data = await service.getLanguages();

      final languages = (data['languages'] as List<dynamic>? ?? [])
          .map((lang) => LanguageOption(
                code: lang['code'] as String? ?? 'es',
                name: lang['name'] as String? ?? 'Spanish',
                flag: lang['flag'] as String? ?? '🌍',
                fact: lang['fact'] as String? ?? '',
              ))
          .toList();

      final levels = (data['levels'] as List<dynamic>? ?? [])
          .map((level) => LevelOption(
                code: level is Map<String, dynamic>
                    ? level['code'] as String? ?? 'B1'
                    : level.toString(),
                name: level is Map<String, dynamic>
                    ? level['name'] as String? ?? ''
                    : level.toString(),
                description: level is Map<String, dynamic>
                    ? level['description'] as String? ?? ''
                    : '',
              ))
          .toList();

      final defaultLanguage = languages.isNotEmpty ? languages.first : null;
      final defaultLevel = levels.isNotEmpty
          ? (levels.length > 2 ? levels[2] : levels.first)
          : null;

      setState(() {
        _languages = languages;
        _levels = levels;
        _selectedLanguage = defaultLanguage;
        _selectedLevel = defaultLevel;
        _loading = false;
      });

      if (defaultLanguage != null && defaultLevel != null) {
        await _loadRoleplays(defaultLanguage, defaultLevel);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'We could not reach the server. Please try again.';
      });
    }
  }

  Future<void> _loadRoleplays(
    LanguageOption language,
    LevelOption level,
  ) async {
    setState(() {
      _roleplaysLoading = true;
      _selectedRoleplay = null;
    });

    try {
      final service = ref.read(chatServiceProvider);
      final scenarios = await service.getRoleplays(
        language.name,
        level.code,
      );

      setState(() {
        _roleplays = scenarios;
        _selectedRoleplay = scenarios.isNotEmpty ? scenarios.first : null;
        _roleplaysLoading = false;
      });
    } catch (e) {
      setState(() {
        _roleplaysLoading = false;
      });
    }
  }

  void _onLanguageSelected(LanguageOption option) {
    if (_selectedLanguage?.code == option.code) return;
    setState(() {
      _selectedLanguage = option;
    });
    final level = _selectedLevel;
    if (level != null) {
      _loadRoleplays(option, level);
    }
  }

  void _onLevelSelected(LevelOption option) {
    if (_selectedLevel?.code == option.code) return;
    setState(() {
      _selectedLevel = option;
    });
    final language = _selectedLanguage;
    if (language != null) {
      _loadRoleplays(language, option);
    }
  }

  void _startChat() {
    final language = _selectedLanguage;
    final level = _selectedLevel;
    if (language == null || level == null) {
      return;
    }

    ref.read(selectedLanguageProvider.notifier).state = language.name;
    ref.read(selectedLevelProvider.notifier).state = level.code;
    ref.read(activeRoleplayProvider.notifier).state = _selectedRoleplay;
    ref.read(totalPointsProvider.notifier).state = 0;
    ref.read(streakProvider.notifier).state = 0;
    ref.read(showHintsProvider.notifier).state = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to Vyria',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF422006),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose your language journey. Customise your experience and jump straight into an immersive conversation.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF92400E),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/vyria.png',
                          height: 140,
                          width: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const _SectionHeader(
                    title: 'Language',
                    subtitle: 'Pick the language you want to practice today.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      itemCount: _languages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final lang = _languages[index];
                        return _SelectableCard(
                          isSelected: _selectedLanguage?.code == lang.code,
                          onTap: () => _onLanguageSelected(lang),
                          icon: lang.flag,
                          title: lang.name,
                          subtitle: lang.fact,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    title: 'Level',
                    subtitle:
                        'Tell us your comfort level so we can tune the responses.',
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      children: _levels
                          .map(
                            (level) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _SelectableChip(
                                isSelected: _selectedLevel?.code == level.code,
                                label: 'Level ${level.code}',
                                description: level.description.isNotEmpty
                                    ? level.description
                                    : level.name,
                                onTap: () => _onLevelSelected(level),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    title: 'Simulation',
                    subtitle:
                        'Choose a scenario to roleplay or skip to keep the chat casual.',
                  ),
                  const SizedBox(height: 12),
                  _roleplaysLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          height: 190,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                (_roleplays.isEmpty ? 0 : _roleplays.length) + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final isSelected = _selectedRoleplay == null;
                                return _FreeConversationCard(
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedRoleplay = null;
                                    });
                                  },
                                );
                              }

                              if (_roleplays.isEmpty) {
                                return Container(
                                  width: 220,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.2),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'No simulations available yet. Pick "Free conversation" to start chatting.',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final roleplay = _roleplays[index - 1];
                              return _RoleplayCard(
                                roleplay: roleplay,
                                isSelected:
                                    roleplay.id == _selectedRoleplay?.id,
                                onTap: () {
                                  setState(() {
                                    _selectedRoleplay = roleplay;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startChat,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'Start chatting',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _loadInitialData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh options'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF78350F),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: primaryAccent.withOpacity(0.75),
              ),
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(isSelected ? 0.26 : 0.12),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.isSelected,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final bool isSelected;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [primaryColor, primaryAccent],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected ? Colors.transparent : primaryColor.withOpacity(0.3),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF78350F),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: isSelected ? Colors.white70 : const Color(0xFFB45309),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleplayCard extends StatelessWidget {
  const _RoleplayCard({
    required this.roleplay,
    required this.isSelected,
    required this.onTap,
  });

  final RoleplayScenario roleplay;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? const [primaryColor, primaryAccent]
                : [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(isSelected ? 0.28 : 0.12),
              blurRadius: isSelected ? 16 : 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roleplay.title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF78350F),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                roleplay.scenario,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : const Color(0xFFB45309),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white24 : primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                roleplay.character,
                style: TextStyle(
                  color: isSelected ? Colors.white : primaryAccent.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeConversationCard extends StatelessWidget {
  const _FreeConversationCard({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [primaryColor, primaryAccent],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.85),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(isSelected ? 0.28 : 0.12),
              blurRadius: isSelected ? 18 : 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💬 Free conversation',
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF78350F),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Chat casually with Vyria without a preset scenario. Perfect for warm-ups or open-ended practice.',
              style: TextStyle(
                color: isSelected ? Colors.white70 : const Color(0xFFB45309),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  bool _canSend = false;
  bool _hasInitializedRoleplay = false;

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
    _controller.addListener(_handleInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRoleplayIfNeeded();
    });
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
          translation: response.translation,
          hint: response.hint,
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

  void _handleInputChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _canSend) {
      setState(() {
        _canSend = hasText;
      });
    }
  }

  void _initializeRoleplayIfNeeded() {
    if (_hasInitializedRoleplay) return;
    final roleplay = ref.read(activeRoleplayProvider);
    if (roleplay == null) return;

    _hasInitializedRoleplay = true;
    _requestRoleplayIntro(roleplay);
  }

  Future<void> _requestRoleplayIntro(RoleplayScenario roleplay) async {
    setState(() {
      _isTyping = true;
    });

    try {
      final service = ref.read(chatServiceProvider);
      final language = ref.read(selectedLanguageProvider);
      final level = ref.read(selectedLevelProvider);

      final response = await service.sendMessage(
        _apiMessages,
        language,
        level,
        roleplay: roleplay,
        isFirstMessage: true,
      );

      setState(() {
        _messages.add(ChatMessage(
          text: response.message,
          isUser: false,
          timestamp: DateTime.now(),
          translation: response.translation,
          hint: response.hint,
          roleplayHints: roleplay.hints,
          isRoleplayStarter: true,
        ));
        _isTyping = false;
      });

      _apiMessages.add({'role': 'assistant', 'content': response.message});
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text:
              '⚠️ Could not start the scenario. Try again or begin a free conversation.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isTyping = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputChanged);
    _controller.dispose();
    _scrollController.dispose();
    _pointsAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = ref.watch(selectedLanguageProvider);
    final selectedLevel = ref.watch(selectedLevelProvider);
    final totalPoints = ref.watch(totalPointsProvider);
    final streak = ref.watch(streakProvider);
    final activeRoleplay = ref.watch(activeRoleplayProvider);
    final showHints = ref.watch(showHintsProvider);

    ref.listen<RoleplayScenario?>(activeRoleplayProvider, (previous, next) {
      if (!mounted) return;
      if (previous?.id != next?.id) {
        setState(() {
          _hasInitializedRoleplay = false;
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()),
          SafeArea(
            child: Column(
              children: [
                _ChatHeader(
                  language: selectedLanguage,
                  level: selectedLevel,
                  points: totalPoints,
                  streak: streak,
                  animation: _pointsAnimation,
                  activeScenario: activeRoleplay?.title,
                  onClearScenario: activeRoleplay != null
                      ? () {
                          ref.read(activeRoleplayProvider.notifier).state = null;
                          setState(() {
                            _messages.clear();
                            _apiMessages.clear();
                            _hasInitializedRoleplay = false;
                          });
                        }
                      : null,
                  onSettingsTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SetupScreen(),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 24),
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _MessageComposer(
                    controller: _controller,
                    canSend: _canSend,
                    placeholder: activeRoleplay != null
                        ? 'Reply to ${activeRoleplay.character}...'
                        : 'Type your message...',
                    onSend: () => _sendMessage(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  final String? hint;
  final List<String>? roleplayHints;

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
    this.hint,
    this.roleplayHints,
  });
}

// Enhanced Message Bubble
class EnhancedMessageBubble extends ConsumerStatefulWidget {
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
  ConsumerState<EnhancedMessageBubble> createState() =>
      _EnhancedMessageBubbleState();
}

class _EnhancedMessageBubbleState extends ConsumerState<EnhancedMessageBubble> {
  bool _showTranslation = false;
  bool _showHint = false;
  String _fullTranslation = '';

  @override
  void initState() {
    super.initState();
    _extractTranslations();
  }

  @override
  void didUpdateWidget(covariant EnhancedMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.text != widget.message.text ||
        oldWidget.message.timestamp != widget.message.timestamp) {
      _showTranslation = false;
      _showHint = false;
      _extractTranslations();
    }
  }

  void _extractTranslations() {
    _fullTranslation = '';
    final provided = widget.message.translation;
    if (provided != null && provided.trim().isNotEmpty) {
      _fullTranslation = provided.trim();
      return;
    }

    final text = widget.message.text;
    final RegExp bracketPattern = RegExp(r'\[([^\]]+)\]');
    final matches = bracketPattern.allMatches(text);

    if (matches.isNotEmpty) {
      _fullTranslation = matches.map((match) => match.group(1) ?? '').join(' ');
    }
  }

  Widget _buildTranslation() {
    if (!_showTranslation ||
        _fullTranslation.isEmpty ||
        widget.message.isUser ||
        widget.message.isError) {
      return const SizedBox.shrink();
    }

    final translationText = _fullTranslation;
    final color = primaryAccent;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.translate_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              translationText,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintCard() {
    final hint = widget.message.hint;
    if (!_showHint ||
        hint == null ||
        hint.trim().isEmpty ||
        widget.message.isUser ||
        widget.message.isError) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryAccent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 18, color: primaryAccent.withOpacity(0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint.trim(),
              style: const TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final timeOfDay = TimeOfDay.fromDateTime(timestamp);
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final suffix = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: widget.message.isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Message bubble with width constraints
        Align(
          alignment:
              widget.message.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: widget.message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
            if (widget.message.isRoleplayStarter)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🎭 Simulation Started',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryAccent.withOpacity(0.9),
                  ),
                ),
              ),
            if (!widget.message.isUser && !widget.message.isError)
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor.withOpacity(0.2), primaryAccent.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        'assets/images/vyria.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.auto_awesome,
                            color: primaryAccent,
                            size: 18,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Vyria',
                    style: TextStyle(
                      color: primaryAccent.withOpacity(0.9),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatTimestamp(widget.message.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            if (!widget.message.isUser && !widget.message.isError)
              const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: widget.message.isUser
                    ? const LinearGradient(
                        colors: [primaryColor, primaryAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : widget.message.isError
                        ? LinearGradient(
                            colors: [Colors.redAccent, Colors.red],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.grey[50]!,
                              Colors.white,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                color: widget.message.isUser || widget.message.isError
                    ? null
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: widget.message.isUser || widget.message.isError
                    ? null
                    : Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: widget.message.isUser 
                        ? primaryColor.withOpacity(0.2)
                        : widget.message.isError
                            ? Colors.red.withOpacity(0.2)
                            : Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.text
                        .replaceAll(RegExp(r'\[.*?\]'), '')
                        .trim(),
                    style: TextStyle(
                      color: widget.message.isUser || widget.message.isError
                          ? Colors.white
                          : Colors.grey[800],
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: widget.message.isUser 
                          ? FontWeight.w500 
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.message.roleplayHints != null &&
                widget.message.roleplayHints!.isNotEmpty &&
                widget.showHints)
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
                    ...widget.message.roleplayHints!.map((hint) => Text(
                          '• $hint',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade700,
                          ),
                        )),
                  ],
                ),
              ),
            // Correction summary will be rendered outside the message bubble for full width
            if (!widget.message.isUser &&
                !widget.message.isError &&
                (widget.message.translation != null ||
                    widget.message.hint != null))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.message.hint != null &&
                        widget.message.hint!.trim().isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lightbulb_outline, size: 16),
                        label: Text(_showHint ? 'Hide hint' : 'Hint'),
                        onPressed: () {
                          setState(() {
                            _showHint = !_showHint;
                          });
                        },
                      ),
                    if (widget.message.translation != null &&
                        widget.message.translation!.trim().isNotEmpty)
                      FilledButton.icon(
                        icon: const Icon(Icons.translate_rounded, size: 16),
                        onPressed: () {
                          setState(() {
                            _showTranslation = !_showTranslation;
                          });
                        },
                        label: Text(
                          _showTranslation ? 'Hide translation' : 'Translation',
                        ),
                      ),
                  ],
                ),
              ),
            _buildTranslation(),
            _buildHintCard(),
              ],
            ),
          ),
        ),
        // Full-width correction summary outside the message bubble
        if (widget.message.correction != null)
          _CorrectionSummary(message: widget.message),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.language,
    required this.level,
    required this.points,
    required this.streak,
    required this.animation,
    required this.onSettingsTap,
    this.activeScenario,
    this.onClearScenario,
  });

  final String language;
  final String level;
  final int points;
  final int streak;
  final Animation<double> animation;
  final VoidCallback onSettingsTap;
  final String? activeScenario;
  final VoidCallback? onClearScenario;

  @override
  Widget build(BuildContext context) {
    final headerRow = Row(
      children: [
        GestureDetector(
          onTap: onSettingsTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryColor, primaryAccent],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1AF97316),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.menu_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/vyria.png',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vyria',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: primaryAccent.withOpacity(0.95),
                  ),
                ),
                Text(
                  '$language • Level $level',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        Wrap(
          spacing: 8,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return Transform.scale(
                  scale: 1 + animation.value * 0.12,
                  child: const _StatChip(
                    icon: '⭐',
                    label: '0 pts',
                  ),
                );
              },
            ),
            _StatChip(icon: '🔥', label: streak.toString()),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerRow,
          if (activeScenario != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InputChip(
                avatar: const Icon(Icons.theater_comedy, size: 18),
                label: Text(activeScenario!),
                onDeleted: onClearScenario,
                deleteIcon: onClearScenario != null
                    ? const Icon(Icons.close_rounded, size: 16)
                    : null,
                backgroundColor: primaryColor.withOpacity(0.2),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF78350F),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AF97316),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78350F),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.canSend,
    required this.placeholder,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final String placeholder;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              enableInteractiveSelection: true,
              decoration: InputDecoration(
                hintText: placeholder,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
              onSubmitted: (_) {
                if (canSend) onSend();
              },
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: canSend ? onSend : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: canSend
                    ? const LinearGradient(
                        colors: [primaryColor, primaryAccent],
                      )
                    : null,
                color: canSend ? null : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: primaryAccent.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                Icons.send_rounded,
                color: canSend ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ],
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

// --- Correction Summary as Horizontal Carousel ---
class _CorrectionSummary extends StatelessWidget {
  const _CorrectionSummary({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final correction = message.correction!;
    final grade = message.grade;

    List<Widget> carouselItems = [];

    // Grade card
    if (grade != null) {
      carouselItems.add(
        _CorrectionCard(
          icon: Icons.grade_rounded,
          title: 'Grade',
          subtitle: '${grade.letter} (${grade.score}/100)',
          content: grade.feedback,
          color: grade.color,
        ),
      );
    }

    // Suggestion card
    carouselItems.add(
      _CorrectionCard(
        icon: Icons.edit_rounded,
        title: 'Suggestion',
        subtitle: 'Corrected text',
        content: correction.corrected.isEmpty ? message.text : correction.corrected,
        color: primaryColor,
      ),
    );

    // Mistake cards
    if (correction.mistakes.isNotEmpty) {
      for (final mistake in correction.mistakes.take(2)) {
        carouselItems.add(
          _CorrectionCard(
            icon: Icons.error_outline_rounded,
            title: mistake.type,
            subtitle: '${mistake.original} → ${mistake.correction}',
            content: mistake.explanation,
            color: Colors.orange,
          ),
        );
      }
    }

    // Feedback card
    if (correction.feedback.trim().isNotEmpty) {
      carouselItems.add(
        _CorrectionCard(
          icon: Icons.feedback_rounded,
          title: 'Feedback',
          subtitle: 'Teacher comment',
          content: correction.feedback.trim(),
          color: Colors.blue,
        ),
      );
    }

    if (carouselItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
      child: SizedBox(
        height: 80, // Height for compact cards
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: carouselItems.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => carouselItems[index],
        ),
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String content;
  final Color color;

  void _showFullTextPopup(BuildContext context) {
    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 20, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitle.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Details',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Full Text',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  content,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Close button
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Error showing popup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        print('Card tapped - showing popup for: $title');
        _showFullTextPopup(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 170,
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: color.withOpacity(0.7),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
