import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../api_client.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_icons.dart';
import '../theme/onehub_theme.dart';

/// Where a customer wants work done, or where a provider's business is: an
/// area name for display and the coordinates distances are measured from.
class SavedLocation {
  final String city;
  final double latitude;
  final double longitude;
  const SavedLocation(
      {required this.city, required this.latitude, required this.longitude});

  /// Reads `city`, `latitude` and `longitude` from a user or business JSON
  /// object; null when the coordinates are missing.
  static SavedLocation? fromJson(Map<String, dynamic>? json) {
    final lat = json?['latitude'];
    final lng = json?['longitude'];
    if (lat is! num || lng is! num) return null;
    return SavedLocation(
      city: (json!['city'] as String?)?.trim().isNotEmpty == true
          ? json['city'] as String
          : 'Your location',
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
  }

  Map<String, Object> toJson() =>
      {'city': city, 'latitude': latitude, 'longitude': longitude};

  /// `latitude=..&longitude=..`, for list routes that sort by distance.
  String get query => 'latitude=$latitude&longitude=$longitude';
}

/// "800 m away" under a kilometre, else "3.4 km away".
String distanceLabel(double km) => km < 1
    ? '${(km * 1000).round()} m away'
    : '${km.toStringAsFixed(1)} km away';

/// Why the phone's position could not be read, worded for the user.
class LocationUnavailable implements Exception {
  final String message;
  const LocationUnavailable(this.message);
  @override
  String toString() => message;
}

typedef Position2D = ({double latitude, double longitude});

/// Reads the phone's position. Screens take one of these so tests skip GPS.
typedef PositionFinder = Future<Position2D> Function();

/// Asks the user where they are. Screens take one of these so tests can hand
/// in a location without the sheet.
typedef LocationPicker = Future<SavedLocation?> Function(
    BuildContext context, SavedLocation? current);

/// The default [PositionFinder], through the platform's location service.
/// Asks for permission the first time; throws [LocationUnavailable] when
/// location is off or refused.
Future<Position2D> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationUnavailable(
        'Location is turned off. Turn it on, or pick your area below.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const LocationUnavailable(
        'OneHub is not allowed to use your location. Pick your area below.');
  }
  final p = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
  );
  return (latitude: p.latitude, longitude: p.longitude);
}

/// A sheet offering "Use my current location" (GPS, named after the nearest
/// service area by the API) or a pick from the service areas. Null when the
/// user backs out. Both routes it calls are public, so it works during
/// provider signup too.
Future<SavedLocation?> chooseLocation(
  BuildContext context,
  ApiClient api, {
  SavedLocation? current,
  PositionFinder findPosition = currentPosition,
}) =>
    showModalBottomSheet<SavedLocation>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LocationSheet(
          api: api, current: current, findPosition: findPosition),
    );

class LocationSheet extends StatefulWidget {
  final ApiClient api;
  final SavedLocation? current;
  final PositionFinder findPosition;
  const LocationSheet(
      {super.key,
      required this.api,
      this.current,
      this.findPosition = currentPosition});

  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  List<SavedLocation>? _areas;
  String? _areasError;
  bool _locating = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    try {
      final list = await widget.api.get('/locations/areas') as List;
      if (!mounted) return;
      setState(() => _areas = [
            for (final a in list.cast<Map<String, dynamic>>())
              SavedLocation(
                  city: a['name'] as String,
                  latitude: (a['latitude'] as num).toDouble(),
                  longitude: (a['longitude'] as num).toDouble()),
          ]);
    } catch (_) {
      if (mounted) setState(() => _areasError = 'Could not load the areas.');
    }
  }

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _gpsError = null;
    });
    try {
      final p = await widget.findPosition();
      final place = await widget.api.get(
              '/locations/place?latitude=${p.latitude}&longitude=${p.longitude}')
          as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pop(SavedLocation(
          city: place['city'] as String? ?? 'Your location',
          latitude: p.latitude,
          longitude: p.longitude));
    } on LocationUnavailable catch (e) {
      if (mounted) setState(() => _gpsError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _gpsError =
            'Could not find your location. Try again, or pick your area below.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final areas = _areas;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Choose your location',
                  style: OneHubTextStyles.topBarTitle(textPrimary)),
            ),
            ListTile(
              key: const Key('use-gps'),
              leading: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(OneHubIcons.location,
                      color: OneHubColors.primary),
              title: Text(_locating
                  ? 'Finding your location…'
                  : 'Use my current location'),
              onTap: _locating ? null : _useGps,
            ),
            if (_gpsError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(_gpsError!,
                    style: OneHubTextStyles.bodyText(context.statusDanger)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('OR PICK YOUR AREA',
                  style: OneHubTextStyles.fieldLabel(textMuted)),
            ),
            if (_areasError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(_areasError!,
                    style: OneHubTextStyles.bodyText(context.statusDanger)),
              )
            else if (areas == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final area in areas)
                ListTile(
                  key: Key('area-${area.city}'),
                  title: Text(area.city),
                  trailing: area.city == widget.current?.city
                      ? const Icon(OneHubIcons.successCheck,
                          size: 18, color: OneHubColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(area),
                ),
          ],
        ),
      ),
    );
  }
}

/// Saves the signed-in user's location (PUT /users/me/location) and returns
/// it as the API stored it.
Future<SavedLocation> saveMyLocation(ApiClient api, SavedLocation location) async {
  final json =
      await api.put('/users/me/location', location.toJson(), auth: true);
  return SavedLocation.fromJson(json) ?? location;
}
