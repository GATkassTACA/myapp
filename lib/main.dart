// lib/main.dart
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

// ====== INIT ======
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);

  tasks = await Hive.openBox('tasks');
  sessions = await Hive.openBox('sessions');
  routines = await Hive.openBox('routines');     // AM meds, water, planner, etc.
  packRules = await Hive.openBox('packRules');   // “If Wed & PE → add Gym clothes”
  settings = await Hive.openBox('settings');     // bell times, lastResetYMD
  packChecks = await Hive.openBox('packChecks'); // per-day checked items
  routineChecks = await Hive.openBox('routineChecks'); // per-day checked traits

  _seedOnce();
  _dailyResetIfNeeded();

  runApp(const MyApp());
}

// ====== HIVE BOXES ======
late Box tasks;
late Box sessions;
late Box routines;
late Box packRules;
late Box settings;
late Box packChecks;
late Box routineChecks;

// ====== UTIL ======
String newId(String prefix) => '$prefix${DateTime.now().millisecondsSinceEpoch}';
int toEpoch(DateTime d) => d.millisecondsSinceEpoch;
DateTime fromEpoch(int e) => DateTime.fromMillisecondsSinceEpoch(e);
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
String weekdayKey(DateTime d) => const ['sun','mon','tue','wed','thu','fri','sat'][0 + (d.weekday % 7)];

// ====== SEED + DAILY RESET ======
void _seedOnce() {
  if (settings.get('seeded') == true) return;
  // Minimal routines (morning checklist)
  routines.put('rt_meds',   {'id':'rt_meds','name':'AM Meds','icon':'medication','order':1});
  routines.put('rt_water',  {'id':'rt_water','name':'Water Bottle','icon':'water','order':2});
  routines.put('rt_plan',   {'id':'rt_plan','name':'Planner Signed','icon':'checklist','order':3});
  // Example pack rule: if Wednesday and has PE, add Gym clothes
  packRules.put('pk_base',  {'id':'pk_base','name':'Base','when':{},'items':['Water bottle','Planner']});
  packRules.put('pk_pe',    {'id':'pk_pe','name':'PE Day','when':{'weekday':'wed','hasClass':'PE'},'items':['Gym clothes','Deodorant']});
  settings.put('classes', <String>{'Math','Science','PE'}.toList()); // simple class list
  settings.put('seeded', true);
}

void _dailyResetIfNeeded() {
  final today = ymd(DateTime.now());
  final last = settings.get('lastResetYMD');
  if (last == today) return;
  // clear today's check maps
  routineChecks.put(today, <String, bool>{});
  packChecks.put(today, <String, bool>{});
  settings.put('lastResetYMD', today);
}

// ====== APP ======
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EvoQuest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00E5FF), brightness: Brightness.dark), scaffoldBackgroundColor: const Color(0xFF0D0F12)),
      home: const EvoQuestApp(),
    );
  }
}
// ====== APP ROOT ======
class EvoQuestApp extends StatefulWidget {
  const EvoQuestApp({super.key});
  @override
  State<EvoQuestApp> createState() => _EvoQuestAppState();
}

class _EvoQuestAppState extends State<EvoQuestApp> {
  int idx = 0;
  final screens = const [
    TodayScreen(), PlannerScreen(), PacklistScreen(), MorningChecklistScreen(), FossilsScreen()
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00E5FF), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF0D0F12),
    );
    return MaterialApp(
      title: 'EvoQuest',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: screens[idx],
        bottomNavigationBar: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => setState(() => idx = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.flash_on), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.account_tree), label: 'Planner'),
            NavigationDestination(icon: Icon(Icons.backpack), label: 'Pack'),
            NavigationDestination(icon: Icon(Icons.vaccines), label: 'Morning'),
            NavigationDestination(icon: Icon(Icons.scatter_plot), label: 'Fossils'),
          ],
        ),
      ),
    );
  }
}

// ====== TODAY: Now → Next + Timer ======
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}
class _TodayScreenState extends State<TodayScreen> {
  int minutes = 15;
  bool running = false;
  DateTime? start;
  String? activeId;

  List<Map> _openTasks() {
    final all = tasks.values.cast<Map>().toList();
    all.retainWhere((m) => (m['status'] ?? 'open') == 'open');
    all.sort((a, b) => (a['dueAt'] ?? 0).compareTo(b['dueAt'] ?? 0));
    return all;
  }

  void _start(String taskId) {
    setState(() {
      running = true;
      start = DateTime.now();
      activeId = taskId;
    });
  }

  void _finish() {
    if (!running || activeId == null || start == null) return;
    final dur = DateTime.now().difference(start!);
    final ses = {
      'id': newId('ses'),
      'taskId': activeId,
      'startedAt': toEpoch(start!),
      'endedAt': toEpoch(DateTime.now()),
      'minutes': dur.inMinutes
    };
    sessions.put(ses['id'], ses);
    setState(() { running = false; start = null; activeId = null; });
  }

  @override
  Widget build(BuildContext context) {
    final list = _openTasks();
    final now = list.isNotEmpty ? list[0] : null;
    final next = list.length > 1 ? list[1] : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Habitat: Today', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text('Now', style: Theme.of(context).textTheme.titleLarge),
          Card(
            child: ListTile(
              title: Text(now != null ? now['title'] : 'Add a task'),
              subtitle: Text(now != null && now['dueAt'] != null && now['dueAt'] != 0
                  ? 'Due ${fromEpoch(now['dueAt']).toLocal()}'
                  : 'No due date'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Next', style: Theme.of(context).textTheme.titleMedium),
          if (next != null) Card(child: ListTile(title: Text(next['title']))),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 10, label: Text('10m')),
                  ButtonSegment(value: 15, label: Text('15m')),
                  ButtonSegment(value: 25, label: Text('25m')),
                ],
                selected: {minutes},
                onSelectionChanged: (s) => setState(() => minutes = s.first),
              ),
              FilledButton.tonal(
                onPressed: running || now == null ? null : () => _start(now['id']),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text('GO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (running) FilledButton(onPressed: _finish, child: const Text('Finish Session')),
        ]),
      ),
    );
  }
}

// ====== PLANNER ======
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}
class _PlannerScreenState extends State<PlannerScreen> {
  final titleCtrl = TextEditingController();
  String? selectedClass;
  DateTime? due;

  @override
  Widget build(BuildContext context) {
    final classList = (settings.get('classes') as List).cast<String>().toList();
    final list = tasks.values.cast<Map>().toList()
      ..sort((a, b) => (a['dueAt'] ?? 0).compareTo(b['dueAt'] ?? 0));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'New task'),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: selectedClass,
              hint: const Text('Class'),
              items: [for (final c in classList) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => selectedClass = v),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Due date',
              icon: const Icon(Icons.event),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  firstDate: now.subtract(const Duration(days: 1)),
                  lastDate: now.add(const Duration(days: 365)),
                  initialDate: due ?? now,
                );
                if (picked != null) setState(() => due = picked);
              },
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.isEmpty) return;
                final id = newId('tsk');
                final map = {
                  'id': id,
                  'title': titleCtrl.text,
                  'class': selectedClass,
                  'dueAt': due != null ? toEpoch(due!) : 0,
                  'status': 'open',
                  'createdAt': DateTime.now().millisecondsSinceEpoch
                };
                tasks.put(id, map);
                titleCtrl.clear(); selectedClass = null; due = null;
                setState(() {});
              },
              child: const Text('Add'),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final t in list)
                  Card(
                    child: ListTile(
                      title: Text(t['title']),
                      subtitle: Text([
                        if (t['class'] != null) 'Class: ${t['class']}',
                        if (t['dueAt'] != null && t['dueAt'] != 0)
                          'Due: ${fromEpoch(t['dueAt']).toLocal()}'
                      ].join('  •  ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          t['status'] = 'done';
                          tasks.put(t['id'], t);
                          setState(() {});
                        },
                      ),
                    ),
                  )
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ====== PACKLIST (rule-based) ======
class PacklistScreen extends StatefulWidget {
  const PacklistScreen({super.key});
  @override
  State<PacklistScreen> createState() => _PacklistScreenState();
}
class _PacklistScreenState extends State<PacklistScreen> {
  late String todayKey;
  late Map<String, bool> checks;

  @override
  void initState() {
    super.initState();
    todayKey = ymd(DateTime.now());
    checks = Map<String, bool>.from(packChecks.get(todayKey) ?? {});
  }

  Set<String> _classesToday() {
    // simple assumption: all classes are potential; tweak if you add real schedule
    return ((settings.get('classes') as List?)?.cast<String>().toSet()) ?? <String>{};
  }

  List<String> _itemsForToday() {
    final day = weekdayKey(DateTime.now());
    final rules = packRules.values.cast<Map>().toList();
    final classSet = _classesToday();
    final out = SplayTreeSet<String>(); // sorted
    for (final r in rules) {
      final w = (r['when'] ?? {}) as Map;
      final okDay = w['weekday'] == null || w['weekday'] == day;
      final okClass = w['hasClass'] == null || classSet.contains(w['hasClass']);
      if (okDay && okClass) {
        out.addAll(((r['items'] ?? <String>[]) as List).cast<String>());
      }
    }
    return out.toList();
  }

  void _toggle(String item, bool value) {
    setState(() {
      checks[item] = value;
      packChecks.put(todayKey, checks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsForToday();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Field Kit for Today', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 12),
          for (final it in items)
            CheckboxListTile(
              value: checks[it] ?? false,
              onChanged: (v) => _toggle(it, v ?? false),
              title: Text(it),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Pack Rule (quick)'),
            onPressed: () async {
              final c = await _editQuickRule(context);
              if (c != null) {
                final id = newId('pk');
                packRules.put(id, c);
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _editQuickRule(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    String? weekday; String? needsClass;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Pack Rule'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Rule name')),
            const SizedBox(height: 8),
            TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item (comma-separated for multiple)')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: weekday, hint: const Text('Weekday (optional)'),
              items: const [
                DropdownMenuItem(value: 'mon', child: Text('Monday')),
                DropdownMenuItem(value: 'tue', child: Text('Tuesday')),
                DropdownMenuItem(value: 'wed', child: Text('Wednesday')),
                DropdownMenuItem(value: 'thu', child: Text('Thursday')),
                DropdownMenuItem(value: 'fri', child: Text('Friday')),
              ],
              onChanged: (v) => weekday = v,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: needsClass, hint: const Text('Requires class (optional)'),
              items: [
                for (final c in (settings.get('classes') as List).cast<String>())
                  DropdownMenuItem(value: c, child: Text(c))
              ],
              onChanged: (v) => needsClass = v,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty || itemCtrl.text.isEmpty) return;
              final when = <String, dynamic>{};
              if (weekday != null) when['weekday'] = weekday;
              if (needsClass != null) when['hasClass'] = needsClass;
              final items = itemCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              Navigator.pop(ctx, {'id': newId('pk'), 'name': nameCtrl.text, 'when': when, 'items': items});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ====== MORNING CHECKLIST (Traits) ======
class MorningChecklistScreen extends StatefulWidget {
  const MorningChecklistScreen({super.key});
  @override
  State<MorningChecklistScreen> createState() => _MorningChecklistScreenState();
}
class _MorningChecklistScreenState extends State<MorningChecklistScreen> {
  late String todayKey;
  late Map<String, bool> checks;

  @override
  void initState() {
    super.initState();
    todayKey = ymd(DateTime.now());
    checks = Map<String, bool>.from(routineChecks.get(todayKey) ?? {});
  }

  List<Map> _sortedRoutines() {
    final list = routines.values.cast<Map>().toList();
    list.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
    return list;
  }

  void _toggle(String id, bool v) {
    setState(() {
      checks[id] = v;
      routineChecks.put(todayKey, checks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _sortedRoutines();
    final allDone = list.isNotEmpty && list.every((r) => (checks[r['id']] ?? false));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Morning Traits', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                for (final r in list)
                  CheckboxListTile(
                    value: checks[r['id']] ?? false,
                    onChanged: (v) => _toggle(r['id'], v ?? false),
                    title: Text(r['name']),
                    secondary: const Icon(Icons.checklist),
                  ),
              ],
            ),
          ),
          if (allDone)
            const Text('Cambrian Burst unlocked 🔓', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Trait'),
                onPressed: () async {
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  routineChecks.put(todayKey, <String, bool>{});
                  setState(() => checks = {});
                },
                child: const Text('Reset today'),
              ),
            ],
          ),
        ]),
      ),
    );
  }

}

// ====== FOSSILS ======
class FossilsScreen extends StatelessWidget {
  const FossilsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final sessionsList = sessions.values.cast<Map>().toList()
      ..sort((a, b) => (b['startedAt'] ?? 0).compareTo(a['startedAt'] ?? 0));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Fossil Record', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 12),
          for (final s in sessionsList)
            ListTile(
              title: Text('Session ${s['minutes']} min'),
              subtitle: Text(fromEpoch(s['startedAt']).toLocal().toString()),
            )
        ],
      ),
    );
  }
}
