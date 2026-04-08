import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_input.dart';
import 'package:http/http.dart' as http;

class CreateCapsuleScreen extends ConsumerStatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  ConsumerState<CreateCapsuleScreen> createState() =>
      _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends ConsumerState<CreateCapsuleScreen> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _mapCtrl = MapController();

  DateTime _unlockDate = DateTime.now().add(const Duration(days: 1));
  bool _isPublic = true;
  int _tolerance = 50;
  LatLng _pin = const LatLng(40.7128, -74.006);
  List<File> _images = [];
  bool _loading = false;
  String? _titleError, _msgError;
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _showMap = true;
  bool _detectingLocation = true;
  String? _locationLabel;

  // Friend tagging for private capsules
  String? _receiverId;
  String? _receiverName;
  List<Map<String, dynamic>> _contacts = [];
  bool _loadingContacts = false;
  bool _showFriendPicker = false;

  @override
  void initState() {
    super.initState();
    _detectCurrentLocation();
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _detectingLocation = true);
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _detectingLocation = false);
        return;
      }

      // Check & request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _detectingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _detectingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _pin = LatLng(position.latitude, position.longitude);
          _detectingLocation = false;
        });
        // Move map to detected location
        try {
          _mapCtrl.move(_pin, 15);
        } catch (_) {}

        // Reverse geocode for label
        _reverseGeocode(position.latitude, position.longitude);
      }
    } catch (_) {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&zoom=16',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'TimeCapsuleFlutter/1.0'},
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final name = data['display_name'] as String?;
      if (name != null && mounted) {
        setState(() {
          _locationLabel = name.split(',').take(2).join(',').trim();
          _searchCtrl.text = _locationLabel!;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadContacts() async {
    if (_contacts.isNotEmpty) return;
    setState(() => _loadingContacts = true);
    try {
      final res = await dioClient.get('/chats/contacts');
      final list = (res.data as List<dynamic>).cast<Map<String, dynamic>>();
      setState(() => _contacts = list);
    } catch (_) {
    } finally {
      setState(() => _loadingContacts = false);
    }
  }

  Future<void> _searchLocation(String q) async {
    if (q.length < 2) return;
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=5',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'TimeCapsuleFlutter/1.0'},
      );
      final data = jsonDecode(res.body) as List<dynamic>;
      setState(() => _searchResults = data.cast<Map<String, dynamic>>());
    } catch (_) {
    } finally {
      setState(() => _searching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> r) {
    final lat = double.parse(r['lat'] as String);
    final lng = double.parse(r['lon'] as String);
    final name = (r['display_name'] as String).split(',')[0];
    setState(() {
      _pin = LatLng(lat, lng);
      _searchCtrl.text = name;
      _locationLabel = name;
      _searchResults = [];
    });
    _mapCtrl.move(_pin, 14);
  }

  Future<void> _pickImages() async {
    if (_images.length >= 5) return;
    final res = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (res.isNotEmpty) {
      final picked = res
          .take(5 - _images.length)
          .map((e) => File(e.path))
          .toList();
      setState(() => _images = [..._images, ...picked]);
    }
  }

  void _validate() {
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty ? 'Title is required' : null;
      _msgError = _msgCtrl.text.trim().isEmpty ? 'Message is required' : null;
    });
  }

  Future<void> _create() async {
    _validate();
    if (_titleError != null || _msgError != null) return;
    setState(() => _loading = true);
    try {
      final formMap = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'latitude': _pin.latitude.toString(),
        'longitude': _pin.longitude.toString(),
        'unlockDate': _unlockDate.toUtc().toIso8601String(),
        'isPublic': _isPublic.toString(),
        'pointsReward': '0',
        'proximityTolerance': _tolerance.toString(),
        if (_receiverId != null) 'receiverUserId': _receiverId,
      };
      final form = FormData.fromMap(formMap);
      for (int i = 0; i < _images.length; i++) {
        form.files.add(
          MapEntry(
            'mediaFiles',
            await MultipartFile.fromFile(
              _images[i].path,
              filename: 'img_$i.jpg',
            ),
          ),
        );
      }
      await dioClient.post('/capsules', data: form);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create capsule')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Capsule')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassInput(
              label: 'Title',
              hint: 'Capsule title',
              controller: _titleCtrl,
              errorText: _titleError,
              onBlur: _validate,
            ),
            const SizedBox(height: 12),
            GlassInput(
              label: 'Message',
              hint: 'Your message to the future...',
              controller: _msgCtrl,
              maxLines: 4,
              errorText: _msgError,
              onBlur: _validate,
            ),
            const SizedBox(height: 12),

            // ── Unlock Date ────────────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock Date',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _unlockDate,
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 10),
                        ),
                      );
                      if (picked != null) setState(() => _unlockDate = picked);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_unlockDate.day}/${_unlockDate.month}/${_unlockDate.year}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Location Picker ────────────────────────────────────────────
            GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_detectingLocation) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Detecting...',
                          style: TextStyle(fontSize: 11, color: scheme.primary),
                        ),
                      ] else if (_locationLabel != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Colors.green,
                        ),
                      ],
                      const Spacer(),
                      // My Location button
                      GestureDetector(
                        onTap: _detectingLocation
                            ? null
                            : _detectCurrentLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.primary.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 13,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'My Location',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _showMap = !_showMap),
                        child: Text(
                          _showMap ? 'Hide map' : 'Show map',
                          style: TextStyle(color: scheme.primary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Search bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            isDense: true,
                            prefixIcon: Icon(
                              Icons.search,
                              size: 18,
                              color: scheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: scheme.primary.withAlpha(60),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: scheme.primary.withAlpha(40),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: scheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: _searchLocation,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      if (_searching) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Search results dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1D3D) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scheme.primary.withAlpha(50)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        children: _searchResults.map((r) {
                          final name = r['display_name'] as String;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _selectSearchResult(r),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Interactive map
                  if (_showMap)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 240,
                        child: FlutterMap(
                          mapController: _mapCtrl,
                          options: MapOptions(
                            initialCenter: _pin,
                            initialZoom: 15,
                            onTap: (tapPos, latLng) {
                              setState(() {
                                _pin = latLng;
                                _locationLabel = null;
                              });
                              _reverseGeocode(
                                latLng.latitude,
                                latLng.longitude,
                              );
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.timecapsule.time_capsule_flutter',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _pin,
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      // dragging handled by onTap for simplicity;
                                      // tap anywhere on map to repin
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: scheme.primary.withAlpha(
                                                  120,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.push_pin_rounded,
                                            size: 16,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                        Container(
                                          width: 2,
                                          height: 8,
                                          color: scheme.primary.withAlpha(180),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),
                  // Coordinates display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 14,
                        color: scheme.onSurface.withAlpha(120),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _locationLabel != null
                              ? '$_locationLabel (${_pin.latitude.toStringAsFixed(4)}, ${_pin.longitude.toStringAsFixed(4)})'
                              : '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withAlpha(150),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Settings ───────────────────────────────────────────────────
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Visibility',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      Switch(
                        value: _isPublic,
                        onChanged: (v) {
                          setState(() {
                            _isPublic = v;
                            _receiverId = null;
                            _receiverName = null;
                            _showFriendPicker = false;
                          });
                          if (!v) _loadContacts();
                        },
                        activeThumbColor: scheme.primary,
                      ),
                      Text(
                        _isPublic ? 'Public' : 'Private',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),

                  // Friend picker — shown when Private
                  if (!_isPublic) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tag a friend (optional)',
                          style: TextStyle(
                            color: scheme.onSurface.withAlpha(180),
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        if (_receiverName != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _receiverId = null;
                              _receiverName = null;
                            }),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: scheme.error,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_receiverName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.primary.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _receiverName!,
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => setState(
                          () => _showFriendPicker = !_showFriendPicker,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.primary.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 16,
                                color: scheme.onSurface.withAlpha(120),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Select a friend...',
                                style: TextStyle(
                                  color: scheme.onSurface.withAlpha(120),
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showFriendPicker
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                                color: scheme.onSurface.withAlpha(120),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_showFriendPicker && _receiverName == null) ...[
                      const SizedBox(height: 6),
                      _loadingContacts
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              ),
                            )
                          : _contacts.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'No contacts found',
                                style: TextStyle(
                                  color: scheme.onSurface.withAlpha(120),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1A1D3D)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: scheme.primary.withAlpha(40),
                                ),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _contacts.length,
                                itemBuilder: (_, i) {
                                  final c = _contacts[i];
                                  final uid = c['userId'] as String? ?? '';
                                  final name =
                                      c['displayName'] as String? ?? '';
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => setState(() {
                                      _receiverId = uid;
                                      _receiverName = name;
                                      _showFriendPicker = false;
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: scheme.primary
                                                .withAlpha(40),
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: scheme.primary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Proximity',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      for (final t in [5, 50])
                        GestureDetector(
                          onTap: () => setState(() => _tolerance = t),
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _tolerance == t
                                  ? scheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _tolerance == t
                                    ? scheme.primary
                                    : scheme.onSurface.withAlpha(80),
                              ),
                            ),
                            child: Text(
                              '${t}m',
                              style: TextStyle(
                                color: _tolerance == t
                                    ? (isDark ? Colors.black : Colors.white)
                                    : null,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Media ──────────────────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media (up to 5)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._images.asMap().entries.map(
                        (e) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                e.value,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _images.removeAt(e.key)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: scheme.error,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_images.length < 5)
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: scheme.primary.withAlpha(120),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              color: scheme.primary,
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassButton(
              title: 'Create Capsule',
              onPressed: _create,
              loading: _loading,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
