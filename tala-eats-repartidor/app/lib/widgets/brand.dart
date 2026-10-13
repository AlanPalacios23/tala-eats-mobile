import 'package:flutter/material.dart';

import '../core/theme.dart';

const String kTalaEatsLogoAsset = 'assets/branding/tala_eats_logo.png';

/// Identidad oficial de Tala Eats reutilizada desde el material de marca
/// existente. No dibuja ni inventa un logotipo alternativo.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.center = false});

  final bool center;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Tala Eats Repartidor',
        excludeSemantics: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.25;
            final compact = constraints.maxWidth < 280 || largeText;
            final mark = Image.asset(
              kTalaEatsLogoAsset,
              width: 72,
              height: 72,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            );
            const wordmark = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TALA EATS',
                  style: TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  'Repartidor',
                  style: TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    height: 1.15,
                  ),
                ),
              ],
            );
            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  mark,
                  const SizedBox(height: Space.s),
                  wordmark,
                ],
              );
            }
            return Row(
              mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
              children: [
                mark,
                const SizedBox(width: Space.m),
                const Flexible(child: wordmark),
              ],
            );
          },
        ),
      );
}
