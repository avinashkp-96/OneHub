import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

/// Two-column grid of [ServiceTile]s, sized to its content so it can sit
/// inside a scrolling page. Used by signup step 2 and Business details.
class ServiceGrid extends StatelessWidget {
  final List<Widget> children;
  const ServiceGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: children,
    );
  }
}

/// A selectable category or service tile: icon circle (the category's image
/// when it has one), a check when selected, and the name.
class ServiceTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final IconData fallbackIcon;
  final bool selected;
  final VoidCallback? onTap;
  const ServiceTile({
    super.key,
    required this.label,
    required this.fallbackIcon,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final iconFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        side: BorderSide(
            color: selected ? OneHubColors.primary : cardBorder,
            width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconFill,
                      border: Border.all(color: cardBorder),
                      image: imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(imageUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: imageUrl == null
                        ? Icon(fallbackIcon, color: textPrimary, size: 18)
                        : null,
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(OneHubIcons.confirmed,
                        size: 20, color: OneHubColors.primary),
                ],
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OneHubTextStyles.bodyText(textPrimary)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
