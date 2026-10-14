part of '../main.dart';

// Mapa de seguimiento de la entrega. Todos los puntos vienen del pedido
// autenticado /v11/orders/{id}/live; nunca usar coordenadas de demostración.
// El backend actual guarda las últimas coordenadas del driver en su perfil,
// pero no expone cuándo se tomó la muestra GPS: se informa como aproximada.

bool validTrackingCoordinates(double? lat, double? lng) {
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  return lat != 0 || lng != 0;
}

class DriverTrackingMap extends StatefulWidget {
  const DriverTrackingMap({super.key, required this.order});

  final OrderEntry order;

  @override
  State<DriverTrackingMap> createState() => _DriverTrackingMapState();
}

class _DriverTrackingMapState extends State<DriverTrackingMap> {
  final MapController _controller = MapController();
  bool _mapReady = false;
  bool _followDriver = true;
  LatLng? _previousDriverPosition;

  // Se puede cambiar al proveedor de teselas contratado al cerrar la fase
  // piloto, sin reconstruir el widget ni modificar el backend.
  // El servicio público de OSM requiere attribution, User-Agent y caching.
  static const String _tiles = String.fromEnvironment(
    'TALAEATS_MAP_TILES_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fitVisiblePoints() {
    if (!_mapReady) return;
    _followDriver = true;
    final OrderEntry order = widget.order;
    final List<LatLng> positions = <LatLng>[
      if (order.hasDeliveryCoordinates)
        LatLng(order.deliveryLat!, order.deliveryLng!),
      if (order.hasDriverCoordinates)
        LatLng(order.driverLat!, order.driverLng!),
    ];
    if (positions.isEmpty) return;
    if (positions.length == 1 || positions.first == positions.last) {
      _controller.move(positions.first, 15);
    } else {
      _controller.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(positions),
        padding: const EdgeInsets.all(42),
        maxZoom: 16,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final OrderEntry order = widget.order;
    if (!order.canShowTrackingMap) return const SizedBox.shrink();

    final bool driverLocated = order.hasDriverCoordinates;
    final bool destinationLocated = order.hasDeliveryCoordinates;
    final LatLng? driver = driverLocated
        ? LatLng(order.driverLat!, order.driverLng!)
        : null;
    final LatLng? destination = destinationLocated
        ? LatLng(order.deliveryLat!, order.deliveryLng!)
        : null;

    // Los marcadores se actualizan cada vez que cambia OrderEntry por polling.
    // Seguir el GPS es opcional: al mover el mapa manualmente deja de recentrar
    // automáticamente hasta que se toque el botón de centrado.
    if (driver != _previousDriverPosition) {
      final bool firstPosition = _previousDriverPosition == null;
      _previousDriverPosition = driver;
      if (driver != null && _mapReady && _followDriver) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_mapReady || !_followDriver) return;
          if (firstPosition) {
            _fitVisiblePoints();
          } else {
            _controller.move(driver, _controller.camera.zoom);
          }
        });
      }
    }

    final bool assigned = order.driverId > 0;
    final String subtitle = !assigned
        ? 'Te mostraremos al repartidor cuando esté asignado.'
        : !driverLocated
            ? 'Esperando la primera ubicación GPS del repartidor.'
            : 'Última ubicación informada · puede tener retraso.';

    return TalaCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: Text('Mapa de tu entrega', style: TalaText.h2)),
              StatusPill(
                label: driverLocated ? 'GPS disponible' : 'Esperando GPS',
                color: driverLocated ? kGreen : kInkSoft,
                background: driverLocated ? kSoftGreen : kSunken,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TalaText.caption),
          const SizedBox(height: 12),
          if (driver == null && destination == null)
            Container(
              key: const ValueKey<String>('tracking-map-no-coordinates'),
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: kSunken,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.location_searching_rounded, color: kInkSoft, size: 34),
                      SizedBox(height: 12),
                      Text(
                        'Esperando coordenadas verificadas del pedido.',
                        textAlign: TextAlign.center,
                        style: TalaText.muted,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 258,
                width: double.infinity,
                child: Stack(
                  children: <Widget>[
                    FlutterMap(
                      mapController: _controller,
                      options: MapOptions(
                        initialCenter: destination ?? driver!,
                        initialZoom: 14,
                        initialCameraFit: driver != null &&
                                destination != null &&
                                driver != destination
                            ? CameraFit.bounds(
                                bounds: LatLngBounds.fromPoints(<LatLng>[driver, destination]),
                                padding: const EdgeInsets.all(46),
                                maxZoom: 16,
                              )
                            : null,
                        minZoom: 3,
                        maxZoom: 18,
                        onPositionChanged: (MapCamera camera, bool hasGesture) {
                          if (hasGesture) _followDriver = false;
                        },
                        onMapReady: () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _mapReady = true);
                          });
                        },
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate: _tiles,
                          userAgentPackageName: 'com.talaeats.app',
                          maxZoom: 18,
                        ),
                        MarkerLayer(
                          markers: <Marker>[
                            if (destination != null)
                              Marker(
                                point: destination,
                                height: 52,
                                width: 52,
                                child: Semantics(
                                  label: 'Ubicación de entrega confirmada',
                                  child: const _TrackingPin(
                                    icon: Icons.home_rounded,
                                    color: kGreen,
                                  ),
                                ),
                              ),
                            if (driver != null)
                              Marker(
                                key: ValueKey<String>('driver-marker-${order.id}'),
                                point: driver,
                                height: 52,
                                width: 52,
                                child: Semantics(
                                  label: 'Última ubicación reportada del repartidor',
                                  child: const _TrackingPin(
                                    icon: Icons.two_wheeler_rounded,
                                    color: kBrand,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                        child: IconButton(
                          icon: const Icon(Icons.center_focus_strong_rounded, color: kInk),
                          tooltip: 'Centrar mapa y seguir GPS',
                          onPressed: _mapReady ? _fitVisiblePoints : null,
                          constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(color: kInkSoft, fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: <Widget>[
              if (destinationLocated)
                const _TrackingMapLegend(icon: Icons.home_rounded, label: 'Tu entrega', color: kGreen),
              if (driverLocated)
                const _TrackingMapLegend(icon: Icons.two_wheeler_rounded, label: 'Repartidor', color: kBrand),
            ],
          ),
          const SizedBox(height: 8),
          const QuietNote(
            icon: Icons.info_outline_rounded,
            text: 'La posición se consulta mientras ves el pedido. No es navegación ni una ruta calculada.',
          ),
        ],
      ),
    );
  }
}

class _TrackingPin extends StatelessWidget {
  const _TrackingPin({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: kShadowSoft,
        ),
        child: Icon(icon, color: Colors.white, size: 23),
      ),
    );
  }
}

class _TrackingMapLegend extends StatelessWidget {
  const _TrackingMapLegend({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 4),
        Text(label, style: TalaText.caption),
      ],
    );
  }
}
