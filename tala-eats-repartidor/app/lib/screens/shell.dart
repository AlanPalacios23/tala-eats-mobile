import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../widgets/motion.dart';
import 'deliveries_screen.dart';
import 'earnings_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.controller});

  final DriverController controller;

  void _select(int index) {
    if (index == controller.tabIndex) return;
    Haptics.selection();
    controller.setTab(index);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final tab = controller.tabIndex;
          final routeBusy = controller.deliveryInProgress;
          final pages = <Widget>[
            HomeScreen(controller: controller),
            DeliveriesScreen(controller: controller),
            EarningsScreen(controller: controller),
            ProfileScreen(controller: controller),
          ];

          return PopScope(
            // Atrás desde otra pestaña regresa a Inicio en lugar de salir.
            canPop: tab == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _select(0);
            },
            child: Scaffold(
              // Solo se monta la pestaña visible. Esto evita que pantallas
              // ocultas sigan haciendo layout/animaciones y puedan provocar
              // overflows o trabajo innecesario en accesibilidad.
              body: KeyedSubtree(
                key: ValueKey('driver-tab-$tab'),
                child: TabStage(active: true, child: pages[tab]),
              ),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CTA operativo fijo solo en Inicio (no compite con otras
                  // vistas y nunca queda tapado por la navegación).
                  Reveal(
                    visible: tab == 0,
                    child: HomeActionBar(controller: controller),
                  ),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: kLine)),
                    ),
                    child: NavigationBar(
                      selectedIndex: tab,
                      onDestinationSelected: _select,
                      animationDuration: Motion.of(context, Motion.medium),
                      labelBehavior: MediaQuery.textScalerOf(context).scale(1) >= 1.25
                          ? NavigationDestinationLabelBehavior.alwaysHide
                          : MediaQuery.sizeOf(context).width < 390
                              ? NavigationDestinationLabelBehavior.onlyShowSelected
                              : NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: [
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible: routeBusy && tab != 0,
                            smallSize: 8,
                            backgroundColor: kBrandDeep,
                            child: const Icon(Icons.home_outlined),
                          ),
                          selectedIcon: const Icon(Icons.home_rounded),
                          label: 'Inicio',
                          tooltip:
                              routeBusy ? 'Inicio, entrega en curso' : 'Inicio',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long_rounded),
                          label: 'Entregas',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.account_balance_wallet_outlined),
                          selectedIcon:
                              Icon(Icons.account_balance_wallet_rounded),
                          label: 'Ganancias',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: 'Perfil',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
