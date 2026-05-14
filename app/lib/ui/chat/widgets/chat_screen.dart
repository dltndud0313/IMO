import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/chat_message.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/imo_chip.dart';
import '../../core/widgets/imo_confirm_dialog.dart';
import '../../core/widgets/imo_text_field.dart';
import '../view_model/chat_viewmodel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _shownErrorSnapshot;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _maybeShowError(BuildContext context, ChatViewModel vm) {
    final error = vm.errorMessage;
    if (error == null || error == _shownErrorSnapshot) return;
    _shownErrorSnapshot = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      vm.consumeError();
      _shownErrorSnapshot = null;
    });
  }

  Future<void> _confirmClear(BuildContext context, ChatViewModel vm) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ImoConfirmDialog(
        title: '대화 초기화',
        message: '대화 내용을 모두 삭제할까요?',
        confirmLabel: '삭제',
        danger: true,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          vm.clearHistory();
        },
      ),
    );
  }

  void _handleSend(ChatViewModel vm, String text) {
    if (text.trim().isEmpty || vm.isSending) return;
    _inputController.clear();
    vm.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatViewModel>(
      builder: (context, vm, _) {
        _maybeShowError(context, vm);
        if (vm.messages.isNotEmpty || vm.isSending) {
          _scheduleScrollToBottom();
        }

        return AppScaffold(
          title: 'AI 코치',
          showBackButton: true,
          horizontalPadding: false,
          actions: [
            IconButton(
              tooltip: '대화 초기화',
              onPressed: vm.messages.isEmpty || vm.isClearing
                  ? null
                  : () => _confirmClear(context, vm),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          body: Column(
            children: [
              Expanded(
                child: _MessageList(
                  vm: vm,
                  scrollController: _scrollController,
                  onChipTap: (text) => _handleSend(vm, text),
                ),
              ),
              _InputBar(
                controller: _inputController,
                isSending: vm.isSending,
                onSubmit: (text) => _handleSend(vm, text),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.vm,
    required this.scrollController,
    required this.onChipTap,
  });

  final ChatViewModel vm;
  final ScrollController scrollController;
  final ValueChanged<String> onChipTap;

  @override
  Widget build(BuildContext context) {
    if (vm.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.messages.isEmpty && !vm.isSending) {
      return _EmptyState(onChipTap: onChipTap);
    }

    final itemCount = vm.messages.length + (vm.isSending ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == vm.messages.length && vm.isSending) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: _TypingIndicator(),
          );
        }
        final msg = vm.messages[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: _ChatBubble(message: msg),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onChipTap});

  final ValueChanged<String> onChipTap;

  static const _examples = [
    '어깨 운동 추천해줘',
    '푸시업 폼 알려줘',
    '오늘 루틴 짜줘',
  ];

  @override
  Widget build(BuildContext context) {
    final greeting = ChatMessage(
      role: ChatRole.assistant,
      content: '안녕하세요! 운동 추천을 도와드릴게요.',
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatBubble(message: greeting, maxWidthFactor: 0.95),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final text in _examples)
                ImoChip(
                  label: text,
                  onTap: () => onChipTap(text),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.maxWidthFactor = 0.82,
  });

  final ChatMessage message;
  final double maxWidthFactor;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final maxWidth =
        MediaQuery.sizeOf(context).width * maxWidthFactor;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : AppColors.cardSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Text(
        message.content,
        style: AppTextStyles.body.copyWith(
          color: isUser ? AppColors.card : AppColors.textPrimary,
        ),
      ),
    );

    if (isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(0, -16),
          child: ClipRect(
            child: SizedBox(
              width: 96,
              height: 96,
              child: Transform.scale(
                scale: 1.4,
                child: Image.asset(
                  'assets/images/chatbot.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: bubble),
      ],
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRect(
          child: SizedBox(
            width: 96,
            height: 96,
            child: Transform.scale(
              scale: 1.4,
              child: Image.asset(
                'assets/images/chatbot.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardSubtle,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _Dot(phase: (_controller.value + i / 3) % 1),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.phase});

  final double phase;

  @override
  Widget build(BuildContext context) {
    final opacity = 0.3 + 0.7 * (1 - (phase * 2 - 1).abs()).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.textSecondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSending;
  final ValueChanged<String> onSubmit;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final canSend = hasText && !widget.isSending;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ImoTextField(
                  controller: widget.controller,
                  hint: '메시지를 입력하세요...',
                  enabled: !widget.isSending,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SendButton(
                enabled: canSend,
                onTap: () => widget.onSubmit(widget.controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryStrong],
                )
              : null,
          color: enabled ? null : AppColors.disabledBg,
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
