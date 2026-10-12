import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'uc_boundaries.dart';

class ComplaintMapScreen extends StatefulWidget {
  const ComplaintMapScreen({super.key});

  @override
  State<ComplaintMapScreen> createState() => _ComplaintMapScreenState();
}

class _ComplaintMapScreenState extends State<ComplaintMapScreen> {
  final _search = TextEditingController();
  String _status = 'All';
  List<SupervisorIssue> _issues = const [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadIssues();
    });
  }

  Future<void> _loadIssues() async {
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() => _loadError = 'Sign in again.');
      return;
    }
    try {
      final rows = await SupervisorApi().issues(session.cnic);
      if (!mounted) return;
      setState(() {
        _issues = rows;
        _loadError = null;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    }
  }

  List<SupervisorIssue> get _visibleIssues {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final issue in _issues)
        if (_matchesStatus(issue) && _matchesQuery(issue, query)) issue,
    ];
  }

  bool _matchesStatus(SupervisorIssue issue) {
    return switch (_status) {
      'Pending' => !issue.resolved,
      'Resolved' => issue.resolved,
      _ => true,
    };
  }

  bool _matchesQuery(SupervisorIssue issue, String query) {
    if (query.isEmpty) return true;
    final haystack = '${issue.id} ${issue.description} ${issue.sector} ${issue.activity} ${issue.loggedBy}'.toLowerCase();
    return haystack.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Complaints Map',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                SearchBarField(
                  controller: _search,
                  hint: 'Search complaints',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilterChips(
                  options: const ['All', 'Pending', 'Resolved'],
                  selected: _status,
                  onSelected: (value) => setState(() => _status = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: _ComplaintsMap(query: _search.text),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                if (_loadError != null)
                  InlineMessage(tone: InlineTone.error, message: _loadError!)
                else if (_visibleIssues.isEmpty)
                  const InlineMessage(message: 'No complaints match this filter.')
                else
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      itemCount: _visibleIssues.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final issue = _visibleIssues[index];
                        return ListItem(
                          title: issue.activity.isEmpty ? 'Complaint ${issue.id}' : issue.activity,
                          subtitle: issue.description.isEmpty ? issue.sector : issue.description,
                          trailing: StatusBadge(
                            label: issue.resolved ? 'Resolved' : 'Pending',
                            color: issue.resolved ? AppColors.success : AppColors.info,
                          ),
                          onTap: () {
                            AppStateScope.read(context).openIssue(issue);
                            context.push(AppRoutes.complaintDetails);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintsMap extends StatefulWidget {
  const _ComplaintsMap({
    required this.query,
    this.initialAreas,
    this.allowFullScreen = true,
  });

  final String query;
  final List<UcArea>? initialAreas;
  final bool allowFullScreen;

  @override
  State<_ComplaintsMap> createState() => _ComplaintsMapState();
}

class _ComplaintsMapState extends State<_ComplaintsMap> {
  static const _islamabad = LatLng(33.6844, 73.0479);
  static const _fills = <Color>[
    Color(0xFF0F766E),
    Color(0xFF1D4ED8),
    Color(0xFFB45309),
    Color(0xFF7C3AED),
    Color(0xFFBE123C),
    Color(0xFF047857),
    Color(0xFF0369A1),
    Color(0xFFA16207),
  ];

  final _controller = MapController();
  final LayerHitNotifier<UcArea> _hits = ValueNotifier(null);
  List<UcArea> _areas = const [];
  bool _loading = true;
  bool _mapReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialAreas;
    if (seeded != null && seeded.isNotEmpty) {
      _areas = seeded;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _hits.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final areas = await loadUcAreas();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _loading = false;
      });
      if (_mapReady) _fit(areas);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Union council boundaries could not be loaded.';
        _loading = false;
      });
    }
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final camera = _controller.camera;
    final next = (camera.zoom + delta).clamp(8.0, 18.0);
    _controller.move(camera.center, next);
  }

  void _openFullMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AppPage(
          title: 'Complaints Map',
          body: _ComplaintsMap(
            query: widget.query,
            initialAreas: _areas,
            allowFullScreen: false,
          ),
        ),
      ),
    );
  }

  void _fit(List<UcArea> areas) {
    if (!_mapReady) return;
    final points = [for (final area in areas) ...area.points];
    if (points.isEmpty) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(16),
        maxZoom: 14,
      ),
    );
  }

  List<UcArea> get _visible =>
      _areas.where((area) => area.matches(widget.query)).toList();

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _islamabad,
            initialZoom: 11,
            minZoom: 8,
            maxZoom: 18,
            onMapReady: () {
              _mapReady = true;
              _fit(_areas);
            },
            onTap: (_, _) {
              final area = _hits.value?.hitValues.firstOrNull;
              if (area != null) _fit([area]);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'pk.gov.cda.cda_clean_islamabad',
            ),
            PolygonLayer<UcArea>(
              hitNotifier: _hits,
              polygonLabels: true,
              drawLabelsLast: true,
              polygons: [
                for (var i = 0; i < visible.length; i++)
                  Polygon<UcArea>(
                    points: visible[i].points,
                    hitValue: visible[i],
                    label: visible[i].code,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Color(0xCC0F172A), blurRadius: 4),
                      ],
                    ),
                    color: _fills[i % _fills.length].withValues(alpha: 0.38),
                    borderColor: _fills[i % _fills.length],
                    borderStrokeWidth: 2,
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              if (widget.allowFullScreen)
                _MapButton(
                  icon: Icons.open_in_full_rounded,
                  tooltip: 'Full map',
                  onPressed: _areas.isEmpty ? null : _openFullMap,
                ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.add_rounded,
                tooltip: 'Zoom in',
                onPressed: _mapReady ? () => _zoomBy(1) : null,
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom out to zones',
                onPressed: _mapReady ? () => _fit(visible) : null,
              ),
            ],
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF12304A), size: 20),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
