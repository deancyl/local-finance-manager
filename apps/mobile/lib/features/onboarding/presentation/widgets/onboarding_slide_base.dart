import 'package:flutter/material.dart';

/// Base slide widget for onboarding pages
class OnboardingSlide extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final List<Widget>? features;
  
  const OnboardingSlide({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    this.features,
  });
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with decorative background
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: (iconColor ?? colorScheme.primary).withOpacity(0.15),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              icon,
              size: 64,
              color: iconColor ?? colorScheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          
          // Title (bilingual)
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Subtitle
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Additional features if provided
          if (features != null && features!.isNotEmpty) ...[
            const SizedBox(height: 32),
            ...features!,
          ],
        ],
      ),
    );
  }
}

/// Feature item widget for onboarding slides
class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? color;
  
  const FeatureItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final effectiveColor = color ?? colorScheme.primary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: effectiveColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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