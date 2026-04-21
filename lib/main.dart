import 'dart:async';
import 'dart:math' as math;
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
    const paper = Color(0xFFF7F0E4);
    const ink = Color(0xFF2E2923);

    return MaterialApp(
      title: 'ClrPkr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF60755C),
          brightness: Brightness.light,
          surface: paper,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
          fontFamily: 'Georgia',
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
  bool _pickerBusy = false;
  String? _lastCopiedId;

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
  }

  @override
  void dispose() {
    _pickSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startPicker() async {
    if (_pickerBusy) {
      return;
    }

    setState(() {
      _pickerBusy = true;
    });

    try {
      await _pickerMethodChannel.invokeMethod<void>('startPicker');
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to start picker.')),
      );
      setState(() {
        _pickerBusy = false;
      });
    }
  }

  void _handleNativePick(dynamic event) {
    if (event is! Map<Object?, Object?>) {
      setState(() {
        _pickerBusy = false;
      });
      return;
    }

    final red = (event['r'] as num?)?.toInt();
    final green = (event['g'] as num?)?.toInt();
    final blue = (event['b'] as num?)?.toInt();
    if (red == null || green == null || blue == null) {
      setState(() {
        _pickerBusy = false;
      });
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
      _pickerBusy = false;
      _history.insert(0, item);
    });
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
      setState(() {
        _lastCopiedId = item.id;
      });
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
      _lastCopiedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const shell = Color(0xFFEAE0CF);
    const panel = Color(0xFFFDF8EF);
    const trim = Color(0xFF6A7F5F);
    const accent = Color(0xFFB94B37);
    const ink = Color(0xFF2E2923);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF7F0E4), Color(0xFFF2E8D7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: shell,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFCEBFA6), width: 1.4),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: const BoxDecoration(
                      color: trim,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: _pickerBusy ? null : _startPicker,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          icon: _pickerBusy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.colorize_rounded, size: 18),
                          label: Text(
                            _pickerBusy ? 'Picking...' : 'Pick From Screen',
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'ClrPkr',
                          style: TextStyle(
                            color: Color(0xFFF7F0E4),
                            fontFamily: 'Menlo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      child: Column(
                        children: <Widget>[
                          _SectionCard(
                            color: panel,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Output Format',
                                  style: TextStyle(
                                    fontFamily: 'Menlo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: ColorFormat.values.map((format) {
                                    final selected = _format == format;
                                    return ChoiceChip(
                                      label: Text(format.label),
                                      selected: selected,
                                      onSelected: (_) {
                                        setState(() {
                                          _format = format;
                                        });
                                      },
                                      backgroundColor: const Color(0xFFF4E9D5),
                                      selectedColor: const Color(0xFFDCE7D3),
                                      labelStyle: TextStyle(
                                        fontFamily: 'Menlo',
                                        fontWeight: FontWeight.w700,
                                        color: selected ? trim : ink,
                                      ),
                                      side: BorderSide(
                                        color: selected
                                            ? trim
                                            : const Color(0xFFCDBA9D),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _SectionCard(
                              color: panel,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      const Text(
                                        'Previous Picks',
                                        style: TextStyle(
                                          fontFamily: 'Menlo',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.7,
                                          color: ink,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: _history.isEmpty
                                            ? null
                                            : _clearHistory,
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                        label: const Text('Clear History'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: accent,
                                          textStyle: const TextStyle(
                                            fontFamily: 'Menlo',
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: _history.isEmpty
                                        ? const _EmptyHistory()
                                        : ListView.separated(
                                            itemCount: _history.length,
                                            separatorBuilder: (_, _) =>
                                                const SizedBox(height: 12),
                                            itemBuilder: (context, index) {
                                              final item = _history[index];
                                              return _HistoryTile(
                                                item: item,
                                                value: _formatColor(
                                                  item,
                                                  _format,
                                                ),
                                                copied:
                                                    _lastCopiedId == item.id,
                                                onTap: () => _copyColor(item),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD5C7AE)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.visibility_rounded, size: 34, color: Color(0xFF6A7F5F)),
            SizedBox(height: 14),
            Text(
              'Pick a colour from anywhere on screen.\nEach result lands here ready to copy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Color(0xFF5C554E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.value,
    required this.copied,
    required this.onTap,
  });

  final PickedColor item;
  final String value;
  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = item.previewPng;

    return Material(
      color: const Color(0xFFF7F0E4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4C2A2)),
                  color: item.color,
                ),
                clipBehavior: Clip.antiAlias,
                child: preview == null
                    ? null
                    : Image.memory(
                        preview,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.none,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E2923),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatColor(item, ColorFormat.hex),
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 12,
                        color: Color(0xFF665E55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timestamp(item.pickedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A7269),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: copied
                      ? const Color(0xFFDCE7D3)
                      : const Color(0xFFF0E4CF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: copied
                        ? const Color(0xFF6A7F5F)
                        : const Color(0xFFD4C2A2),
                  ),
                ),
                child: Text(
                  copied ? 'Copied' : 'Copy',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: copied
                        ? const Color(0xFF496042)
                        : const Color(0xFF6A5A44),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _timestamp(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute:$second';
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
