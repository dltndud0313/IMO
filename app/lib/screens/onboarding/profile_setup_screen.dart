import 'package:flutter/material.dart';

import '../../mock/default_poses.dart';
import '../../models/user_profile.dart';
import '../../services/profile_storage.dart';
import '../../theme/app_theme.dart';
import '../home_screen.dart';
import 'body_capture_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = 'M';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSkip() async {
    // 테스트용: 기본 프로필 + 기본 남성 아바타로 바로 홈
    final storage = ProfileStorage();
    await storage.saveProfile(const UserProfile(
      name: '게스트',
      heightCm: 170,
      weightKg: 65,
      age: 25,
      gender: 'M',
    ));
    await storage.savePose(DefaultPoses.male);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _onNext() {
    if (!_formKey.currentState!.validate()) return;
    final profile = UserProfile(
      name: _nameCtrl.text.trim(),
      heightCm: double.parse(_heightCtrl.text),
      weightKg: double.parse(_weightCtrl.text),
      age: int.parse(_ageCtrl.text),
      gender: _gender,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BodyCaptureScreen(profile: profile),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? '필수 항목입니다' : null;

  String? _number(String? v) {
    if (v == null || v.trim().isEmpty) return '필수 항목입니다';
    if (double.tryParse(v) == null) return '숫자만 입력해주세요';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 입력'),
        actions: [
          TextButton(
            onPressed: _onSkip,
            child: const Text(
              '건너뛰기',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  '안녕하세요!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  '맞춤 운동 분석을 위해 정보를 입력해주세요',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '키 (cm)',
                    border: OutlineInputBorder(),
                  ),
                  validator: _number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '체중 (kg)',
                    border: OutlineInputBorder(),
                  ),
                  validator: _number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '나이',
                    border: OutlineInputBorder(),
                  ),
                  validator: _number,
                ),
                const SizedBox(height: 16),
                const Text('성별', style: TextStyle(fontSize: 14)),
                RadioGroup<String>(
                  groupValue: _gender,
                  onChanged: (v) => setState(() => _gender = v ?? 'M'),
                  child: Row(
                    children: const [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('남성'),
                          value: 'M',
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('여성'),
                          value: 'F',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _onNext,
                  child: const Text('다음'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
