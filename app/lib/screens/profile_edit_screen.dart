import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_storage.dart';

/// 프로필 편집 화면.
/// 기존 프로필 값을 불러와서 폼에 채워놓고, 수정 후 저장.
class ProfileEditScreen extends StatefulWidget {
  final UserProfile profile;
  const ProfileEditScreen({super.key, required this.profile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _ageCtrl;
  late String _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p.name);
    _heightCtrl =
        TextEditingController(text: p.heightCm.toStringAsFixed(0));
    _weightCtrl =
        TextEditingController(text: p.weightKg.toStringAsFixed(0));
    _ageCtrl = TextEditingController(text: p.age.toString());
    _gender = p.gender.isNotEmpty ? p.gender : 'M';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? '필수 항목입니다' : null;

  String? _number(String? v) {
    if (v == null || v.trim().isEmpty) return '필수 항목입니다';
    if (double.tryParse(v) == null) return '숫자만 입력해주세요';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = UserProfile(
      name: _nameCtrl.text.trim(),
      heightCm: double.parse(_heightCtrl.text),
      weightKg: double.parse(_weightCtrl.text),
      age: int.parse(_ageCtrl.text),
      gender: _gender,
    );
    await ProfileStorage().saveProfile(updated);
    if (!mounted) return;
    Navigator.pop(context, true); // true = 변경됨
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 편집')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'M', label: Text('남성')),
                    ButtonSegment(value: 'F', label: Text('여성')),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (s) =>
                      setState(() => _gender = s.first),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('저장'),
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
