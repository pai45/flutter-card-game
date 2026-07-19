import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/match_circle/match_circle_cubit.dart';
import '../../blocs/match_circle/match_circle_state.dart';
import '../../config/theme.dart';
import '../../models/avatar_option.dart';
import '../../models/match_circle.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/match_summary_header.dart';

/// Text-only, device-local discussion attached to one sporting fixture.
class MatchCircleScreen extends StatefulWidget {
  const MatchCircleScreen({required this.match, super.key});

  final SportMatch match;

  @override
  State<MatchCircleScreen> createState() => _MatchCircleScreenState();
}

class _MatchCircleScreenState extends State<MatchCircleScreen> {
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocus = FocusNode();

  MatchCirclePost? _replyingTo;
  String? _replyParentId;
  MatchCirclePost? _editingPost;
  String _draftBeforeEdit = '';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<MatchCircleCubit>().ensureThread(widget.match));
    });
  }

  @override
  void didUpdateWidget(covariant MatchCircleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (matchCircleThreadKey(oldWidget.match) ==
        matchCircleThreadKey(widget.match)) {
      return;
    }
    _composerController.clear();
    _replyingTo = null;
    _replyParentId = null;
    _editingPost = null;
    _draftBeforeEdit = '';
    _validationError = null;
    unawaited(context.read<MatchCircleCubit>().ensureThread(widget.match));
  }

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _startReply(MatchCirclePost post) {
    if (_editingPost != null) {
      _composerController.text = _draftBeforeEdit;
      _draftBeforeEdit = '';
      _editingPost = null;
    }
    setState(() {
      _replyingTo = post;
      _replyParentId = post.parentId ?? post.id;
      _validationError = null;
    });
    _focusComposer();
  }

  void _startEdit(MatchCirclePost post) {
    if (_editingPost == null) {
      _draftBeforeEdit = _composerController.text;
    }
    _composerController
      ..text = post.text
      ..selection = TextSelection.collapsed(offset: post.text.length);
    setState(() {
      _editingPost = post;
      _replyingTo = null;
      _replyParentId = null;
      _validationError = null;
    });
    _focusComposer();
  }

  void _cancelComposerMode() {
    if (_editingPost != null) {
      _composerController
        ..text = _draftBeforeEdit
        ..selection = TextSelection.collapsed(offset: _draftBeforeEdit.length);
    }
    setState(() {
      _replyingTo = null;
      _replyParentId = null;
      _editingPost = null;
      _draftBeforeEdit = '';
      _validationError = null;
    });
  }

  void _focusComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  void _focusNewComment() {
    _cancelComposerMode();
    _focusComposer();
  }

  Future<void> _submit() async {
    final text = _composerController.text.trim();
    if (text.isEmpty) {
      setState(() => _validationError = 'Write something before posting.');
      _focusComposer();
      return;
    }
    if (text.length > matchCirclePostMaxLength) {
      setState(
        () => _validationError = 'Comments can be up to 500 characters.',
      );
      _focusComposer();
      return;
    }

    final cubit = context.read<MatchCircleCubit>();
    if (cubit.mutating(widget.match)) return;

    final editing = _editingPost;
    final parentId = _replyParentId;
    final success = editing != null
        ? await cubit.editPost(widget.match, postId: editing.id, text: text)
        : parentId != null
        ? await cubit.addReply(widget.match, parentId: parentId, text: text)
        : await cubit.addComment(widget.match, text);

    if (!mounted || !success) return;
    final restoredDraft = editing == null ? '' : _draftBeforeEdit;
    _composerController
      ..text = restoredDraft
      ..selection = TextSelection.collapsed(offset: restoredDraft.length);
    setState(() {
      _replyingTo = null;
      _replyParentId = null;
      _editingPost = null;
      _draftBeforeEdit = '';
      _validationError = null;
    });
  }

  Future<void> _deletePost(MatchCirclePost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const CyberConfirmDialog(
        title: 'Delete comment?',
        message:
            'This cannot be undone. Replies will remain under a deleted-comment marker.',
        confirmLabel: 'DELETE',
        cancelLabel: 'CANCEL',
        destructive: true,
      ),
    );
    if (!mounted || confirmed != true) return;

    final success = await context.read<MatchCircleCubit>().deletePost(
      widget.match,
      post.id,
    );
    if (!mounted || !success) return;
    if (_editingPost?.id == post.id || _replyingTo?.id == post.id) {
      _cancelComposerMode();
    }
  }

  Future<void> _retry() async {
    final cubit = context.read<MatchCircleCubit>();
    cubit.clearError(widget.match);
    await cubit.ensureThread(widget.match);
  }

  void _onComposerChanged(String _) {
    final cubit = context.read<MatchCircleCubit>();
    if (cubit.error(widget.match) != null) cubit.clearError(widget.match);
    if (mounted) setState(() => _validationError = null);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      key: const ValueKey('match-circle-screen'),
      resizeToAvoidBottomInset: true,
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: BlocConsumer<MatchCircleCubit, MatchCircleState>(
            listenWhen: (previous, current) =>
                previous.error(widget.match) != current.error(widget.match),
            listener: (context, state) {
              final message = state.error(widget.match);
              if (message == null) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(message, style: Cyber.body(13)),
                    backgroundColor: const Color(0xff311922),
                  ),
                );
            },
            builder: (context, state) {
              final thread = state.threadFor(widget.match);
              final loading = state.loading(widget.match);
              final mutating = state.mutating(widget.match);
              final error = state.error(widget.match);
              return Column(
                children: [
                  const _MatchCircleTopBar(),
                  if (!keyboardVisible) MatchSummaryHeader(match: widget.match),
                  const _CircleDivider(),
                  Expanded(
                    child: _DiscussionBody(
                      thread: thread,
                      loading: loading,
                      error: error,
                      currentAuthor: state.currentAuthor,
                      mutating: mutating,
                      onRetry: _retry,
                      onStartComment: _focusNewComment,
                      onLike: (post) => unawaited(
                        context.read<MatchCircleCubit>().toggleLike(
                          widget.match,
                          post.id,
                        ),
                      ),
                      onReply: _startReply,
                      onEdit: _startEdit,
                      onDelete: _deletePost,
                    ),
                  ),
                  _MatchCircleComposer(
                    controller: _composerController,
                    focusNode: _composerFocus,
                    replyingTo: _replyingTo,
                    editingPost: _editingPost,
                    validationError: _validationError,
                    persistenceError: thread == null ? null : error,
                    enabled:
                        thread != null &&
                        state.currentAuthor != null &&
                        !mutating,
                    mutating: mutating,
                    onChanged: _onComposerChanged,
                    onCancelMode: _cancelComposerMode,
                    onSubmit: _submit,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MatchCircleTopBar extends StatelessWidget {
  const _MatchCircleTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back to matches',
            child: InkResponse(
              key: const ValueKey('match-circle-back'),
              onTap: () => Navigator.of(context).maybePop(),
              radius: 24,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Cyber.cyan,
                  size: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'BACK TO MATCHES',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(14, weight: FontWeight.w800),
            ),
          ),
          const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.forum_outlined, color: Cyber.cyan, size: 20),
          ),
        ],
      ),
    );
  }
}

class _CircleDivider extends StatelessWidget {
  const _CircleDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Cyber.cyan.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _DiscussionBody extends StatelessWidget {
  const _DiscussionBody({
    required this.thread,
    required this.loading,
    required this.error,
    required this.currentAuthor,
    required this.mutating,
    required this.onRetry,
    required this.onStartComment,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  final MatchCircleThread? thread;
  final bool loading;
  final String? error;
  final MatchCircleAuthor? currentAuthor;
  final bool mutating;
  final Future<void> Function() onRetry;
  final VoidCallback onStartComment;
  final ValueChanged<MatchCirclePost> onLike;
  final ValueChanged<MatchCirclePost> onReply;
  final ValueChanged<MatchCirclePost> onEdit;
  final ValueChanged<MatchCirclePost> onDelete;

  @override
  Widget build(BuildContext context) {
    if (thread == null && loading) {
      return const Center(
        key: ValueKey('match-circle-loading'),
        child: CircularProgressIndicator(color: Cyber.cyan),
      );
    }
    if (thread == null && error != null) {
      return CyberNoDataState(
        key: const ValueKey('match-circle-error'),
        icon: Icons.sync_problem,
        title: 'Circle unavailable',
        message: error!,
        accent: Cyber.danger,
        spark: Icons.refresh,
        actionLabel: 'RETRY',
        actionIcon: Icons.refresh,
        onAction: () => unawaited(onRetry()),
      );
    }
    if (thread == null) {
      return const Center(child: CircularProgressIndicator(color: Cyber.cyan));
    }

    final posts = thread!.topLevelPosts;
    if (posts.isEmpty) {
      return CyberNoDataState(
        key: const ValueKey('match-circle-empty'),
        icon: Icons.forum_outlined,
        title: 'Start the circle',
        message: 'Be the first to talk about this match.',
        accent: Cyber.cyan,
        spark: Icons.add_comment_outlined,
        actionLabel: 'WRITE A COMMENT',
        actionIcon: Icons.edit_outlined,
        onAction: onStartComment,
      );
    }

    return RefreshIndicator(
      color: Cyber.cyan,
      backgroundColor: Cyber.panel,
      onRefresh: onRetry,
      child: ListView.builder(
        key: const ValueKey('match-circle-feed'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final replies = thread!.repliesFor(post.id);
          final owned = currentAuthor != null && post.isOwnedBy(currentAuthor!);
          return _DiscussionThread(
            key: ValueKey('match-circle-post-${post.id}'),
            post: post,
            replies: replies,
            currentAuthor: currentAuthor,
            owned: owned,
            disabled: mutating,
            onLike: onLike,
            onReply: post.isDeleted ? null : onReply,
            onEdit: owned ? onEdit : null,
            onDelete: owned ? onDelete : null,
          );
        },
      ),
    );
  }
}

class _DiscussionThread extends StatelessWidget {
  const _DiscussionThread({
    required this.post,
    required this.replies,
    required this.currentAuthor,
    required this.owned,
    required this.disabled,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final MatchCirclePost post;
  final List<MatchCirclePost> replies;
  final MatchCircleAuthor? currentAuthor;
  final bool owned;
  final bool disabled;
  final ValueChanged<MatchCirclePost> onLike;
  final ValueChanged<MatchCirclePost>? onReply;
  final ValueChanged<MatchCirclePost>? onEdit;
  final ValueChanged<MatchCirclePost>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Cyber.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        children: [
          _PostTile(
            post: post,
            currentAuthor: currentAuthor,
            owned: owned,
            disabled: disabled,
            onLike: onLike,
            onReply: onReply,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Cyber.cyan.withValues(alpha: 0.25)),
                  ),
                ),
                child: Column(
                  children: [
                    for (final reply in replies)
                      _PostTile(
                        key: ValueKey('match-circle-post-${reply.id}'),
                        post: reply,
                        currentAuthor: currentAuthor,
                        owned:
                            currentAuthor != null &&
                            reply.isOwnedBy(currentAuthor!),
                        disabled: disabled,
                        compact: true,
                        onLike: onLike,
                        onReply: post.isDeleted ? null : onReply,
                        onEdit:
                            currentAuthor != null &&
                                reply.isOwnedBy(currentAuthor!)
                            ? onEdit
                            : null,
                        onDelete:
                            currentAuthor != null &&
                                reply.isOwnedBy(currentAuthor!)
                            ? onDelete
                            : null,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.post,
    required this.currentAuthor,
    required this.owned,
    required this.disabled,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
    super.key,
  });

  final MatchCirclePost post;
  final MatchCircleAuthor? currentAuthor;
  final bool owned;
  final bool disabled;
  final bool compact;
  final ValueChanged<MatchCirclePost> onLike;
  final ValueChanged<MatchCirclePost>? onReply;
  final ValueChanged<MatchCirclePost>? onEdit;
  final ValueChanged<MatchCirclePost>? onDelete;

  @override
  Widget build(BuildContext context) {
    final liked = currentAuthor != null && post.isLikedBy(currentAuthor!.id);
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 2, 12, 2, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostAvatar(
            post: post,
            currentAuthor: currentAuthor,
            size: compact ? 32 : 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.isDeleted
                            ? 'DELETED COMMENT'
                            : post.author.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.body(
                          compact ? 12 : 13,
                          color: post.isDeleted ? Cyber.muted : Colors.white,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _relativeTime(post.createdAt),
                      style: Cyber.body(10, color: Cyber.muted),
                    ),
                    if (!post.isDeleted && owned) ...[
                      const SizedBox(width: 2),
                      _OwnedPostMenu(
                        post: post,
                        enabled: !disabled,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  post.isDeleted ? 'This comment was deleted.' : post.text,
                  style:
                      Cyber.body(
                        compact ? 12 : 13,
                        color: post.isDeleted ? Cyber.muted : Colors.white,
                        weight: post.isDeleted
                            ? FontWeight.w500
                            : FontWeight.w600,
                        height: 1.45,
                      ).copyWith(
                        fontStyle: post.isDeleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                ),
                if (!post.isDeleted) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 2,
                    runSpacing: 0,
                    children: [
                      _PostAction(
                        key: ValueKey('match-circle-like-${post.id}'),
                        semanticLabel: liked
                            ? 'Unlike comment'
                            : 'Like comment',
                        icon: liked ? Icons.favorite : Icons.favorite_border,
                        label: post.likes == 0 ? 'LIKE' : '${post.likes}',
                        active: liked,
                        enabled: !disabled && currentAuthor != null,
                        onTap: () => onLike(post),
                      ),
                      if (onReply != null)
                        _PostAction(
                          key: ValueKey('match-circle-reply-${post.id}'),
                          semanticLabel: 'Reply to ${post.author.displayName}',
                          icon: Icons.chat_bubble_outline,
                          label: 'REPLY',
                          enabled: !disabled,
                          onTap: () => onReply!(post),
                        ),
                      if (post.isEdited)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 17,
                          ),
                          child: Text(
                            'EDITED',
                            style: Cyber.label(
                              8,
                              color: Cyber.muted,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostAvatar extends StatelessWidget {
  const _PostAvatar({
    required this.post,
    required this.currentAuthor,
    required this.size,
  });

  final MatchCirclePost post;
  final MatchCircleAuthor? currentAuthor;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (post.isDeleted) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(color: Cyber.border),
        ),
        child: Icon(Icons.person_off_outlined, color: Cyber.muted, size: 17),
      );
    }
    final author = currentAuthor?.id == post.author.id
        ? currentAuthor!
        : post.author;
    final avatar = avatarOptionById(author.avatarId);
    return Semantics(
      image: true,
      label: '${author.displayName} avatar',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(
            color: currentAuthor?.id == post.author.id
                ? Cyber.cyan
                : Cyber.border,
          ),
        ),
        child: Image.asset(
          avatar.assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Icon(Icons.person, color: Cyber.muted, size: size * 0.58),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.semanticLabel,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final String semanticLabel;
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Cyber.cyan : Cyber.muted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 24,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: enabled ? color : Cyber.border),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Cyber.label(
                    9,
                    color: enabled ? color : Cyber.border,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _OwnedPostAction { edit, delete }

class _OwnedPostMenu extends StatelessWidget {
  const _OwnedPostMenu({
    required this.post,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final MatchCirclePost post;
  final bool enabled;
  final ValueChanged<MatchCirclePost>? onEdit;
  final ValueChanged<MatchCirclePost>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Comment options',
      child: SizedBox(
        width: 48,
        height: 48,
        child: PopupMenuButton<_OwnedPostAction>(
          key: ValueKey('match-circle-menu-${post.id}'),
          enabled: enabled,
          padding: EdgeInsets.zero,
          tooltip: 'Comment options',
          color: Cyber.panel,
          icon: Icon(
            Icons.more_horiz,
            size: 19,
            color: enabled ? Cyber.muted : Cyber.border,
          ),
          onSelected: (action) {
            switch (action) {
              case _OwnedPostAction.edit:
                onEdit?.call(post);
              case _OwnedPostAction.delete:
                onDelete?.call(post);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _OwnedPostAction.edit,
              height: 48,
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, color: Cyber.cyan, size: 18),
                  const SizedBox(width: 10),
                  Text('EDIT', style: Cyber.label(10, letterSpacing: 1)),
                ],
              ),
            ),
            PopupMenuItem(
              value: _OwnedPostAction.delete,
              height: 48,
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    color: Cyber.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'DELETE',
                    style: Cyber.label(
                      10,
                      color: Cyber.danger,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCircleComposer extends StatelessWidget {
  const _MatchCircleComposer({
    required this.controller,
    required this.focusNode,
    required this.replyingTo,
    required this.editingPost,
    required this.validationError,
    required this.persistenceError,
    required this.enabled,
    required this.mutating,
    required this.onChanged,
    required this.onCancelMode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final MatchCirclePost? replyingTo;
  final MatchCirclePost? editingPost;
  final String? validationError;
  final String? persistenceError;
  final bool enabled;
  final bool mutating;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancelMode;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final target = editingPost ?? replyingTo;
    final modeLabel = editingPost != null
        ? 'EDITING YOUR COMMENT'
        : replyingTo != null
        ? 'REPLYING TO ${replyingTo!.author.displayName.toUpperCase()}'
        : null;
    final error = validationError ?? persistenceError;

    return Material(
      key: const ValueKey('match-circle-composer'),
      color: const Color(0xff10192b),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Cyber.cyan.withValues(alpha: 0.25)),
          ),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (target != null)
                _ComposerModeBanner(label: modeLabel!, onCancel: onCancelMode),
              if (error != null) ...[
                Padding(
                  key: const ValueKey('match-circle-composer-error'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Cyber.danger,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          error,
                          style: Cyber.body(11, color: Cyber.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const ValueKey('match-circle-composer-field'),
                          controller: controller,
                          focusNode: focusNode,
                          enabled: enabled,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: matchCirclePostMaxLength,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onChanged: onChanged,
                          style: Cyber.body(13, height: 1.35),
                          cursorColor: Cyber.cyan,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) => const SizedBox.shrink(),
                          decoration: InputDecoration(
                            hintText: editingPost != null
                                ? 'Update your comment'
                                : replyingTo != null
                                ? 'Write a reply'
                                : 'Join the Match Circle',
                            hintStyle: Cyber.body(13, color: Cyber.muted),
                            filled: true,
                            fillColor: Cyber.bg2.withValues(alpha: 0.92),
                            contentPadding: const EdgeInsets.fromLTRB(
                              12,
                              11,
                              12,
                              9,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Cyber.border.withValues(alpha: 0.85),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Cyber.cyan),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Cyber.border.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 4),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${controller.text.length}/$matchCirclePostMaxLength',
                              style: Cyber.body(
                                9,
                                color: controller.text.length >= 450
                                    ? Cyber.gold
                                    : Cyber.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    enabled: enabled && controller.text.trim().isNotEmpty,
                    label: editingPost != null
                        ? 'Save comment'
                        : 'Post comment',
                    child: InkResponse(
                      key: const ValueKey('match-circle-composer-send'),
                      onTap: enabled && controller.text.trim().isNotEmpty
                          ? () => unawaited(onSubmit())
                          : null,
                      radius: 26,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: enabled && controller.text.trim().isNotEmpty
                              ? Cyber.cyan
                              : Cyber.panel,
                          border: Border.all(
                            color: enabled && controller.text.trim().isNotEmpty
                                ? Colors.white.withValues(alpha: 0.35)
                                : Cyber.border,
                          ),
                          boxShadow:
                              enabled &&
                                  controller.text.trim().isNotEmpty &&
                                  !mutating
                              ? Cyber.glow(Cyber.cyan, alpha: 0.25, blur: 10)
                              : null,
                        ),
                        child: mutating
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Cyber.cyan,
                                ),
                              )
                            : Icon(
                                editingPost != null
                                    ? Icons.check
                                    : Icons.send_rounded,
                                color:
                                    enabled && controller.text.trim().isNotEmpty
                                    ? Cyber.bg
                                    : Cyber.muted,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerModeBanner extends StatelessWidget {
  const _ComposerModeBanner({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('match-circle-composer-mode'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: Cyber.cyan.withValues(alpha: 0.08),
        border: const Border(left: BorderSide(color: Cyber.cyan, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 0.9),
            ),
          ),
          Semantics(
            button: true,
            label: 'Cancel',
            child: InkResponse(
              onTap: onCancel,
              radius: 24,
              child: const SizedBox(
                key: ValueKey('match-circle-composer-cancel'),
                width: 48,
                height: 48,
                child: Icon(Icons.close, color: Cyber.muted, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime timestamp) {
  final elapsed = DateTime.now().difference(timestamp);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';
  final day = timestamp.day.toString().padLeft(2, '0');
  final month = timestamp.month.toString().padLeft(2, '0');
  return '$day/$month/${timestamp.year}';
}
