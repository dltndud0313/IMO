import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../models/routine.dart';
import '../../theme/app_theme.dart';
import '../../utils/nav.dart';
import 'routine_edit_screen.dart';
import 'routine_session_screen.dart';

class RoutineListScreen extends StatefulWidget {
  const RoutineListScreen({super.key});

  @override
  State<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends State<RoutineListScreen> {
  final _db = DatabaseHelper();
  List<Routine> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routines = await _db.getAllRoutines();
    if (!mounted) return;
    setState(() {
      _routines = routines;
      _loading = false;
    });
  }

  Future<void> _createRoutine() async {
    final created = await Nav.push<bool>(
      context,
      const RoutineEditScreen(),
    );
    if (created == true) _load();
  }

  Future<void> _editRoutine(Routine routine) async {
    final edited = await Nav.push<bool>(
      context,
      RoutineEditScreen(routine: routine),
    );
    if (edited == true) _load();
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('루틴 삭제'),
        content: Text('"${routine.name}" 루틴을 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('삭제', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    if (ok != true || routine.id == null) return;
    await _db.deleteRoutine(routine.id!);
    _load();
  }

  void _startRoutine(Routine routine) {
    if (routine.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동이 추가되지 않은 루틴입니다.')),
      );
      return;
    }
    Nav.push(context, RoutineSessionScreen(routine: routine));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운동 루틴')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createRoutine,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _routines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.list_alt,
                            size: 64, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        const Text(
                          '아직 루틴이 없어요',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '+ 버튼으로 루틴을 만들어보세요',
                          style:
                              TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _routines.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final routine = _routines[index];
                      return _RoutineCard(
                        routine: routine,
                        onTap: () => _startRoutine(routine),
                        onEdit: () => _editRoutine(routine),
                        onDelete: () => _deleteRoutine(routine),
                      );
                    },
                  ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RoutineCard({
    required this.routine,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.playlist_play,
                    color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${routine.items.length}개 운동 · 약 ${routine.estimatedMinutes}분',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('편집')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
