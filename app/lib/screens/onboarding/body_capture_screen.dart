import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../mock/default_poses.dart';
import '../../models/pose_data.dart';
import '../../models/user_profile.dart';
import '../../services/pose_detection_service.dart';
import '../../services/profile_storage.dart';
import '../../theme/app_theme.dart';
import '../avatar_test_screen.dart';

class BodyCaptureScreen extends StatefulWidget {
  final UserProfile profile;
  const BodyCaptureScreen({super.key, required this.profile});

  @override
  State<BodyCaptureScreen> createState() => _BodyCaptureScreenState();
}

class _BodyCaptureScreenState extends State<BodyCaptureScreen> {
  final _picker = ImagePicker();
  final _service = PoseDetectionService();
  final _storage = ProfileStorage();

  File? _image;
  PoseData? _pose;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
      _pose = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
      final file = File(picked.path);
      final pose = await _service.detectFromFile(file);
      if (pose == null) {
        setState(() {
          _image = file;
          _busy = false;
          _error = '관절을 감지하지 못했어요. 전신이 보이도록 다시 촬영해주세요.';
        });
        return;
      }
      setState(() {
        _image = file;
        _pose = pose;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '오류가 발생했어요: $e';
      });
    }
  }

  Future<void> _onSave() async {
    if (_pose == null) return;
    await _storage.saveProfile(widget.profile);
    await _storage.savePose(_pose!);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AvatarTestScreen(fromOnboarding: true),
      ),
    );
  }

  Future<void> _onSkip() async {
    // 테스트용: 성별에 맞는 기본 아바타 사용
    final defaultPose = DefaultPoses.byGender(widget.profile.gender);
    await _storage.saveProfile(widget.profile);
    await _storage.savePose(defaultPose);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AvatarTestScreen(fromOnboarding: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전신 촬영'),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 가이드
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: AppTheme.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '전신이 보이도록, 차렷 자세로 촬영해주세요',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: _busy
                      ? const Center(child: CircularProgressIndicator())
                      : _image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _image!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 80,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '아직 사진이 없어요',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_pose != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '관절 ${_pose!.landmarks.length}개 감지됨',
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('카메라'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('갤러리'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _pose == null || _busy ? null : _onSave,
                child: const Text('아바타 만들기'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
