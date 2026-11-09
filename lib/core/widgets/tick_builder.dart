import 'dart:async';

import 'package:flutter/widgets.dart';

/// Перестраивает [builder] с текущим временем каждые [interval].
class TickBuilder extends StatefulWidget {
  const TickBuilder({
    super.key,
    this.interval = const Duration(seconds: 1),
    required this.builder,
  });

  final Duration interval;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<TickBuilder> createState() => _TickBuilderState();
}

class _TickBuilderState extends State<TickBuilder> {
  Timer? _timer;
  bool _active = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Скрытые вкладки (IndexedStack) отключают TickerMode — не тикаем зря.
    _active = TickerMode.valuesOf(context).enabled;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted && _active) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}
