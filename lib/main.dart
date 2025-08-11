import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- DATA MODELS ---

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

  void addQuest(Quest quest) {
    _quests.add(quest);
    notifyListeners();
  }

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
    if (quest.isCompleted) {
       _creature.addXp(quest.xp);
    } else {
      // If quest is un-checked, subtract XP
      _creature.currentXp -= quest.xp;
      if (_creature.currentXp < 0) {
        _creature.currentXp = 0;
      }
    }
    notifyListeners();
  }
}


// --- MAIN APP ---

Future<void> main() async {
  // Ensure Flutter is ready.
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Hive for Flutter.
  await Hive.initFlutter();
  
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
    const Color primarySeedColor = Colors.teal;

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.light,
        primary: primarySeedColor,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: primarySeedColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold),
      ),
       elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primarySeedColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w500),
        ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddQuestDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Add Quest',
      ),
    );
  }

  void _showAddQuestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final xpController = TextEditingController();

        return AlertDialog(
          title: const Text('Add a New Quest'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Quest Title'),
              ),
              TextField(
                controller: xpController,
                decoration: const InputDecoration(labelText: 'XP Value'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final String title = titleController.text;
                final int? xp = int.tryParse(xpController.text);

                if (title.isNotEmpty && xp != null) {
                  final newQuest = Quest(
                    id: DateTime.now().toString(),
                    title: title,
                    xp: xp,
                  );
                  context.read<QuestProvider>().addQuest(newQuest);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class CreatureStatusView extends StatelessWidget {
  const CreatureStatusView({super.key});

  @override
  Widget build(BuildContext context) {
    final creature = context.watch<CreatureProvider>().creature;

    double xpPercentage = (creature.xpToNextLevel > 0) 
        ? creature.currentXp / creature.xpToNextLevel
        : 0;

    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(creature.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Level ${creature.level}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: xpPercentage),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
              ),
            ),
            const SizedBox(height: 8),
            Text('${creature.currentXp} / ${creature.xpToNextLevel} XP', style: Theme.of(context).textTheme.bodyLarge),
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
    final questProvider = context.watch<QuestProvider>();
    final creatureProvider = context.read<CreatureProvider>();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: questProvider.quests.length,
      itemBuilder: (context, index) {
        final quest = questProvider.quests[index];
        return Card(
           margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
           elevation: 4.0,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            title: Text(quest.title, style: TextStyle(decoration: quest.isCompleted ? TextDecoration.lineThrough : null)),
            subtitle: Text('${quest.xp} XP'),
            trailing: Checkbox(
              value: quest.isCompleted,
              onChanged: (bool? value) {
                if (value != null) {
                  questProvider.toggleQuestCompletion(quest.id);
                  creatureProvider.completeQuest(quest);
                }
              },
               activeColor: Colors.teal,
            ),
          ),
        );
      },
    );
  }
}
