import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/theme_controller.dart';
import 'neomorphic_container.dart';
import 'orbit_loader.dart';
import 'tap_scale.dart';

class LinkInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const LinkInputField({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSearch,
    required this.onClear,
  });

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      controller.text = data!.text!.trim();
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return NeomorphicContainer(
          style: NeoStyle.pressed,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: colors.textPrimary, fontSize: 15),
                  cursorColor: colors.accent,
                  decoration: InputDecoration(
                    hintText: 'Paste a video or audio link',
                    hintStyle: TextStyle(
                      color: colors.textFaint,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  if (controller.text.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TapScale(
                      onTap: () {
                        controller.clear();
                        onClear();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadowDark,
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                            BoxShadow(
                              color: colors.shadowLight,
                              offset: const Offset(-2, -2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              TapScale(
                onTap: _paste,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadowDark,
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                      BoxShadow(
                        color: colors.shadowLight,
                        offset: const Offset(-2, -2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.content_paste_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TapScale(
                onTap: isLoading ? null : onSearch,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.videoStart, colors.videoEnd],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadowDark,
                        offset: const Offset(3, 3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: isLoading
                      ? const OrbitLoader(size: 22)
                      : const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
