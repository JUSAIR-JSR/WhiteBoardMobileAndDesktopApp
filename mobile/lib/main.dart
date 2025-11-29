// mobile/lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'drawing_board.dart';
import 'draw_models.dart';

void main() {
  runApp(MyApp());
}

const CANVAS_WIDTH = 8000.0;
const CANVAS_HEIGHT = 1200.0;
const SERVER = "https://whiteboardmobileanddesktopapp.onrender.com";
const SCROLL_STEP = 350.0;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      home: WhiteboardPage(),
    );
  }
}

class WhiteboardPage extends StatefulWidget {
  @override
  _WhiteboardPageState createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {
  late IO.Socket socket;

  List<Stroke> strokes = [];
  Stroke? currentStroke;

  final ScrollController _dummyScrollController = ScrollController(); // not used for real scrolling
  final StreamController<List<Stroke>> _strokesStreamController = StreamController<List<Stroke>>.broadcast();

  ToolMode _currentTool = ToolMode.pen;
  bool _isLocked = false;

  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;

  Offset _lastPanGlobal = Offset.zero;

  // SINGLE GlobalKey for the canvas (must be unique)
  final GlobalKey _canvasKey = GlobalKey();
  RenderBox? _canvasBox; // will be set after frame

  // Virtual canvas offset (we don't rely on a horizontal ScrollView; we use offsetX)
  double canvasOffsetX = 0.0;

  // Color presets for quick access
  final List<Color> _colorPresets = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.brown,
  ];

  // Brush sizes
  final List<double> _brushSizes = [1, 3, 5, 8, 12, 18, 25, 35];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _assignCanvasBox();
    });

    _setupSocket();
  }

  void _assignCanvasBox() {
    try {
      _canvasBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    } catch (_) {
      _canvasBox = null;
    }
  }

  void _setupSocket() {
    socket = IO.io(
      SERVER,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io/')
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      debugPrint('✅ Connected to server: ${socket.id}');
      _showSnackBar('Connected to server', Colors.green);
    });

    socket.onDisconnect((_) {
      _showSnackBar('Disconnected from server', Colors.orange);
    });

    socket.onConnectError((err) {
      debugPrint('🔴 Connect error: $err');
      _showSnackBar('Connection error', Colors.red);
    });

    socket.on("draw", (data) {
      try {
        final newStroke = Stroke.fromJson(data);
        strokes.add(newStroke);
        _strokesStreamController.add(strokes);
      } catch (e) {
        debugPrint("Error parsing incoming stroke: $e  data=$data");
      }
    });

    socket.on("clear", (_) {
      strokes.clear();
      _strokesStreamController.add(strokes);
    });
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, duration: Duration(seconds: 2)));
  }

  String colorToHex(Color c) {
    final hex = c.value.toRadixString(16).padLeft(8, '0');
    return '#' + hex.substring(2);
  }

  // Convert from global touch position -> absolute canvas coordinates (take canvasOffsetX into account)
  Offset getCanvasPosition(Offset globalPos) {
    // keep canvasBox up-to-date if possible
    _canvasBox ??= _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (_canvasBox == null) {
      // fallback: use global coordinates + offset
      return Offset(globalPos.dx + canvasOffsetX, globalPos.dy);
    }

    final local = _canvasBox!.globalToLocal(globalPos);
    final absX = local.dx + canvasOffsetX;
    final absY = local.dy;
    return Offset(absX, absY);
  }

  void _startStroke(Offset pos) {
    final color = _currentTool == ToolMode.eraser ? Colors.white : _selectedColor;
    final width = _currentTool == ToolMode.eraser ? 35.0 : _strokeWidth;

    currentStroke = Stroke(
      color: colorToHex(color),
      width: width,
      points: [StrokePoint(pos.dx, pos.dy)],
    );

    strokes.add(currentStroke!);
    _strokesStreamController.add(strokes);
  }

  void _appendStroke(Offset pos) {
    if (currentStroke == null) return;
    currentStroke!.points.add(StrokePoint(pos.dx, pos.dy));
    _strokesStreamController.add(strokes);
  }

  void _endStroke() {
    if (currentStroke != null && currentStroke!.points.length > 0) {
      // send absolute coordinates to server
      try {
        socket.emit("draw", currentStroke!.toJson());
      } catch (e) {
        debugPrint("Socket emit error: $e");
      }
      currentStroke = null;
    }
  }

  void _clearAll() {
    strokes.clear();
    try {
      socket.emit("clear");
    } catch (_) {}
    _strokesStreamController.add(strokes);
  }

  // BUTTON SCROLL: move virtual canvasOffsetX left/right
  void _scrollLeft() {
    setState(() {
      canvasOffsetX = (canvasOffsetX - SCROLL_STEP).clamp(0.0, CANVAS_WIDTH - MediaQuery.of(context).size.width);
      _strokesStreamController.add(strokes);
    });
  }

  void _scrollRight() {
    setState(() {
      canvasOffsetX = (canvasOffsetX + SCROLL_STEP).clamp(0.0, CANVAS_WIDTH - MediaQuery.of(context).size.width);
      _strokesStreamController.add(strokes);
    });
  }

  // When moving (pan to move), update offset by delta
  void _onMovePanUpdate(DragUpdateDetails details) {
    setState(() {
      // finger moves right => we want to pan left (decrease offset) so subtract delta.dx
      canvasOffsetX = (canvasOffsetX - details.delta.dx).clamp(0.0, CANVAS_WIDTH - MediaQuery.of(context).size.width);
      _strokesStreamController.add(strokes);
    });
  }

  Widget _buildToolButton(IconData icon, String tooltip, ToolMode mode, {Color? color}) {
    final isActive = _currentTool == mode;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 28),
        color: isActive ? (color ?? Colors.blue) : Colors.grey,
        onPressed: () {
          setState(() {
            _currentTool = mode;
            if (mode == ToolMode.lock) {
              _isLocked = !_isLocked;
            }
          });
        },
      ),
    );
  }

  Widget _buildColorPreset(Color color) {
    final isSelected = _selectedColor.value == color.value && _currentTool == ToolMode.pen;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _currentTool = ToolMode.pen;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
        ),
      ),
    );
  }

  Widget _buildBrushSizeIndicator(double s) {
    final isSel = _strokeWidth == s;
    return GestureDetector(
      onTap: () => setState(() => _strokeWidth = s),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSel ? Colors.blue.withOpacity(0.18) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(child: Container(width: s, height: s, decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height > screenSize.width;

    // keep canvas box updated
    if (_canvasBox == null && _canvasKey.currentContext != null) {
      try {
        _canvasBox = _canvasKey.currentContext!.findRenderObject() as RenderBox?;
      } catch (_) {
        _canvasBox = null;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(color: Theme.of(context).colorScheme.background),

          Row(
            children: [
              // Sidebar (keeps your UI)
              Container(
                width: isPortrait ? 80 : 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 0))],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top tools
                      Column(
                        children: [
                          _buildToolButton(Icons.brush, 'Draw', ToolMode.pen),
                          SizedBox(height: 16),
                          _buildToolButton(Icons.pan_tool, 'Move', ToolMode.move),
                          SizedBox(height: 16),
                          _buildToolButton(Icons.auto_fix_off, 'Eraser', ToolMode.eraser),
                          SizedBox(height: 16),
                          _buildToolButton(_isLocked ? Icons.lock : Icons.lock_open, _isLocked ? 'Unlock' : 'Lock', ToolMode.lock, color: _isLocked ? Colors.red : Colors.grey),
                        ],
                      ),

                      // Bottom actions + scroll buttons in front of delete
                      Column(
                        children: [
                          // Scroll left
                          IconButton(icon: Icon(Icons.arrow_back_ios_new), color: Colors.blue, onPressed: _scrollLeft, tooltip: 'Scroll Left'),
                          SizedBox(height: 8),
                          // Scroll right
                          IconButton(icon: Icon(Icons.arrow_forward_ios), color: Colors.blue, onPressed: _scrollRight, tooltip: 'Scroll Right'),
                          SizedBox(height: 16),
                          // Delete / Clear (kept below scroll as requested)
                          IconButton(icon: Icon(Icons.delete, size: 28), color: Colors.red, onPressed: _clearAll, tooltip: 'Clear Canvas'),
                          SizedBox(height: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Canvas area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Theme.of(context).colorScheme.background, Theme.of(context).colorScheme.background.withOpacity(0.9)],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Top controls (desktop layout)
                      if (!isPortrait)
                        Container(
                          height: 80,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                          child: Row(
                            children: [
                              Text('Brush Size:', style: TextStyle(fontWeight: FontWeight.w500)),
                              SizedBox(width: 16),
                              Expanded(child: Wrap(spacing: 8, children: _brushSizes.map(_buildBrushSizeIndicator).toList())),
                              SizedBox(width: 24),
                              Text('Colors:', style: TextStyle(fontWeight: FontWeight.w500)),
                              SizedBox(width: 16),
                              Expanded(child: Wrap(spacing: 8, children: _colorPresets.map(_buildColorPreset).toList())),
                              SizedBox(width: 16),
                              IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: _clearAll, tooltip: 'Clear Canvas'),
                            ],
                          ),
                        ),

                      // Canvas painting area
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            if (_currentTool == ToolMode.move) {
                              _lastPanGlobal = details.globalPosition;
                              return;
                            }
                            if (_isLocked) return;
                            final pos = getCanvasPosition(details.globalPosition);
                            _startStroke(pos);
                          },
                          onPanUpdate: (details) {
                            if (_currentTool == ToolMode.move) {
                              _onMovePanUpdate(details);
                              return;
                            }
                            if (_isLocked) return;
                            final pos = getCanvasPosition(details.globalPosition);
                            _appendStroke(pos);
                          },
                          onPanEnd: (_) {
                            if (_currentTool != ToolMode.move && !_isLocked) _endStroke();
                          },
                          onPanCancel: () {
                            if (_currentTool != ToolMode.move && !_isLocked) _endStroke();
                          },
                          child: StreamBuilder<List<Stroke>>(
                            stream: _strokesStreamController.stream,
                            initialData: strokes,
                            builder: (context, snapshot) {
                              final allStrokes = snapshot.data ?? [];

                              // Create transformed copy for local rendering: subtract canvasOffsetX so strokes appear shifted into viewport
                              final transformed = allStrokes.map((s) {
                                final shiftedPoints = s.points.map((p) => StrokePoint(p.x - canvasOffsetX, p.y)).toList();
                                return Stroke(color: s.color, width: s.width, points: shiftedPoints);
                              }).toList();

                              // If there's an in-progress currentStroke, also show it (it uses absolute coords)
                              if (currentStroke != null) {
                                final shifted = currentStroke!.points.map((p) => StrokePoint(p.x - canvasOffsetX, p.y)).toList();
                                transformed.add(Stroke(color: currentStroke!.color, width: currentStroke!.width, points: shifted));
                              }

                              // Canvas size: full height, very wide horizontally (we show portion via transformed coordinates)
                              return RepaintBoundary(
                                child: CustomPaint(
                                  key: _canvasKey,
                                  size: Size(CANVAS_WIDTH, MediaQuery.of(context).size.height - (isPortrait ? 120 : 80)),
                                  painter: BoardPainter(transformed),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Bottom controls for portrait devices
                      if (isPortrait)
                        Container(
                          height: 120,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: Colors.grey.shade300))),
                          child: Column(
                            children: [
                              Text('Brush Size', style: TextStyle(fontWeight: FontWeight.w500)),
                              SizedBox(height: 8),
                              Expanded(child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _brushSizes.length, itemBuilder: (context, index) {
                                return Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: _buildBrushSizeIndicator(_brushSizes[index]));
                              })),
                              SizedBox(height: 12),
                              Text('Colors', style: TextStyle(fontWeight: FontWeight.w500)),
                              SizedBox(height: 8),
                              Expanded(child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _colorPresets.length, itemBuilder: (context, index) {
                                return Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: _buildColorPreset(_colorPresets[index]));
                              })),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Connection status pill
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: socket.connected ? Colors.green : Colors.red, shape: BoxShape.circle)),
                  SizedBox(width: 8),
                  Text(socket.connected ? 'Connected' : 'Disconnected', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _strokesStreamController.close();
    try {
      socket.dispose();
    } catch (_) {}
    super.dispose();
  }
}
enum ToolMode {
  pen,
  eraser,
  lock,
  move,
}
