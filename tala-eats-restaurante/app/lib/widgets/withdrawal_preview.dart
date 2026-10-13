import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/withdrawal_gateway.dart';
import '../screens/withdrawals/withdrawals_screen.dart';
import 'buttons.dart';

/// Acceso compacto «Retirar ganancias» desde Finanzas.
///
/// Abre «Mis retiros». Nunca inicia transferencias ni calcula saldos: en
/// v0.5.11 el servicio de retiros no está conectado
/// ([DisconnectedWithdrawalGateway]) y el envío final permanece bloqueado.
class WithdrawalPreviewAction extends StatelessWidget {
  const WithdrawalPreviewAction({super.key, this.gateway, this.restaurantId});

  /// Fuente de datos de retiros. `null` = servicio no conectado.
  final WithdrawalGateway? gateway;
  final int? restaurantId;

  void _open(BuildContext context) {
    Navigator.of(context).push<void>(
      appRoute<void>(
        WithdrawalsScreen(
          gateway: restaurantId != null && restaurantId! > 0
              ? (gateway ?? const DisconnectedWithdrawalGateway())
                    .forRecipient(restaurantId!)
              : const DisconnectedWithdrawalGateway(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      key: const ValueKey<String>('restaurant-withdraw-earnings'),
      label: 'Retirar ganancias',
      icon: Icons.account_balance_wallet_outlined,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.compact,
      expand: false,
      onPressed: () => _open(context),
    );
  }
}
