import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/transfer_provider.dart';
import '../../screens/transfers/transfer_detail_screen.dart';

class TransferCycleIndicator extends ConsumerWidget {
  const TransferCycleIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferState = ref.watch(transferListProvider);
    final active = transferState.activeTransfers;
    final recent = transferState.transfers
        .where((t) =>
            t.completedAt != null &&
            DateTime.now().difference(t.completedAt!).inSeconds < 30)
        .toList();

    if (active.isEmpty && recent.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransferDetailScreen(
            transfers: transferState.transfers,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              if (active.isNotEmpty)
                AppColors.transferProgress
              else
                AppColors.success,
              if (active.isNotEmpty)
                AppColors.primaryGreen
              else
                AppColors.primaryGreenSurface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (active.isNotEmpty
                      ? AppColors.transferProgress
                      : AppColors.success)
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _AnimatedCycle(count: active.isNotEmpty ? active.length : 0),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active.isNotEmpty
                        ? '${active.length} file(s) transferring'
                        : '${recent.length} file(s) received',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active.isNotEmpty
                        ? 'Tap to view progress'
                        : 'Tap to view details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCycle extends StatefulWidget {
  final int count;
  const _AnimatedCycle({required this.count});

  @override
  State<_AnimatedCycle> createState() => _AnimatedCycleState();
}

class _AnimatedCycleState extends State<_AnimatedCycle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.count > 0) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AnimatedCycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > 0 && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.count == 0 && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showLive = widget.count > 0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: showLive ? _controller.value * 2 * math.pi : 0,
          child: child,
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            showLive ? '${widget.count}' : '\u{2713}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
