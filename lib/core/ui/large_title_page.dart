import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Страница с большим заголовком, который сворачивается при прокрутке,
/// как в нативных iOS-приложениях.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.bottom,
    this.bottomPadding = 32,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;

  /// Закреплённый внизу блок (например, кнопка SOS).
  final Widget? bottom;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: trailing,
            automaticallyImplyLeading: false,
            transitionBetweenRoutes: false,
            backgroundColor: c.bg.withValues(alpha: 0.9),
            border: null,
          ),
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
        ],
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// Страница-модалка с обычной нав-панелью (закрытие слева).
class ModalPage extends StatelessWidget {
  const ModalPage({
    super.key,
    required this.title,
    required this.child,
    this.closeLabel = 'Закрыть',
  });

  final String title;
  final Widget child;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Scaffold нужен, чтобы SnackBar показывался поверх этой страницы,
    // а не под ней.
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(
        middle: Text(title),
        backgroundColor: c.bg.withValues(alpha: 0.9),
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(closeLabel),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}
