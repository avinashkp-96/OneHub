import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

/// "Choose location" until one is picked, then the area's name and "Change".
/// Signup step 3 and Business details both use it for where the business is.
class LocationField extends StatelessWidget {
  final SavedLocation? location;
  final VoidCallback? onPressed;
  const LocationField({super.key, this.location, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final picked = location;
    return Row(
      children: [
        OutlinedButton.icon(
          key: const Key('choose-location'),
          onPressed: onPressed,
          icon: const Icon(OneHubIcons.location, size: 16),
          label: Text(picked == null ? 'Choose location' : 'Change'),
        ),
        if (picked != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(picked.city,
                key: const Key('location-name'),
                overflow: TextOverflow.ellipsis,
                style: OneHubTextStyles.bodyText(textPrimary)
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}
