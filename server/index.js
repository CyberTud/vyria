import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import OpenAI from 'openai';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Vyria server is running' });
});

// Enhanced chat endpoint with grading
app.post('/chat', async (req, res) => {
  try {
    const { messages, language = 'Spanish', level = 'B1', roleplay = null, isFirstMessage = false } = req.body;

    // Get roleplay-specific or regular system message
    let systemContent = '';

    if (roleplay) {
      systemContent = `You are an expert ${language} language tutor helping a ${level} level student in a roleplay scenario.

      ROLEPLAY SCENARIO: ${roleplay.scenario}
      YOUR CHARACTER: ${roleplay.character}
      SETTING: ${roleplay.setting}

      Important instructions:
      1. Stay in character throughout the conversation
      2. ${isFirstMessage ? `Start the conversation naturally as your character would in this setting` : `Continue the roleplay naturally`}
      3. Keep the conversation context and remember previous exchanges
      4. Speak primarily in ${language} at the ${level} level

      Based on the student's level (${level}):
      ${level === 'A1' ? `- Use very simple sentences and basic vocabulary
- After EACH sentence in ${language}, add [English translation in brackets]
- Example: "Bonjour!" [Hello!] "Comment allez-vous?" [How are you?]` : ''}
      ${level === 'A2' ? `- Use simple sentences with common vocabulary
- After EACH sentence in ${language}, add [English translation in brackets]
- Example: "Je voudrais un café." [I would like a coffee.]` : ''}
      ${level === 'B1' ? `- Use moderate complexity
- Provide [English hints] for difficult phrases only` : ''}
      ${level === 'B2' ? `- Use complex sentences
- Provide [English hints] only for very difficult concepts` : ''}
      ${level === 'C1' || level === 'C2' ? '- Use natural, complex language\n- No English translations needed' : ''}

      5. Use emojis to make the roleplay engaging
      6. Keep responses concise (2-3 sentences)
      7. Encourage participation and praise efforts`;
    } else {
      systemContent = `You are an expert ${language} language tutor helping a ${level} level student.
      Your role is to:
      1. Have natural, engaging conversations in ${language}
      2. Provide detailed grammar corrections with explanations
      3. Give encouraging feedback
      4. Keep responses concise and at the appropriate level
      5. Use emojis occasionally to make learning fun
      6. Praise good attempts and progress

      Based on the student's level (${level}):
      ${level === 'A1' ? `- After EACH sentence, add [English translation in brackets]
- Example: "Hola, ¿cómo estás?" [Hello, how are you?]` : ''}
      ${level === 'A2' ? `- After EACH sentence, add [English translation in brackets]` : ''}
      ${level === 'B1' ? `- Add [English hints] for complex phrases` : ''}
      ${level === 'B2' ? `- Add [English hints] only for very difficult parts` : ''}
      ${level === 'C1' || level === 'C2' ? '- No translations needed' : ''}

      When the student makes mistakes, be supportive and explain corrections clearly.
      Respond primarily in ${language}, but use English for grammar explanations.
      Keep your responses friendly and encouraging!
      8. If the student slips into another language, gently remind them to continue in ${language}.`;
    }

    const systemMessage = {
      role: 'system',
      content: systemContent
    };

    // Get AI response
    const completion = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      messages: [systemMessage, ...messages],
      temperature: 0.7,
      max_tokens: 500,
    });

    const aiMessage = completion.choices[0].message.content?.trim() || '';

    let translation = null;
    let hint = null;

    try {
      const translationPrompt = `You are helping a ${language} tutor. Provide a JSON object with two keys: "translation" and "hint".\n- "translation": translate the assistant message into English in a natural tone.\n- "hint": briefly explain one challenging phrase from the assistant message so the student can reply better. Keep the hint to one short sentence in English.\nRespond with valid JSON only.\nAssistant message: "${aiMessage}"`;

      const helper = await openai.chat.completions.create({
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content:
              'You produce concise JSON. Never add extra text. Keys must be translation and hint.',
          },
          { role: 'user', content: translationPrompt },
        ],
        temperature: 0.2,
        max_tokens: 200,
      });

      const helperResponse = helper.choices[0].message.content || '{}';
      const parsed = JSON.parse(helperResponse);
      translation = parsed.translation || null;
      hint = parsed.hint || null;
    } catch (err) {
      console.log('Translation helper failed:', err.message);
    }

    // Enhanced correction analysis for user's last message
    let correction = null;
    let grade = null;
    let points = 0;

    if (messages.length > 0 && messages[messages.length - 1].role === 'user') {
      const userMessage = messages[messages.length - 1].content;

      // Get detailed correction and grading
      const analysisPrompt = `Analyze this ${language} text from a ${level} student: "${userMessage}"

      Respond with a JSON object containing:
      1. "hasErrors": boolean
      2. "corrected": the corrected version (or original if no errors)
      3. "mistakes": array of {type, original, correction, explanation} for each mistake
      4. "grade": letter grade (A+, A, B+, B, C+, C, D, F)
      5. "score": numerical score 0-100
      6. "feedback": encouraging feedback message
      7. "improvements": specific suggestions for improvement

      Be encouraging but accurate. Write the "corrected" in ${language}, but write "mistakes[].explanation", "feedback", and each item in "improvements" in English. Grade based on:
      - Grammar accuracy (40%)
      - Vocabulary usage (30%)
      - Sentence structure (20%)
      - Spelling (10%)
      If the student's message is not in ${language}, politely remind them to respond in ${language} and provide guidance. 

      Example response:
      {
        "hasErrors": true,
        "corrected": "Hola, ¿cómo estás?",
        "mistakes": [
          {
            "type": "spelling",
            "original": "Ola",
            "correction": "Hola",
            "explanation": "Hola needs an 'H' at the beginning"
          }
        ],
        "grade": "B+",
        "score": 85,
        "feedback": "Great attempt! Just one small spelling mistake.",
        "improvements": ["Remember to include 'H' in Hola", "Try using more vocabulary"]
      }`;

      const correctionCheck = await openai.chat.completions.create({
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a language teacher providing detailed feedback. Always respond with valid JSON only.'
          },
          {
            role: 'user',
            content: analysisPrompt
          }
        ],
        temperature: 0.3,
        max_tokens: 500,
      });

      try {
        const analysis = JSON.parse(correctionCheck.choices[0].message.content);

        if (analysis.hasErrors || analysis.score < 100) {
          correction = {
            hasErrors: analysis.hasErrors,
            corrected: analysis.corrected,
            mistakes: analysis.mistakes || [],
            feedback: analysis.feedback,
            improvements: analysis.improvements || []
          };

          grade = {
            letter: analysis.grade,
            score: analysis.score,
            feedback: analysis.feedback
          };

          // Calculate points based on score
          points = Math.floor(analysis.score / 10) * 10; // 10 points per 10% correct

          // Bonus points for attempting
          points += 5;

          // Perfect bonus
          if (analysis.score === 100) {
            points += 20; // Perfect message bonus
          }
        } else {
          // Perfect message!
          grade = {
            letter: 'A+',
            score: 100,
            feedback: '🌟 Perfect! Excellent work!'
          };
          points = 120; // 100 + 20 perfect bonus
        }
      } catch (e) {
        console.log('Could not parse correction response:', e);
      }
    }

    res.json({
      message: aiMessage,
      correction: correction,
      grade: grade,
      points: points,
      translation,
      hint,
      usage: completion.usage,
    });

  } catch (error) {
    console.error('OpenAI API error:', error);
    res.status(500).json({
      error: 'Failed to process chat request',
      details: error.message
    });
  }
});

// Get supported languages with fun facts
app.get('/languages', (req, res) => {
  res.json({
    languages: [
      { code: 'es', name: 'Spanish', flag: '🇪🇸', fact: '559 million speakers worldwide!' },
      { code: 'fr', name: 'French', flag: '🇫🇷', fact: 'Official language in 29 countries!' },
      { code: 'de', name: 'German', flag: '🇩🇪', fact: 'Most spoken native language in EU!' },
      { code: 'it', name: 'Italian', flag: '🇮🇹', fact: '85 million speakers globally!' },
      { code: 'pt', name: 'Portuguese', flag: '🇵🇹', fact: '260 million speakers worldwide!' },
      { code: 'ja', name: 'Japanese', flag: '🇯🇵', fact: '3 writing systems in one language!' },
      { code: 'zh', name: 'Chinese', flag: '🇨🇳', fact: 'Most spoken language on Earth!' },
      { code: 'ko', name: 'Korean', flag: '🇰🇷', fact: 'Scientific alphabet created in 1443!' },
    ],
    levels: [
      { code: 'A1', name: 'Beginner', description: 'Basic phrases and greetings' },
      { code: 'A2', name: 'Elementary', description: 'Simple everyday conversations' },
      { code: 'B1', name: 'Intermediate', description: 'Can handle most situations' },
      { code: 'B2', name: 'Upper Intermediate', description: 'Complex discussions' },
      { code: 'C1', name: 'Advanced', description: 'Fluent in most contexts' },
      { code: 'C2', name: 'Mastery', description: 'Near-native proficiency' }
    ]
  });
});

// Get roleplay scenarios
app.get('/roleplays', (req, res) => {
  const { language = 'Spanish', level = 'B1' } = req.query;

  const scenarios = {
    'A1': [
      {
        id: 'cafe-order',
        title: '☕ Ordering at a Café',
        scenario: 'Ordering coffee and a snack at a local café',
        character: 'A friendly barista at a cozy café',
        setting: 'A small neighborhood café in the morning',
        starter: '¡Buenos días! ¿Qué le puedo servir hoy? (Good morning! What can I serve you today?)',
        hints: ['coffee = café', 'please = por favor', 'thank you = gracias']
      },
      {
        id: 'meet-greet',
        title: '👋 Meeting Someone New',
        scenario: 'Introducing yourself to a new friend',
        character: 'A friendly new neighbor who just moved in',
        setting: 'In front of your apartment building',
        starter: '¡Hola! Soy tu nuevo vecino. (Hello! I am your new neighbor.)',
        hints: ['my name is = me llamo', 'nice to meet you = mucho gusto']
      },
      {
        id: 'directions',
        title: '🗺️ Asking for Directions',
        scenario: 'Finding your way to the train station',
        character: 'A helpful local person on the street',
        setting: 'On a busy street corner',
        starter: '¿Necesita ayuda? Parece perdido. (Need help? You seem lost.)',
        hints: ['where is = dónde está', 'turn right = gire a la derecha']
      }
    ],
    'A2': [
      {
        id: 'restaurant',
        title: '🍽️ Restaurant Reservation',
        scenario: 'Making a dinner reservation at a restaurant',
        character: 'Restaurant host taking reservations',
        setting: 'Calling a popular restaurant',
        starter: 'Buenas tardes, Restaurante La Plaza, ¿en qué puedo ayudarle?',
        hints: ['table for two = mesa para dos', 'tonight = esta noche']
      },
      {
        id: 'shopping',
        title: '🛍️ Shopping for Clothes',
        scenario: 'Buying clothes at a boutique',
        character: 'Helpful sales assistant',
        setting: 'In a clothing store',
        starter: '¡Bienvenido! ¿Busca algo especial hoy?',
        hints: ['size = talla', 'try on = probarse']
      },
      {
        id: 'doctor',
        title: '🏥 Doctor\'s Appointment',
        scenario: 'Describing symptoms to a doctor',
        character: 'Caring family doctor',
        setting: 'Doctor\'s office',
        starter: 'Buenos días, ¿cómo se siente hoy?',
        hints: ['headache = dolor de cabeza', 'fever = fiebre']
      }
    ],
    'B1': [
      {
        id: 'job-interview',
        title: '💼 Job Interview',
        scenario: 'Interviewing for your dream job',
        character: 'Professional HR manager',
        setting: 'Corporate office meeting room',
        starter: 'Bienvenido a nuestra empresa. Cuénteme sobre su experiencia profesional.',
        hints: ['skills = habilidades', 'experience = experiencia']
      },
      {
        id: 'apartment',
        title: '🏠 Apartment Viewing',
        scenario: 'Looking for a new apartment to rent',
        character: 'Real estate agent showing properties',
        setting: 'Modern apartment in the city center',
        starter: 'Este apartamento tiene dos habitaciones y una vista increíble de la ciudad.',
        hints: []
      },
      {
        id: 'complaint',
        title: '📱 Customer Service',
        scenario: 'Resolving an issue with your phone plan',
        character: 'Customer service representative',
        setting: 'Phone call to service provider',
        starter: 'Gracias por llamar. Veo aquí que tiene un problema con su factura.',
        hints: []
      }
    ],
    'B2': [
      {
        id: 'debate',
        title: '🌍 Environmental Debate',
        scenario: 'Discussing climate change solutions',
        character: 'Environmental activist at a conference',
        setting: 'Environmental summit panel discussion',
        starter: 'Creo que necesitamos acciones más drásticas para combatir el cambio climático.',
        hints: []
      },
      {
        id: 'negotiation',
        title: '💰 Business Negotiation',
        scenario: 'Negotiating a business contract',
        character: 'Experienced business partner',
        setting: 'Corporate boardroom',
        starter: 'Hemos revisado su propuesta y queremos discutir algunos términos.',
        hints: []
      }
    ],
    'C1': [
      {
        id: 'presentation',
        title: '🎤 Conference Presentation',
        scenario: 'Presenting research findings at an academic conference',
        character: 'Conference moderator',
        setting: 'International academic conference',
        starter: 'Su investigación es fascinante. ¿Podría elaborar sobre la metodología?',
        hints: []
      }
    ],
    'C2': [
      {
        id: 'philosophy',
        title: '🤔 Philosophical Discussion',
        scenario: 'Debating philosophy and ethics',
        character: 'Philosophy professor',
        setting: 'University seminar room',
        starter: 'El concepto de libre albedrío es más complejo de lo que parece inicialmente.',
        hints: []
      }
    ]
  };

  const levelScenarios = scenarios[level] || scenarios['B1'];

  res.json({
    scenarios: levelScenarios,
    currentLevel: level
  });
});

// Get learning tips
app.get('/tips', (req, res) => {
  const tips = [
    "🎯 Practice daily, even just 5 minutes helps!",
    "🗣️ Don't be afraid to make mistakes - they help you learn!",
    "📚 Read children's books in your target language",
    "🎬 Watch shows with subtitles in your target language",
    "🎵 Listen to music and learn the lyrics",
    "✍️ Keep a journal in your target language",
    "🤝 Find a language exchange partner",
    "🎮 Play games in your target language"
  ];

  res.json({
    tip: tips[Math.floor(Math.random() * tips.length)]
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✨ Vyria server running on http://0.0.0.0:${PORT}`);
  console.log(`📱 Access from devices at: http://192.168.0.115:${PORT}`);
  console.log(`🔑 OpenAI API configured with model: ${process.env.OPENAI_MODEL || 'gpt-4o-mini'}`);
  console.log(`🚀 Ready for language learning!`);
});
