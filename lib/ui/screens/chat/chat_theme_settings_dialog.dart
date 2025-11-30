import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/providers/chat_theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

/// Dialog for customizing chat theme settings
class ChatThemeSettingsDialog extends StatefulWidget {
  const ChatThemeSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChatThemeSettingsDialog(),
    );
  }

  @override
  State<ChatThemeSettingsDialog> createState() =>
      _ChatThemeSettingsDialogState();
}

class _ChatThemeSettingsDialogState extends State<ChatThemeSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Iconsax.paintbucket,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  loc.t('chat_appearance'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    context.read<ChatThemeProvider>().resetToDefaults();
                  },
                  child: Text(loc.t('reset')),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: loc.t('themes')),
              Tab(text: loc.t('colors')),
              Tab(text: loc.t('style')),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildThemesTab(context, isDark),
                _buildColorsTab(context, isDark),
                _buildStyleTab(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemesTab(BuildContext context, bool isDark) {
    return Consumer<ChatThemeProvider>(
      builder: (context, provider, _) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: ChatThemeProvider.themes.length,
          itemBuilder: (context, index) {
            final themeName = ChatThemeProvider.themes.keys.elementAt(index);
            final themeConfig = ChatThemeProvider.themes[themeName]!;
            final isSelected = provider.currentThemeName == themeName;

            return GestureDetector(
              onTap: () => provider.setTheme(themeName),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: themeConfig.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected ? AppTheme.primaryColor : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Preview bubbles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // AI bubble
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: themeConfig.aiBubbleColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Hi!',
                            style: TextStyle(
                              color: themeConfig.aiTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // User bubble
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: themeConfig.userBubbleColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Hello!',
                            style: TextStyle(
                              color: themeConfig.userTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Theme name
                    Text(
                      themeConfig.name,
                      style: TextStyle(
                        color: themeConfig.aiTextColor.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Iconsax.tick_circle5,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorsTab(BuildContext context, bool isDark) {
    final loc = AppLocalizations.of(context);

    return Consumer<ChatThemeProvider>(
      builder: (context, provider, _) {
        final theme = provider.currentTheme;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User bubble color
            _buildColorPicker(
              context: context,
              title: loc.t('your_messages'),
              subtitle: loc.t('customize_your_bubble_color'),
              currentColor:
                  provider.customUserBubbleColor ?? theme.userBubbleColor,
              onColorChanged: (color) => provider.setUserBubbleColor(color),
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // AI bubble color
            _buildColorPicker(
              context: context,
              title: loc.t('ai_messages'),
              subtitle: loc.t('customize_ai_bubble_color'),
              currentColor: provider.customAiBubbleColor ?? theme.aiBubbleColor,
              onColorChanged: (color) => provider.setAiBubbleColor(color),
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Color presets
            Text(
              loc.t('quick_colors'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in _presetColors)
                  GestureDetector(
                    onTap: () => provider.setUserBubbleColor(color),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: provider.customUserBubbleColor == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStyleTab(BuildContext context, bool isDark) {
    final loc = AppLocalizations.of(context);

    return Consumer<ChatThemeProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Font size slider
            _buildSettingTile(
              context,
              icon: Iconsax.text,
              title: loc.t('font_size'),
              subtitle: '${provider.fontSize.round()}px',
              child: Slider(
                value: provider.fontSize,
                min: 10,
                max: 24,
                divisions: 14,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) => provider.setFontSize(value),
              ),
              isDark: isDark,
            ),
            const Divider(),

            // Bubble radius slider
            _buildSettingTile(
              context,
              icon: Iconsax.shapes,
              title: loc.t('bubble_roundness'),
              subtitle: '${provider.bubbleRadius.round()}px',
              child: Slider(
                value: provider.bubbleRadius,
                min: 4,
                max: 32,
                divisions: 14,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) => provider.setBubbleRadius(value),
              ),
              isDark: isDark,
            ),
            const Divider(),

            // Font family dropdown
            _buildSettingTile(
              context,
              icon: Iconsax.text_block,
              title: loc.t('font_family'),
              subtitle: provider.fontFamily,
              child: DropdownButton<String>(
                value: provider.fontFamily,
                isExpanded: true,
                underline: const SizedBox(),
                items: ChatThemeProvider.fontFamilies.map((font) {
                  return DropdownMenuItem(
                    value: font,
                    child: Text(
                      font,
                      style: TextStyle(
                        fontFamily: font == 'Default' ? null : font,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) provider.setFontFamily(value);
                },
              ),
              isDark: isDark,
            ),
            const Divider(),

            // Show timestamps toggle
            SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.clock, color: AppTheme.primaryColor),
              ),
              title: Text(loc.t('show_timestamps')),
              subtitle: Text(loc.t('show_message_time')),
              value: provider.showTimestamps,
              activeColor: AppTheme.primaryColor,
              onChanged: (value) => provider.setShowTimestamps(value),
            ),
            const Divider(),

            // Show avatars toggle
            SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.user, color: AppTheme.primaryColor),
              ),
              title: Text(loc.t('show_avatars')),
              subtitle: Text(loc.t('show_profile_pictures')),
              value: provider.showAvatars,
              activeColor: AppTheme.primaryColor,
              onChanged: (value) => provider.setShowAvatars(value),
            ),

            const SizedBox(height: 24),

            // Preview section
            Text(
              loc.t('preview'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildPreviewBubbles(provider),
          ],
        );
      },
    );
  }

  Widget _buildColorPicker({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color currentColor,
    required Function(Color) onColorChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Hue slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 16,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackShape: _GradientTrackShape(),
            ),
            child: Slider(
              value: HSVColor.fromColor(currentColor).hue,
              min: 0,
              max: 360,
              onChanged: (hue) {
                final hsv = HSVColor.fromColor(currentColor);
                onColorChanged(
                    HSVColor.fromAHSV(1, hue, hsv.saturation, hsv.value)
                        .toColor());
              },
            ),
          ),
          const SizedBox(height: 8),
          // Saturation slider
          Slider(
            value: HSVColor.fromColor(currentColor).saturation,
            min: 0,
            max: 1,
            activeColor: currentColor,
            onChanged: (sat) {
              final hsv = HSVColor.fromColor(currentColor);
              onColorChanged(
                  HSVColor.fromAHSV(1, hsv.hue, sat, hsv.value).toColor());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildPreviewBubbles(ChatThemeProvider provider) {
    final theme = provider.currentTheme;
    final radius = Radius.circular(provider.bubbleRadius);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AI message
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: provider.customAiBubbleColor ?? theme.aiBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: const Radius.circular(4),
                  bottomRight: radius,
                ),
              ),
              child: Text(
                'Hello! How can I help you today?',
                style: TextStyle(
                  color: theme.aiTextColor,
                  fontSize: provider.fontSize,
                  fontFamily: provider.fontFamily == 'Default'
                      ? null
                      : provider.fontFamily,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // User message
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: provider.customUserBubbleColor ?? theme.userBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: radius,
                  bottomRight: const Radius.circular(4),
                ),
              ),
              child: Text(
                'This is a **preview** of the chat!',
                style: TextStyle(
                  color: theme.userTextColor,
                  fontSize: provider.fontSize,
                  fontFamily: provider.fontFamily == 'Default'
                      ? null
                      : provider.fontFamily,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<Color> _presetColors = [
    Color(0xFF6C63FF), // Default purple
    Color(0xFF00D4FF), // Cyan
    Color(0xFFFF6584), // Pink
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFE91E63), // Rose
    Color(0xFF9C27B0), // Purple
    Color(0xFF2196F3), // Blue
    Color(0xFF009688), // Teal
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF795548), // Brown
  ];
}

/// Custom track shape for hue slider with rainbow gradient
class _GradientTrackShape extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = true,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final gradient = LinearGradient(
      colors: List.generate(
        360,
        (i) => HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor(),
      ),
    );

    final paint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(sliderTheme.trackHeight! / 2),
    );

    context.canvas.drawRRect(rrect, paint);
  }
}
