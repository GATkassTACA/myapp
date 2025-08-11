import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// --- DATA MODELS ---

// Represents a single task or chore for the user to complete.
class Quest {
  final String id;
  final String title;
  final String description;
  final int xp;
  bool isCompleted;

  Quest({
    required this.id,
    required this.title,
    this.description = '',
    required this.xp,
    this.isCompleted = false,
  });
}

// Represents the user's evolving creature.
class Creature {
  String name;
  int level;
  int currentXp;
  int xpToNextLevel;

  Creature({
    required this.name,
    this.level = 1,
    this.currentXp = 0,
    this.xpToNextLevel = 100,
  });

  void addXp(int xp) {
    currentXp += xp;
    if (currentXp >= xpToNextLevel) {
      levelUp();
    }
  }

  void levelUp() {
    level++;
    currentXp = currentXp - xpToNextLevel;
    xpToNextLevel = (xpToNextLevel * 1.5).round();
  }
}

// --- STATE MANAGEMENT (PROVIDERS) ---

class QuestProvider with ChangeNotifier {
  final List<Quest> _quests = [
    Quest(id: '1', title: 'Brush Teeth', description: 'Morning and night!', xp: 10),
    Quest(id: '2', title: 'Make Bed', xp: 5),
    Quest(id: '3', title: 'Get Dressed for School', xp: 10),
    Quest(id: '4', title: 'Pack School Bag', xp: 15),
    Quest(id: '5', title: 'Do Homework', xp: 30),
  ];

  List<Quest> get quests => _quests;

  void toggleQuestCompletion(String id) {
    final quest = _quests.firstWhere((q) => q.id == id);
    quest.isCompleted = !quest.isCompleted;
    notifyListeners();
  }
}

class CreatureProvider with ChangeNotifier {
  final Creature _creature = Creature(name: 'Sparky');

  Creature get creature => _creature;

  void completeQuest(Quest quest) {
    if (!quest.isCompleted) {
      // Ensure we don't give XP for un-completing
      return;
    }
    _creature.addXp(quest.xp);
    notifyListeners();
  }
}


// --- MAIN APP ---

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuestProvider()),
        ChangeNotifierProvider(create: (_) => CreatureProvider()),
      ],
      child: const EvoQuestApp(),
    ),
  );
}

class EvoQuestApp extends StatelessWidget {
  const EvoQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primarySeedColor = Colors.teal;

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: primarySeedColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );

    return MaterialApp(
      title: 'Evo-Quest',
      theme: lightTheme,
      home: const HomePage(),
    );
  }
}

// --- UI WIDGETS ---

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evo-Quest'),
      ),
      body: const Column(
        children: [
          CreatureStatusView(),
          Expanded(
            child: QuestListView(),
          ),
        ],
      ),
    );
  }
}

class CreatureStatusView extends StatelessWidget {
  const CreatureStatusView({super.key});

  @override
  Widget build(BuildContext context) {
    final creatureProvider = Provider.of<CreatureProvider>(context);
    final creature = creatureProvider.creature;

    double xpPercentage = creature.currentXp / creature.xpToNextLevel;

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(creature.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Level ${creature.level}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: xpPercentage,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 8),
            Text('${creature.currentXp} / ${creature.xpToNextLevel} XP'),
          ],
        ),
      ),
    );
  }
}


class QuestListView extends StatelessWidget {
  const QuestListView({super.key});

  @override
  Widget build(BuildContext context) {
    final questProvider = Provider.of<QuestProvider>(context);
    final creatureProvider = Provider.of<CreatureProvider>(context);

    return ListView.builder(
      itemCount: questProvider.quests.length,
      itemBuilder: (context, index) {
        final quest = questProvider.quests[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ListTile(
            title: Text(quest.title),
            subtitle: Text('${quest.xp} XP'),
            trailing: Checkbox(
              value: quest.isCompleted,
              onChanged: (bool? value) {
                if (value != null) {
                  questProvider.toggleQuestCompletion(quest.id);
                  // Use the updated quest state to add XP
                  final updatedQuest = questProvider.quests.firstWhere((q) => q.id == quest.id);
                  creatureProvider.completeQuest(updatedQuest);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
