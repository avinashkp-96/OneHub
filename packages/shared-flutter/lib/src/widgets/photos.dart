import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_icons.dart';
import '../theme/onehub_theme.dart';

/// An image the user picked, ready to upload.
class PickedPhoto {
  final Uint8List bytes;
  final String name;
  const PickedPhoto(this.bytes, this.name);
}

/// Asks the user for one photo. Screens take one of these so tests can hand
/// in a photo without the platform picker.
typedef PhotoPicker = Future<PickedPhoto?> Function(BuildContext context);

/// The default [PhotoPicker]: a sheet offering the camera or the gallery, then
/// the platform picker. Photos are scaled to at most 1600px and re-encoded at
/// 80% quality on the phone, which keeps uploads well under the API's 5 MB
/// limit. Null when the user backs out.
Future<PickedPhoto?> choosePhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(OneHubIcons.camera),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(OneHubIcons.image),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final file = await ImagePicker()
      .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
  if (file == null) return null;
  return PickedPhoto(await file.readAsBytes(), file.name);
}

/// One square photo with rounded corners. A photo that cannot load shows a
/// muted image icon instead of an error.
class PhotoThumb extends StatelessWidget {
  final String url;
  final double size;
  final VoidCallback? onTap;
  const PhotoThumb(
      {super.key, required this.url, this.size = 72, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final muted = dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final radius = BorderRadius.circular(OneHubTheme.radiusInputField);

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: fill, borderRadius: radius, border: Border.all(color: border)),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(OneHubIcons.image, size: 20, color: muted),
        ),
      ),
    );
  }
}

/// A row of request photos that wraps; tapping one opens [PhotoViewer] at it.
class PhotoStrip extends StatelessWidget {
  final List<String> urls;
  const PhotoStrip({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < urls.length; i++)
          PhotoThumb(
            key: Key('photo-$i'),
            url: urls[i],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PhotoViewer(urls: urls, initialIndex: i))),
          ),
      ],
    );
  }
}

/// Photos full screen on black, one at a time: swipe between them, pinch to
/// zoom, "2 of 3" in the top bar.
class PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const PhotoViewer({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _index = widget.initialIndex;
  late final _pages = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text('${_index + 1} of ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.urls[i],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(OneHubIcons.image,
                  size: 40, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round account picture: the photo when there is one, else the name's
/// initial on the brand gradient. With [onTap] it carries a small camera badge
/// and shows a spinner while [busy].
class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  final VoidCallback? onTap;
  final bool busy;
  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 56,
    this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [OneHubColors.primary, OneHubColors.primaryGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: photo == null
            ? null
            : DecorationImage(
                image: NetworkImage(photo),
                fit: BoxFit.cover,
                onError: (_, __) {}),
      ),
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : photo == null
              ? Text(initial,
                  style: OneHubTextStyles.pageHeading(Colors.white)
                      .copyWith(fontSize: size * 0.4))
              : null,
    );
    if (onTap == null) return circle;

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Change photo',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            circle,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OneHubColors.primary,
                  border: Border.all(
                      color: dark
                          ? OneHubColors.surfaceDark
                          : OneHubColors.surfaceLight,
                      width: 2),
                ),
                child: const Icon(OneHubIcons.camera,
                    size: 11, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
