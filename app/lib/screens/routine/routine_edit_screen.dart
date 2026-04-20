import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../mock/mock_data.dart';
import '../../models/routine.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exercise_icon.dart';

/// 루틴 편집(생성/수정) 화면.
class RoutineEditScreen extends StatefulWidget {
  final Routine? routine; // null이면 새로 만들기
  const RoutineEditScreen({super.key, this.routine});

  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> {
  final _db = DatabaseHelper();
  final _nameCtrl = TextEditingController();
  List<RoutineItem> _items = [];
  bool _saving = false;

  bool get _isEditing => widget.routine != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.routine!.name;
      _items = List.from(widget.routine!.items);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addExercise() {
    // 전체 운동 목록에서 선택
    final exercises = MockData.workoutExercises;
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.separated(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        itemCount: exercises.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final ex = exercises[i];
          return ListTile(
            leading: ExerciseIcon(
              exerciseId: ex.id,
              size: 36,
              color: AppTheme.primary,
            ),
            title: Text(ex.name),
            subtitle: Text(ex.description),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _items.add(RoutineItem(
                  exerciseId: ex.id,
                  sets: 3,
                  targetReps: 12,
                  restSeconds: 60,
                  sortOrder: _items.length,
                ));
              });
            },
          );
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _editItem(int index) {
    final item = _items[index];
    final setsCtrl =
        TextEditingController(text: item.sets.toString());
    final repsCtrl =
        TextEditingController(text: item.targetReps.toString());
    final restCtrl =
        TextEditingController(text: item.restSeconds.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_exerciseName(item.exerciseId)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '세트 수'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: repsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '목표 반복수'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: restCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '휴식 시간(초)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _items[index] = item.copyWith(
                  sets: int.tryParse(setsCtrl.text) ?? item.sets,
                  targetReps:
                      int.tryParse(repsCtrl.text) ?? item.targetReps,
                  restSeconds:
                      int.tryParse(restCtrl.text) ?? item.restSeconds,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _exerciseName(String exerciseId) {
    final all = MockData.workoutExercises;
    final match = all.where((e) => e.id == exerciseId);
    return match.isNotEmpty ? match.first.name : exerciseId;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('루틴 이름을 입력해주세요')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('운동을 하나 이상 추가해주세요')),
      );
      return;
    }
    setState(() => _saving = true);

    final routine = Routine(
      id: widget.routine?.id,
      name: name,
      createdAt: widget.routine?.createdAt ?? DateTime.now(),
      items: _items,
    );

    if (_isEditing) {
      await _db.updateRoutine(routine);
    } else {
      await _db.insertRoutine(routine);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '루틴 편집' : '루틴 만들기'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              '저장',
              style: TextStyle(
                color: _saving ? AppTheme.textSecondary : AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 루틴 이름
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '루틴 이름',
                hintText: '예: 상체 루틴',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  '운동 목록',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text(
                  '운동을 추가해주세요',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                onReorder: (old, newIdx) {
                  setState(() {
                    if (newIdx > old) newIdx--;
                    final item = _items.removeAt(old);
                    _items.insert(newIdx, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    key: ValueKey('item_$index'),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle,
                            color: AppTheme.textSecondary),
                      ),
                      title: Text(_exerciseName(item.exerciseId)),
                      subtitle: Text(
                        '${item.sets}세트 × ${item.targetReps}회 · 휴식 ${item.restSeconds}초',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit,
                                size: 20,
                                color: AppTheme.textSecondary),
                            onPressed: () => _editItem(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 20, color: AppTheme.accent),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
