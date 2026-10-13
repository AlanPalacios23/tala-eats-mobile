import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/withdrawal.dart';
import '../../state/operations_controller.dart' show LoadStatus;
import '../../state/withdrawal_state.dart';
import '../../widgets/feedback.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/states.dart';
import '../../widgets/surfaces.dart';
import 'withdrawal_widgets.dart';

/// Pantalla C — «Historial de retiros».
///
/// Lista virtualizada. «Pagado» solo aparece cuando el servidor informa ese
/// estado definitivo; esta pantalla no infiere estados.
class WithdrawalHistoryScreen extends StatelessWidget {
  const WithdrawalHistoryScreen({super.key, required this.controller});

  final WithdrawalController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Historial de retiros'),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => RefreshIndicator(
            color: AppColors.ink,
            onRefresh: controller.loadHistory,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: _slivers(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _slivers() {
    final c = controller;
    final records = c.history;
    final failure = c.historyFailure;
    final failed = c.historyStatus == LoadStatus.failure && failure != null;

    // `hasScrollBody: false` mide el hijo con intrínsecos: sin scroll anidado.
    Widget fill(Widget child) => SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: child),
        );

    if (failure != null && failed && records.isEmpty) {
      return <Widget>[
        fill(StateView.failure(failure, onRetry: c.loadHistory)),
      ];
    }
    if (c.historyStatus != LoadStatus.ready && !failed && records.isEmpty) {
      return const <Widget>[
        SliverToBoxAdapter(child: _HistorySkeleton()),
      ];
    }
    if (!c.gateway.isConnected) {
      return <Widget>[
        fill(
          const StateView(
            icon: Icons.history_rounded,
            title: 'Historial pendiente de habilitación',
            message: 'Cuando los retiros estén disponibles verás aquí cada '
                'solicitud con su fecha, importe, destino y estado.',
          ),
        ),
      ];
    }
    if (records.isEmpty) {
      return <Widget>[
        fill(
          const StateView(
            icon: Icons.receipt_long_outlined,
            title: 'Aún no tienes retiros',
            message: 'Cada solicitud aparecerá aquí con su estado.',
          ),
        ),
      ];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: _Constrained(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              AppSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (failure != null && failed) ...<Widget>[
                  InlineAlert.failure(failure, onRetry: c.loadHistory),
                  const SizedBox(height: AppSpace.md),
                ],
                Text(
                  plural(records.length, 'retiro', 'retiros'),
                  style: AppText.caption.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.xs,
          AppSpace.gutter,
          AppSpace.xxxl,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final WithdrawalRecord record = records[index];
              return _Constrained(
                key: ValueKey<String>('withdrawal-${record.id}'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: WithdrawalRecordRow(record: record),
                  ),
                ),
              );
            },
            childCount: records.length,
          ),
        ),
      ),
    ];
  }
}

class _Constrained extends StatelessWidget {
  const _Constrained({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: child,
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row() => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: BoneCard(
            child: Shimmer(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Bone(width: 120, height: 16),
                        SizedBox(height: 8),
                        Bone(width: 170, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Bone(width: 84, height: 24, radius: 12),
                ],
              ),
            ),
          ),
        );

    return _Constrained(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          AppSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[row(), row(), row()],
        ),
      ),
    );
  }
}
