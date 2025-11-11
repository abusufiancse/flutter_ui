import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

typedef GyroscopeEffectBuilder = Widget Function(
    BuildContext context, Offset offset, Widget? child);

class GyroscopeEffect extends StatefulWidget {
  /// Use this when you want to wrap a child and have gyroscope motion applied.
  const GyroscopeEffect({
    Key? key,
    required this.child,
    this.maxMovableDistance = 10,
    this.offsetMultiplier = 1,
    this.childBuilder,
  })  : super(key: key);

  /// Use this when you want to build the widget with a builder callback.
  const GyroscopeEffect.builder({
    Key? key,
    this.child,
    this.maxMovableDistance = 10,
    this.offsetMultiplier = 1,
    required this.childBuilder,
  }) : super(key: key);

  final Widget? child;
  final double maxMovableDistance;
  final double offsetMultiplier;
  final GyroscopeEffectBuilder? childBuilder;

  @override
  State<GyroscopeEffect> createState() => _GyroscopeEffectState();
}

class _GyroscopeEffectState extends State<GyroscopeEffect> {
  double _x = 0.0; // integrated sensor x
  double _y = 0.0; // integrated sensor y

  // small damping so the motion does not drift too much
  static const double _damping = 0.85;
  // sensitivity to multiply incoming gyro deltas
  static const double _sensitivity = 1.2;

  @override
  Widget build(BuildContext context) {
    // On web and some desktop platforms sensors are not (reliably) present.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return _buildChild(context, Offset.zero);
    }

    return StreamBuilder<GyroscopeEvent>(
      // <--- IMPORTANT: provide the gyroscope stream
      stream: gyroscopeEvents,
      builder: (context, AsyncSnapshot<GyroscopeEvent> snapshot) {
        if (snapshot.hasData) {
          final ev = snapshot.data!;
          // gyroscope gives angular velocity in rad/s. We'll integrate with damping.
          // Map axes: device axes differ between devices; this is a sensible default.
          final dx = ev.y * _sensitivity;
          final dy = ev.x * _sensitivity;

          // integrate with damping (simple low-pass-ish behavior)
          _x = (_x * _damping) + dx * (1 - _damping);
          _y = (_y * _damping) + dy * (1 - _damping);

          // clamp to allowed range
          _x = _x.clamp(-widget.maxMovableDistance, widget.maxMovableDistance);
          _y = _y.clamp(-widget.maxMovableDistance, widget.maxMovableDistance);
        }

        final offset = Offset(-_y, -_x) * widget.offsetMultiplier;
        return _buildChild(context, offset);
      },
    );
  }

  Widget _buildChild(BuildContext context, Offset offset) {
    // If a builder is provided, prefer it — builder receives offset and optional child
    if (widget.childBuilder != null) {
      return widget.childBuilder!.call(context, offset, widget.child);
    }

    // Otherwise require a child to wrap
    final child = widget.child;
    if (child == null) {
      // defensively return empty box if nothing was provided
      return const SizedBox.shrink();
    }

    // Use AnimatedContainer + transform so this widget works anywhere (no Stack required)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
      child: child,
    );
  }
}
