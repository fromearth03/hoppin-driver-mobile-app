import 'package:flutter/material.dart';

import '../../core/theme/typography.dart';
import '../nav/app_shell.dart';

/// A list backed by cursor pagination.
///
/// Both the statement and trip history page the same way, so the load-more
/// mechanics — and the rule that a page in flight cannot be requested twice
/// — live in one place.
class CursorList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final Widget? emptyState;
  final Widget? header;
  final Future<void> Function()? onRefresh;

  const CursorList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.emptyState,
    this.header,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      // Both users of this list live inside the shell, whose floating pill
      // would otherwise trap the last row beneath it.
      padding: const EdgeInsets.only(bottom: AppShell.bottomClearance),
      // header + items + footer
      itemCount: (header == null ? 0 : 1) + items.length + 1,
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header!;
        final offset = header == null ? 0 : 1;
        final i = index - offset;

        if (i < items.length) return itemBuilder(context, items[i]);

        if (items.isEmpty && emptyState != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 64),
            child: emptyState!,
          );
        }
        if (isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (hasMore && onLoadMore != null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: TextButton(
                onPressed: onLoadMore,
                child: const Text('Load more', style: AppText.body),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );

    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
