import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';

const _pickerMethodChannel = MethodChannel('clrpkr/methods');
const _pickerEventChannel = EventChannel('clrpkr/picks');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClrPkrApp());
}

class ClrPkrApp extends StatelessWidget {
  const ClrPkrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClrPkr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3F3F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.light,
          surface: const Color(0xFFF3F3F5),
        ),
        useMaterial3: true,
      ),
      home: const ClrPkrHome(),
    );
  }
}

enum ColorFormat {
  hex('HEX'),
  rgb('RGB'),
  hsl('HSL'),
  swiftUi('SwiftUI');

  const ColorFormat(this.label);
  final String label;
}

class PickedColor {
  const PickedColor({
    required this.id,
    required this.color,
    required this.previewPng,
    required this.pickedAt,
  });

  final String id;
  final Color color;
  final Uint8List? previewPng;
  final DateTime pickedAt;

  int get red => (color.r * 255).round().clamp(0, 255);
  int get green => (color.g * 255).round().clamp(0, 255);
  int get blue => (color.b * 255).round().clamp(0, 255);
}

class ClrPkrHome extends StatefulWidget {
  const ClrPkrHome({super.key});

  @override
  State<ClrPkrHome> createState() => _ClrPkrHomeState();
}

class _ClrPkrHomeState extends State<ClrPkrHome> {
  final List<PickedColor> _history = <PickedColor>[];
  StreamSubscription<dynamic>? _pickSubscription;
  ColorFormat _format = ColorFormat.hex;

  @override
  void initState() {
    super.initState();
    _pickSubscription = _pickerEventChannel.receiveBroadcastStream().listen(
      _handleNativePick,
      onError: (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The macOS picker bridge is unavailable.'),
          ),
        );
      },
    );
    _syncMenu();
  }

  @override
  void dispose() {
    _pickSubscription?.cancel();
    super.dispose();
  }

  Future<void> _syncMenu() async {
    final items = _history.take(10).map((item) {
      return <String, String>{
        'title': _formatColor(item, _format),
        'copyText': _formatColor(item, _format),
      };
    }).toList();

    try {
      await _pickerMethodChannel.invokeMethod<void>(
        'updateMenu',
        <String, dynamic>{'recentPicks': items},
      );
    } catch (_) {
      // Best-effort menu sync; the app still works without it.
    }
  }

  void _handleNativePick(dynamic event) {
    if (event is! Map<Object?, Object?>) {
      return;
    }

    final red = (event['r'] as num?)?.toInt();
    final green = (event['g'] as num?)?.toInt();
    final blue = (event['b'] as num?)?.toInt();
    if (red == null || green == null || blue == null) {
      return;
    }

    final previewBytes = switch (event['previewPng']) {
      final Uint8List bytes => bytes,
      final ByteData bytes => bytes.buffer.asUint8List(),
      _ => null,
    };

    final item = PickedColor(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      color: Color.fromARGB(255, red, green, blue),
      previewPng: previewBytes,
      pickedAt: DateTime.now(),
    );

    setState(() {
      _history.insert(0, item);
    });
    _syncMenu();
  }

  Future<void> _copyColor(PickedColor item) async {
    final clipboard = SystemClipboard.instance;
    final value = _formatColor(item, _format);

    try {
      if (clipboard != null) {
        final writer = DataWriterItem()..add(Formats.plainText(value));
        await clipboard.write(<DataWriterItem>[writer]);
      } else {
        await Clipboard.setData(ClipboardData(text: value));
      }

      if (!mounted) {
        return;
      }
      _syncMenu();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Copied $value')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clipboard copy failed.')));
    }
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
    });
    _syncMenu();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoSlidingSegmentedControl<ColorFormat>(
                  groupValue: _format,
                  children: {
                    for (final item in ColorFormat.values)
                      item: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(item.label),
                      ),
                  },
                  onValueChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _format = value;
                      });
                      _syncMenu();
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _NativePanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: _history.isEmpty
                            ? Center(
                                child: Text(
                                  'Use Pick in the toolbar to capture a color.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF6B7280),
                                      ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(10),
                                itemBuilder: (context, index) {
                                  final item = _history[index];
                                  return _HistoryRow(
                                    item: item,
                                    format: _format,
                                    onTap: () => _copyColor(item),
                                  );
                                },
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemCount: _history.length,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text(
                    _history.isEmpty ? '0 picks' : '${_history.length} picks',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: _history.isEmpty ? null : _clearHistory,
                    child: const Text('Clear History'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({
    required this.item,
    required this.format,
    required this.onTap,
  });

  final PickedColor item;
  final ColorFormat format;
  final VoidCallback onTap;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hovered = false;
  int _copiedBurst = 0;

  @override
  Widget build(BuildContext context) {
    final showTrailing = _hovered;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: MouseRegion(
        onEnter: (_) => setState(() {
          _hovered = true;
        }),
        onExit: (_) => setState(() {
          _hovered = false;
        }),
        child: InkWell(
          onTap: () {
            setState(() {
              _copiedBurst++;
            });
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: widget.item.color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x14000000)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.item.previewPng == null
                      ? null
                      : Image.memory(
                          widget.item.previewPng!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.none,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _formatColor(widget.item, widget.format),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'SF Mono',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: widget.item.color,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0x14000000)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatColor(widget.item, ColorFormat.hex),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 28,
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerRight,
                    children: <Widget>[
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: showTrailing ? 1 : 0,
                        child: const Icon(
                          Icons.content_copy_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (_copiedBurst > 0)
                        TweenAnimationBuilder<double>(
                          key: ValueKey<int>(_copiedBurst),
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 360),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, -8 * value),
                              child: Opacity(
                                opacity: 1 - value,
                                child: child,
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.content_copy_rounded,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NativePanel extends StatelessWidget {
  const _NativePanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

String _formatColor(PickedColor item, ColorFormat format) {
  return switch (format) {
    ColorFormat.hex =>
      '#${item.red.toRadixString(16).padLeft(2, '0').toUpperCase()}${item.green.toRadixString(16).padLeft(2, '0').toUpperCase()}${item.blue.toRadixString(16).padLeft(2, '0').toUpperCase()}',
    ColorFormat.rgb => 'rgb(${item.red}, ${item.green}, ${item.blue})',
    ColorFormat.hsl => _formatHsl(item),
    ColorFormat.swiftUi =>
      'Color(red: ${(item.red / 255).toStringAsFixed(3)}, green: ${(item.green / 255).toStringAsFixed(3)}, blue: ${(item.blue / 255).toStringAsFixed(3)})',
  };
}

String _formatHsl(PickedColor item) {
  final r = item.red / 255;
  final g = item.green / 255;
  final b = item.blue / 255;
  final maxValue = math.max(r, math.max(g, b));
  final minValue = math.min(r, math.min(g, b));
  final delta = maxValue - minValue;

  double hue = 0;
  final lightness = (maxValue + minValue) / 2;
  final saturation = delta == 0 ? 0 : delta / (1 - (2 * lightness - 1).abs());

  if (delta != 0) {
    if (maxValue == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (maxValue == g) {
      hue = 60 * (((b - r) / delta) + 2);
    } else {
      hue = 60 * (((r - g) / delta) + 4);
    }
  }

  if (hue < 0) {
    hue += 360;
  }

  return 'hsl(${hue.round()} ${(saturation * 100).round()}% ${(lightness * 100).round()}%)';
}
