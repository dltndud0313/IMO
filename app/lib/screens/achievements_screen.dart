import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../theme/app_theme.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Set<String> _unlocked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AchievementService().getUnlocked();
    if (!mounted) return;
    setState(() {
      _unlocked = u;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = AchievementService.all;
    final unlockedCount = _unlocked.length;
    final totalCount = all.length;

    return Scaffold(
      appBar: AppBar(title: const Text('뱃지')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // 진행률 헤더
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events,
                                color: AppTheme.warning, size: 40),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$unlockedCount / $totalCount 달성',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: totalCount == 0
                                          ? 0
                                          : unlockedCount / totalCount,
                                      minHeight: 8,
                                      backgroundColor: AppTheme.border,
                                      valueColor:
                                          const AlwaysStoppedAnimation(
                                              AppTheme.warning),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: all.length,
                      itemBuilder: (_, i) {
                        final a = all[i];
                        final unlocked = _unlocked.contains(a.id);
                        return _BadgeCard(achievement: a, unlocked: unlocked);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  const _BadgeCard({required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? achievement.color : AppTheme.textSecondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: unlocked ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                unlocked ? achievement.icon : Icons.lock_outline,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              achievement.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
