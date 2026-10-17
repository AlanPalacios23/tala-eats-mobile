part of '../main.dart';

// ---------------------------------------------------------------------------
// Carrito, checkout y estado de pago. Same model calls as v1.0.8:
// changeQuantity, setDeliveryMode, setTip, setCoupon, placeOrder,
// startMercadoPago/startStripePayment, refreshOrder. Payment is only "paid" when the backend
// returns payment_status=paid.
// ---------------------------------------------------------------------------

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        if (model.cart.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tu carrito')),
            body: StatusView(
              icon: Icons.shopping_bag_outlined,
              title: 'Tu carrito está vacío',
              body: 'Agrega productos desde el menú de un restaurante.',
              actionLabel: 'Explorar restaurantes',
              onAction: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
            ),
          );
        }

        final List<CartLine> lines = List<CartLine>.of(model.cart);
        final Restaurant? restaurant = model.cartRestaurant;
        final int itemCount = cartItemCount(model);

        return Scaffold(
          appBar: AppBar(title: const Text('Tu carrito')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: <Widget>[
              if (restaurant != null) ...<Widget>[
                Reveal(
                  child: TalaCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                    child: Row(
                      children: <Widget>[
                        RestaurantMedia(assetPath: restaurant.image, imageUrl: restaurant.imageUrl, width: 52, height: 52, radius: 14),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.title),
                              const SizedBox(height: 2),
                              Text('$itemCount ${itemCount == 1 ? 'producto' : 'productos'} · ${restaurant.eta}', style: TalaText.caption),
                            ],
                          ),
                        ),
                        TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Agregar más')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              for (int i = 0; i < lines.length; i++)
                Reveal(index: i + 1, child: CartLineCard(model: model, line: lines[i])),
              const SizedBox(height: 8),
              Reveal(
                index: lines.length + 1,
                child: TalaCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: <Widget>[
                      CustomerCheckoutBreakdown(model: model),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const QuietNote(icon: Icons.info_outline_rounded, text: 'El total definitivo lo calcula el servidor. La comisión del restaurante no se cobra aparte al cliente.'),
            ],
          ),
          bottomNavigationBar: BottomActionBar(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(premiumRoute(CheckoutScreen(model: model))),
              child: const Text('Continuar al pago'),
            ),
          ),
        );
      },
    );
  }
}

class CartLineCard extends StatelessWidget {
  const CartLineCard({super.key, required this.model, required this.line});

  final TalaModel model;
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final Widget stepper = QuantityStepper(
      compact: true,
      deleteAtOne: true,
      quantity: line.quantity,
      onDecrement: () => model.changeQuantity(line, -1),
      onIncrement: () => model.changeQuantity(line, 1),
    );
    final Widget title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(line.item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TalaText.title.copyWith(fontSize: 15)),
        if (line.note.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: kSoftPeach,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(line.note, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kBrandDeep, fontSize: 11,
                    fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool narrow = constraints.maxWidth < 330;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DishThumb(item: line.item, size: 56, radius: 14),
                  const SizedBox(width: 12),
                  Expanded(child: title),
                  if (!narrow) ...<Widget>[
                    const SizedBox(width: 8),
                    stepper,
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text(money(line.total),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TalaText.price.copyWith(fontSize: 16)),
                  ),
                  if (narrow) ...<Widget>[
                    const SizedBox(width: 12),
                    stepper,
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.model});

  final TalaModel model;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final TextEditingController coupon = TextEditingController(text: widget.model.coupon);
  bool placing = false;
  bool refreshingPayment = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    // Relee tasas configuradas en Kali sin modificar los cobros.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshPaymentAvailability();
    });
  }

  @override
  void dispose() {
    coupon.dispose();
    super.dispose();
  }

  Future<void> refreshPaymentAvailability() async {
    setState(() {
      refreshingPayment = true;
      error = '';
    });
    try {
      await widget.model.refreshPaymentMethods();
    } on ApiException catch (e) {
      if (mounted) error = e.message;
    }
    if (!mounted) return;
    setState(() {
      refreshingPayment = false;
      if (!widget.model.hasAvailablePaymentMethod && error.isEmpty) {
        error = 'No hay un método de pago disponible en este momento.';
      }
    });
  }

  Future<void> submit() async {
    final TalaModel model = widget.model;
    if (model.deliveryMode == 'delivery' && model.addresses.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => error = 'Agrega una dirección de entrega para continuar.');
      return;
    }
    if (!model.hasAvailablePaymentMethod || !model.isPaymentMethodEnabled(model.paymentMethod)) {
      setState(() => error = 'No hay un método de pago disponible para confirmar el pedido.');
      return;
    }
    setState(() {
      placing = true;
      error = '';
    });
    try {
      final String selectedMethod = model.paymentMethod;
      final OrderEntry order = await model.placeOrder();
      if (!mounted) return;
      if (selectedMethod == 'cash') {
        Navigator.of(context).pushReplacement(premiumRoute(CashOrderConfirmationScreen(model: model, order: order)));
      } else {
        Navigator.of(context).pushReplacement(premiumRoute(PaymentStatusScreen(model: model, order: order)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          placing = false;
          error = e.message;
        });
      }
    }
  }

  void applyCoupon() {
    FocusScope.of(context).unfocus();
    widget.model.setCoupon(coupon.text);
    if (coupon.text.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    showMessage(context, 'Cupón listo. Se validará al confirmar el pago.');
  }

  void removeCoupon() {
    coupon.clear();
    widget.model.setCoupon('');
  }

  @override
  Widget build(BuildContext context) {
    final TalaModel model = widget.model;
    final Restaurant? restaurant = model.cartRestaurant;
    if (restaurant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finalizar pedido')),
        body: const StatusView(icon: Icons.shopping_bag_outlined, title: 'Tu carrito está vacío', body: 'Agrega productos para continuar.'),
      );
    }

    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        final bool delivery = model.deliveryMode == 'delivery';
        final AddressEntry? address = model.addresses.isEmpty ? null : model.addresses[model.selectedAddress.clamp(0, model.addresses.length - 1).toInt()];
        return Scaffold(
          appBar: AppBar(title: const Text('Finalizar pedido')),
          body: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: <Widget>[
              Reveal(
                child: CheckoutSectionCard(
                  title: 'Entrega',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints bounds) {
                          final Widget? deliveryOption = restaurant.delivery
                              ? DeliveryModeCard(
                                  icon: Icons.two_wheeler_rounded,
                                  title: 'A domicilio',
                                  subtitle: restaurant.eta,
                                  selected: delivery,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    model.setDeliveryMode('delivery');
                                  },
                                )
                              : null;
                          final Widget? pickupOption = restaurant.pickup
                              ? DeliveryModeCard(
                                  icon: Icons.storefront_rounded,
                                  title: 'Recoger',
                                  subtitle: 'Sin costo de envío',
                                  selected: model.deliveryMode == 'pickup',
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    model.setDeliveryMode('pickup');
                                  },
                                )
                              : null;
                          // Full-width choices prevent compressed text and
                          // inaccessible taps on 320dp/textScale 1.3 devices.
                          if (deliveryOption != null && pickupOption != null) {
                            if (bounds.maxWidth < 320) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  deliveryOption,
                                  const SizedBox(height: 10),
                                  pickupOption,
                                ],
                              );
                            }
                            return Row(
                              children: <Widget>[
                                Expanded(child: deliveryOption),
                                const SizedBox(width: 10),
                                Expanded(child: pickupOption),
                              ],
                            );
                          }
                          return deliveryOption ?? pickupOption ??
                              const QuietNote(
                                icon: Icons.storefront_outlined,
                                text: 'Este comercio no ofrece una modalidad de entrega.',
                              );
                        },
                      ),
                      AnimatedSize(
                        duration: TalaMotion.of(context, TalaMotion.reveal),
                        curve: TalaMotion.ease,
                        alignment: Alignment.topCenter,
                        child: !delivery
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: QuietNote(icon: Icons.storefront_outlined, text: 'Recoge tu pedido en ${restaurant.name}. Te avisaremos cuando esté listo.'),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: address == null
                                    ? TalaCard(
                                        color: kSoftPeach,
                                        borderColor: const Color(0xFFFFD9C7),
                                        padding: const EdgeInsets.all(14),
                                        onTap: () => Navigator.of(context).push(premiumRoute(AddressesScreen(model: model))),
                                        child: const Row(
                                          children: <Widget>[
                                            Icon(Icons.add_location_alt_rounded, color: kBrandDeep),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Text('Agrega una dirección', style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
                                                  SizedBox(height: 2),
                                                  Text('La necesitamos para calcular el envío.', style: TalaText.caption),
                                                ],
                                              ),
                                            ),
                                            Icon(Icons.chevron_right_rounded, color: kBrandDeep),
                                          ],
                                        ),
                                      )
                                    : Row(
                                        children: <Widget>[
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(color: kSoftOrange, borderRadius: BorderRadius.circular(13)),
                                            child: const Icon(Icons.location_on_rounded, color: kBrand),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(address.label, style: TalaText.title.copyWith(fontSize: 15)),
                                                const SizedBox(height: 2),
                                                Text(address.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: TalaText.caption.copyWith(fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).push(premiumRoute(AddressesScreen(model: model))),
                                            child: const Text('Cambiar'),
                                          ),
                                        ],
                                      ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (delivery) ...<Widget>[
                const SizedBox(height: 12),
                Reveal(
                  index: 1,
                  child: CheckoutSectionCard(
                    title: 'Propina',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <double>[0, 20, 30, 50]
                          .map((double value) => TalaChoicePill(
                                label: value == 0 ? 'Sin propina' : money(value),
                                selected: model.tip == value,
                                onTap: () => model.setTip(value),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Reveal(
                index: 2,
                child: CheckoutSectionCard(
                  title: 'Cupón',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: coupon,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => applyCoupon(),
                              decoration: const InputDecoration(hintText: 'Código de promoción', prefixIcon: Icon(Icons.local_offer_outlined)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(style: kCompactFilled.copyWith(minimumSize: const WidgetStatePropertyAll<Size>(Size(92, 54))), onPressed: applyCoupon, child: const Text('Aplicar')),
                        ],
                      ),
                      if (model.coupon.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.check_circle_rounded, color: kGreen, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${model.coupon} se validará al pagar', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 13))),
                            TextButton(onPressed: removeCoupon, child: const Text('Quitar')),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Reveal(
                index: 3,
                child: CheckoutSectionCard(
                  title: 'Pago',
                  child: AnimatedSwitcher(
                    duration: TalaMotion.of(context, TalaMotion.reveal),
                    child: model.hasAvailablePaymentMethod
                        ? Column(
                            key: const ValueKey<String>('methods'),
                            children: <Widget>[
                              if (model.cashPayments)
                                PaymentChoiceCard(
                                  icon: Icons.payments_outlined,
                                  title: 'Efectivo',
                                  subtitle: model.deliveryMode == 'delivery' ? 'Paga al recibir tu pedido' : 'Paga al recoger tu pedido',
                                  selected: model.paymentMethod == 'cash',
                                  onTap: () => model.setPaymentMethod('cash'),
                                ),
                              if (model.cashPayments && (model.mercadoPagoPayments || model.stripePayments)) const SizedBox(height: 10),
                              if (model.mercadoPagoPayments)
                                PaymentChoiceCard(
                                  icon: Icons.account_balance_wallet_outlined,
                                  title: 'Mercado Pago',
                                  subtitle: 'Pago en línea protegido',
                                  selected: model.paymentMethod == 'mercadopago',
                                  onTap: () => model.setPaymentMethod('mercadopago'),
                                ),
                              if (model.mercadoPagoPayments && model.stripePayments) const SizedBox(height: 10),
                              if (model.stripePayments)
                                PaymentChoiceCard(
                                  icon: Platform.isIOS ? Icons.apple_rounded : Icons.g_mobiledata_rounded,
                                  title: Platform.isIOS ? 'Tarjeta y Apple Pay' : 'Tarjeta y Google Pay',
                                  subtitle: 'Pago seguro procesado por Stripe',
                                  selected: model.paymentMethod == 'stripe',
                                  onTap: () => model.setPaymentMethod('stripe'),
                                ),
                            ],
                          )
                        : PaymentUnavailableCard(key: const ValueKey<String>('off'), onRetry: refreshPaymentAvailability, loading: refreshingPayment),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Reveal(index: 4, child: SummaryCard(model: model)),
              AnimatedSize(
                duration: TalaMotion.of(context, TalaMotion.select),
                curve: TalaMotion.ease,
                child: error.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AuthNotice(icon: Icons.info_outline_rounded, text: error, danger: true),
                      ),
              ),
            ],
          ),
          bottomNavigationBar: BottomActionBar(
            child: model.hasAvailablePaymentMethod
                ? FilledButton(
                    onPressed: placing ? null : submit,
                    child: BusyLabel(
                      busy: placing,
                      label: model.paymentMethod == 'cash'
                          ? 'Confirmar pedido'
                          : model.paymentMethod == 'stripe'
                              ? 'Continuar a pago con Stripe'
                              : 'Continuar a Mercado Pago',
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: refreshingPayment ? null : refreshPaymentAvailability,
                    icon: refreshingPayment
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Revisar métodos de pago'),
                  ),
          ),
        );
      },
    );
  }
}

class CheckoutSectionCard extends StatelessWidget {
  const CheckoutSectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TalaCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TalaText.title.copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class DeliveryModeCard extends StatelessWidget {
  const DeliveryModeCard({super.key, required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Duration d = TalaMotion.of(context, TalaMotion.select);
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: d,
              curve: TalaMotion.ease,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? kSoftPeach : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? kBrand : kLine, width: selected ? 1.6 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      AnimatedContainer(
                        duration: d,
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: selected ? kBrand : kSunken, borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, size: 20, color: selected ? Colors.white : kMuted),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: d,
                        child: Icon(
                          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                          key: ValueKey<bool>(selected),
                          color: selected ? kBrand : kSubtle,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kInk)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.caption),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumPaymentMethodCard extends StatelessWidget {
  const PremiumPaymentMethodCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF4FAFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFCFE6F8), width: 1.4)),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFCFE6F8))),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1687D9), size: 23),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Mercado Pago', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kInk)),
                SizedBox(height: 2),
                Text('Tarjeta, saldo o efectivo en Mercado Pago', style: TalaText.caption),
              ],
            ),
          ),
          const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF1687D9)),
        ],
      ),
    );
  }
}

class PaymentUnavailableCard extends StatelessWidget {
  const PaymentUnavailableCard({super.key, required this.onRetry, required this.loading});

  final VoidCallback onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(color: kSoftPeach, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFD9C7))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.credit_card_off_rounded, color: kBrandDeep),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Pago en línea no disponible por ahora', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kInk)),
                    SizedBox(height: 4),
                    Text('No se hará ningún cargo. Intenta de nuevo cuando el servidor vuelva a ofrecer un método disponible.', style: TextStyle(color: kInkSoft, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: loading ? null : onRetry,
              icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Revisar de nuevo'),
            ),
          ),
        ],
      ),
    );
  }
}

// Unico desglose de carrito y checkout: referencias obtenidas de
// /orders/payment-methods. El monto real siempre proviene de OrderPublic.
class CustomerCheckoutBreakdown extends StatelessWidget {
  const CustomerCheckoutBreakdown({super.key, required this.model});
  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    final CheckoutPricingPreview preview = model.checkoutPreview;
    final double? shipping = preview.deliveryReference;
    final double? serviceFee = preview.serviceFee;
    final double? referenceTotal = preview.estimatedReferenceTotal;
    final double? rate = model.customerPricingPolicy?.serviceFeeRate;
    final String serviceLabel = rate == null
        ? 'Tarifa de servicio'
        : 'Tarifa de servicio (${(rate * 100).toStringAsFixed(((rate * 100) - (rate * 100).round()).abs() < 0.000001 ? 0 : 1)}%${model.customerPricingPolicy?.serviceFeeCap == null ? '' : ', máx ${moneyWithCents(model.customerPricingPolicy!.serviceFeeCap!)}'})';
    return Column(
      children: <Widget>[
        _CustomerAmountRow(label: 'Subtotal', amount: model.subtotal),
        const SizedBox(height: 9),
        _CustomerAmountRow(
          label: serviceLabel,
          amount: serviceFee,
          hint: 'Aplica a efectivo y pago digital; no a envío ni propina.',
        ),
        const SizedBox(height: 9),
        _CustomerAmountRow(
          label: preview.delivery ? (model.customerPricingPolicy?.version == '1.6.2' ? 'Envío (desde, según distancia)' : 'Envío (referencia base)') : 'Recoger en restaurante',
          amount: shipping,
          hint: preview.delivery ? 'Cotización final en el servidor según distancia GPS.' : 'Sin cargo de envío.',
        ),
        if (preview.delivery && model.tip > 0) ...<Widget>[
          const SizedBox(height: 9),
          _CustomerAmountRow(label: 'Propina para repartidor', amount: model.tip),
        ],
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
        _CustomerAmountRow(label: 'Total de referencia', amount: referenceTotal, bold: true),
        const SizedBox(height: 7),
        Text(preview.disclosure, style: TalaText.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _CustomerAmountRow extends StatelessWidget {
  const _CustomerAmountRow({
    required this.label, required this.amount, this.hint, this.bold = false,
  });

  final String label;
  final double? amount;
  final String? hint;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final Widget description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: TextStyle(color: bold ? kInk : kInkSoft,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontSize: bold ? 16 : 14)),
        if (hint != null)
          Text(hint!, style: TalaText.caption.copyWith(fontSize: 11)),
      ],
    );
    final Widget price = Text(
      amount == null ? 'Por confirmar' : moneyWithCents(amount!),
      textAlign: TextAlign.right,
      style: TextStyle(color: kInk,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontSize: bold ? 18 : 14),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bounds) {
        if (bounds.maxWidth < 310) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              description,
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerRight, child: price),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: description),
            const SizedBox(width: 8),
            price,
          ],
        );
      },
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return CheckoutSectionCard(
      title: 'Resumen',
      child: Column(
        children: <Widget>[
          for (final CartLine line in model.cart)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 30, child: Text('${line.quantity}×', style: const TextStyle(color: kBrandDeep, fontWeight: FontWeight.w800))),
                  Expanded(child: Text(line.item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kInkSoft, fontWeight: FontWeight.w500))),
                  const SizedBox(width: 8),
                  Text(money(line.total), style: const TextStyle(color: kInkSoft, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
          CustomerCheckoutBreakdown(model: model),
        ],
      ),
    );
  }
}

class PaymentChoiceCard extends StatelessWidget {
  const PaymentChoiceCard({super.key, required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TalaCard(
      onTap: onTap,
      borderColor: selected ? kBrand : kLine,
      color: selected ? kSoftPeach : Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: selected ? kBrand : kSoftOrange, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: selected ? Colors.white : kBrandDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: TalaText.title.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: TalaText.caption),
              ],
            ),
          ),
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? kBrand : kSubtle),
        ],
      ),
    );
  }
}

class CashOrderConfirmationScreen extends StatelessWidget {
  const CashOrderConfirmationScreen({super.key, required this.model, required this.order});

  final TalaModel model;
  final OrderEntry order;

  @override
  Widget build(BuildContext context) {
    final bool delivery = order.deliveryMode == 'delivery';
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 42, 22, 28),
          children: <Widget>[
            const Center(child: SuccessOrb(icon: Icons.receipt_long_rounded, color: kBrand, soft: kSoftOrange)),
            const SizedBox(height: 22),
            Text('Pedido recibido', textAlign: TextAlign.center, style: TalaText.display.copyWith(fontSize: 28)),
            const SizedBox(height: 8),
            Text('Pedido #${order.id} · ${money(order.total)}', textAlign: TextAlign.center, style: TalaText.muted.copyWith(fontSize: 15)),
            const SizedBox(height: 22),
            TalaCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: kSoftGreen, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.payments_outlined, color: kGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('Pago en efectivo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kInk)),
                        const SizedBox(height: 3),
                        Text(delivery ? 'Paga al recibir tu pedido.' : 'Paga al recoger tu pedido.', style: TalaText.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TalaCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                const Text('Total definitivo confirmado por TALA EATS', style: TextStyle(fontWeight: FontWeight.w700, color: kInk)),
                const SizedBox(height: 8),
                Text(moneyWithCents(order.total), style: TalaText.price.copyWith(fontSize: 23)),
              ]),
            ),
            const SizedBox(height: 16),
            TalaCard(padding: const EdgeInsets.all(16), child: OrderStatusTimeline(order: order, compact: true)),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(premiumRoute(OrderDetailScreen(model: model, order: order))),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Ver mi pedido'),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst), child: const Text('Volver a Inicio')),
          ],
        ),
      ),
    );
  }
}

class PaymentStatusScreen extends StatefulWidget {
  const PaymentStatusScreen({super.key, required this.model, required this.order});

  final TalaModel model;
  final OrderEntry order;

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> with WidgetsBindingObserver {
  bool opening = false;
  bool checking = false;
  bool cancelling = false;
  bool allowPop = false;
  Timer? _paymentPollTimer;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Server/webhook is authoritative. Poll only while this screen is visible,
    // rather than asking customers to repeatedly tap "Verificar pago".
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 8), (Timer _) {
      if (mounted && !opening && !checking && !cancelling && !paid) {
        unawaited(verify());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openCheckout());
    });
  }

  @override
  void dispose() {
    _paymentPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !paid && !cancelling) {
      unawaited(verify());
    }
  }

  Future<void> openCheckout() async {
    if (opening || widget.order.paymentStatus == 'paid') return;
    setState(() => opening = true);
    try {
      if (widget.order.paymentMethod == 'stripe') {
        final bool sheetCompleted = await widget.model.startStripePayment(widget.order);
        if (!sheetCompleted) {
          await cancelPaymentAndReturn(message: 'Pago cancelado. Tu carrito sigue listo.');
          return;
        }
      } else {
        await widget.model.startMercadoPago(widget.order);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> cancelPaymentAndReturn({String message = 'Pago cancelado. Tu carrito sigue listo.'}) async {
    if (cancelling || paid) return;
    setState(() {
      cancelling = true;
      error = '';
    });

    final bool cancelled = await widget.model.abandonPendingOnlineOrder(widget.order);
    if (!mounted) return;

    // A provider webhook may win the race while the customer closes checkout.
    // If payment was already confirmed, the backend refuses cancellation and
    // the client must honor the paid state instead of rolling the order back.
    if (!cancelled) {
      try {
        await widget.model.refreshOrder(widget.order);
      } on ApiException catch (_) {}
      if (!mounted) return;
      if (paid) {
        setState(() => cancelling = false);
        HapticFeedback.mediumImpact();
        return;
      }
      setState(() {
        cancelling = false;
        error = 'No pudimos cancelar la reserva todavía. Verifica tu conexión antes de salir.';
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {
      cancelling = false;
      allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String get providerName => widget.order.paymentMethod == 'stripe' ? 'Stripe' : 'Mercado Pago';
  String get providerAction => widget.order.paymentMethod == 'stripe' ? 'Abrir pago seguro' : 'Abrir Mercado Pago';

  Future<void> verify() async {
    if (!mounted || checking || cancelling || paid) return;
    setState(() {
      checking = true;
      error = '';
    });
    try {
      await widget.model.refreshOrder(widget.order);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => checking = false);
    }
    if (paid && mounted) {
      _paymentPollTimer?.cancel();
      HapticFeedback.mediumImpact();
    }
  }

  bool get paid => widget.order.paymentStatus == 'paid';

  @override
  Widget build(BuildContext context) {
    final OrderEntry order = widget.order;
    return PopScope<Object?>(
      canPop: allowPop || paid || order.rawStatus == 'cancelled',
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && !paid) cancelPaymentAndReturn();
      },
      child: Scaffold(
        backgroundColor: kBackground,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
            children: <Widget>[
              Center(
                child: AnimatedSwitcher(
                  duration: TalaMotion.of(context, TalaMotion.reveal),
                  child: paid
                      ? const PaymentSuccessOrb(key: ValueKey<String>('paid'))
                      : const SuccessOrb(
                          key: ValueKey<String>('pending'),
                          icon: Icons.lock_clock_outlined,
                          color: kBrandDeep,
                          soft: kSoftOrange,
                        ),
                ),
              ),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: TalaMotion.of(context, TalaMotion.select),
                child: Text(
                  paid ? '¡Pago confirmado!' : 'Completa tu pago',
                  key: ValueKey<bool>(paid),
                  textAlign: TextAlign.center,
                  style: TalaText.display.copyWith(fontSize: 28),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pedido #${order.id} · ${money(order.total)}',
                textAlign: TextAlign.center,
                style: TalaText.muted.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 24),
              TalaCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: kSoftOrange, borderRadius: BorderRadius.circular(13)),
                          child: Icon(order.deliveryMode == 'delivery' ? Icons.two_wheeler_rounded : Icons.storefront_rounded, color: kBrand),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(order.restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.title),
                              const SizedBox(height: 2),
                              Text(order.deliveryMode == 'delivery' ? 'Entrega a domicilio' : 'Recoger en el local', style: TalaText.caption),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: paymentStatusLabel(order.paymentStatus),
                          color: paid ? kGreen : kBrandDeep,
                          background: paid ? kSoftGreen : kSoftOrange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (paid)
                      OrderStatusTimeline(order: order, compact: true)
                    else
                      const QuietNote(
                        icon: Icons.schedule_rounded,
                        text: 'El pedido todavía no entra a preparación. Primero debe confirmarse el pago.',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (paid)
                AuthNotice(icon: Icons.verified_rounded, text: '$providerName confirmó tu pago. Puedes seguir tu pedido desde Pedidos.')
              else
                const QuietNote(
                  icon: Icons.shield_outlined,
                  text: 'El restaurante no recibe este pedido para preparación hasta que el servidor confirme el pago.',
                ),
              if (error.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true),
              ],
              const SizedBox(height: 22),
              if (!paid) ...<Widget>[
                FilledButton.icon(
                  onPressed: opening || cancelling ? null : openCheckout,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(opening ? 'Abriendo $providerName…' : providerAction),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (checking) ...<Widget>[
                      const SizedBox(
                        height: 14, width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                    ] else ...<Widget>[
                      const Icon(Icons.sync_rounded, size: 17, color: kMuted),
                      const SizedBox(width: 8),
                    ],
                    const Flexible(
                      child: Text('El estado del pago se actualiza automáticamente.',
                        textAlign: TextAlign.center,
                        style: TalaText.caption),
                    ),
                  ],
                ),
              ] else
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(premiumRoute(OrderDetailScreen(model: widget.model, order: order))),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Ver mi pedido'),
                ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: cancelling
                    ? null
                    : paid
                        ? () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst)
                        : () => cancelPaymentAndReturn(),
                child: Text(cancelling ? 'Cancelando…' : paid ? 'Volver a Inicio' : 'Cancelar pago y volver al carrito'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brief, elegant success: orb pops in and a ring of brand dots disperses once.
class PaymentSuccessOrb extends StatelessWidget {
  const PaymentSuccessOrb({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: TalaMotion.of(context, const Duration(milliseconds: 900)),
      builder: (BuildContext context, double t, Widget? child) {
        final double pop = Curves.easeOutBack.transform((t / 0.55).clamp(0.0, 1.0).toDouble());
        final double burst = ((t - 0.25) / 0.75).clamp(0.0, 1.0).toDouble();
        return SizedBox(
          width: 180,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(child: CustomPaint(painter: _BurstPainter(progress: burst))),
              Transform.scale(scale: 0.6 + 0.4 * pop, child: child),
            ],
          ),
        );
      },
      child: Container(
        width: 104,
        height: 104,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFF7A3D), kBrand]),
          boxShadow: <BoxShadow>[BoxShadow(color: Color(0x40FF5A1F), blurRadius: 30, offset: Offset(0, 14))],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final Offset center = size.center(Offset.zero);
    final double eased = Curves.easeOutCubic.transform(progress);
    final double radius = 50 + 30 * eased;
    final double alpha = (1 - progress).clamp(0.0, 1.0).toDouble();
    const int count = 10;
    for (int i = 0; i < count; i++) {
      final double angle = (math.pi * 2 / count) * i - math.pi / 2;
      final Offset point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final Paint paint = Paint()..color = (i.isEven ? kBrand : kGold).withValues(alpha: alpha);
      canvas.drawCircle(point, i.isEven ? 4.0 : 3.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => oldDelegate.progress != progress;
}
