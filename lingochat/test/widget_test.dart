// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vyria/main.dart';

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:3000');
  });

  testWidgets('renders Vyria chat header', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatServiceProvider.overrideWithValue(_FakeChatService()),
        ],
        child: const VyriaApp(),
      ),
    );

    // Allow the first frame to paint.
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.textContaining('Vyria'), findsWidgets);
  });
}

class _FakeChatService extends ChatService {
  @override
  Future<ChatResponse> sendMessage(
    List<Map<String, String>> messages,
    String language,
    String level, {
    RoleplayScenario? roleplay,
    bool isFirstMessage = false,
  }) async {
    return ChatResponse(message: '¡Hola!', points: 5);
  }

  @override
  Future<Map<String, dynamic>> getLanguages() async {
    return {
      'languages': [
        {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸'}
      ],
      'levels': ['A1', 'A2', 'B1'],
    };
  }

  @override
  Future<List<RoleplayScenario>> getRoleplays(
      String language, String level) async {
    return [
      RoleplayScenario(
        id: 'test',
        title: 'Test Scenario',
        scenario: 'Practice greetings',
        character: 'Friendly tutor',
        setting: 'Test lab',
        starter: 'Hola, ¿cómo estás?',
        hints: const ['hola = hello'],
      ),
    ];
  }
}
