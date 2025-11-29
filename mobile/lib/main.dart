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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
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

  final ScrollController _scrollController = ScrollController();
  final _strokesStreamController = StreamController<List<Stroke>>.broadcast();

  ToolMode _currentTool = ToolMode.pen;
  bool _isLocked = false;

  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;

  Offset _lastPan = Offset.zero;
  late RenderBox _canvasBox;

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
      _canvasBox = context.findRenderObject() as RenderBox;
    });

    _setupSocket();
    _setupScrollListener();
  }

  void _setupSocket() {
    socket = IO.io(
      SERVER,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io/')
          .enableAutoConnect()
          .enableReconnection()
          .setTimeout(30000)
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('✅ Connected to server');
      _showSnackBar('Connected to server', Colors.green);
    });

    socket.onDisconnect((_) {
      _showSnackBar('Disconnected from server', Colors.orange);
    });

    socket.onConnectError((data) {
      print('❌ Connection error: $data');
      _showSnackBar('Connection error', Colors.red);
    });

    socket.on("draw", (data) {
      try {
        final newStroke = Stroke.fromJson(data);
        strokes.add(newStroke);
        _strokesStreamController.add(strokes);
      } catch (e) {
        print('Error parsing stroke: $e');
      }
    });

    socket.on("clear", (_) {
      strokes.clear();
      _strokesStreamController.add(strokes);
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Update UI if needed for scroll position indicators
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String colorToHex(Color c) {
    final hex = c.value.toRadixString(16).padLeft(8, '0');
    return "#" + hex.substring(2);
  }

  Offset getCanvasPosition(Offset globalPos) {
    final local = _canvasBox.globalToLocal(globalPos);
    final absX = local.dx + _scrollController.offset;
    return Offset(absX, local.dy);
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
    if (currentStroke != null && currentStroke!.points.length > 1) {
      socket.emit("draw", currentStroke!.toJson());
      currentStroke = null;
    } else if (currentStroke != null) {
      // Remove single-point strokes (accidental taps)
      strokes.remove(currentStroke);
      currentStroke = null;
      _strokesStreamController.add(strokes);
    }
  }

  void _clearAll() {
    strokes.clear();
    socket.emit("clear");
    _strokesStreamController.add(strokes);
    _showSnackBar('Canvas cleared', Colors.blue);
  }

  void _scrollRight() {
    final next = (_scrollController.offset + SCROLL_STEP).clamp(
      0.0,
      CANVAS_WIDTH - MediaQuery.of(context).size.width,
    );

    _scrollController.animateTo(
      next,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollLeft() {
    final next = (_scrollController.offset - SCROLL_STEP).clamp(
      0.0,
      CANVAS_WIDTH - MediaQuery.of(context).size.width,
    );

    _scrollController.animateTo(
      next,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 2,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrushSizeIndicator(double size) {
    final isSelected = _strokeWidth == size;
    return GestureDetector(
      onTap: () {
        setState(() {
          _strokeWidth = size;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _selectedColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  final isPortrait = screenSize.height > screenSize.width;

  return WillPopScope(
    onWillPop: () async {
      if (strokes.isNotEmpty) {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Unsaved Changes'),
            content: Text('You have unsaved drawings. Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Exit'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      }
      return true;
    },
    child: Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            color: Theme.of(context).colorScheme.background,
          ),

          Row(
            children: [
              // Enhanced Sidebar
              Container(
                width: isPortrait ? 80 : 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(2, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Tools Section
                      Column(
                        children: [
                          _buildToolButton(Icons.brush, 'Draw', ToolMode.pen),
                          SizedBox(height: 16),
                          _buildToolButton(Icons.pan_tool, 'Move', ToolMode.move),
                          SizedBox(height: 16),
                          _buildToolButton(Icons.auto_fix_off, 'Eraser', ToolMode.eraser),
                          SizedBox(height: 16),
                          _buildToolButton(
                            _isLocked ? Icons.lock : Icons.lock_open,
                            _isLocked ? 'Unlock' : 'Lock',
                            ToolMode.lock,
                            color: _isLocked ? Colors.red : Colors.grey,
                          ),
                        ],
                      ),

                      // Bottom Actions
                      Column(
                        children: [
                          // TODO: Implement undo functionality
                          // _buildToolButton(Icons.undo, 'Undo', ToolMode.pen),
                          // SizedBox(height: 16),
                          IconButton(
                            icon: Icon(Icons.delete, size: 28),
                            color: Colors.red,
                            onPressed: _clearAll,
                            tooltip: 'Clear Canvas',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Canvas Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.background,
                        Theme.of(context).colorScheme.background.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Top Bar with Color and Size Controls
                      if (!isPortrait) _buildTopControls(),

                      // Canvas
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: _currentTool == ToolMode.move
                              ? AlwaysScrollableScrollPhysics()
                              : NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: CANVAS_WIDTH,
                            height: screenSize.height - (isPortrait ? 120 : 80),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,

                              onPanStart: (details) {
                                if (_currentTool == ToolMode.move) {
                                  _lastPan = details.globalPosition;
                                  return;
                                }
                                if (_isLocked) return;

                                final pos = getCanvasPosition(details.globalPosition);
                                _startStroke(pos);
                              },

                              onPanUpdate: (details) {
                                if (_currentTool == ToolMode.move) {
                                  final dx = _lastPan.dx - details.globalPosition.dx;
                                  _scrollController.jumpTo(
                                    (_scrollController.offset + dx).clamp(
                                      0.0,
                                      CANVAS_WIDTH - screenSize.width,
                                    ),
                                  );
                                  _lastPan = details.globalPosition;
                                  return;
                                }
                                if (_isLocked) return;

                                final pos = getCanvasPosition(details.globalPosition);
                                _appendStroke(pos);
                              },

                              onPanEnd: (_) {
                                if (_currentTool != ToolMode.move && !_isLocked) {
                                  _endStroke();
                                }
                              },

                              onPanCancel: () {
                                if (_currentTool != ToolMode.move && !_isLocked) {
                                  _endStroke();
                                }
                              },

                              child: StreamBuilder<List<Stroke>>(
                                stream: _strokesStreamController.stream,
                                initialData: strokes,
                                builder: (context, snapshot) {
                                  return CustomPaint(
                                    size: Size(CANVAS_WIDTH, screenSize.height - (isPortrait ? 120 : 80)),
                                    painter: BoardPainter(snapshot.data ?? []),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom Controls for Portrait
                      if (isPortrait) _buildBottomControls(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Scroll Buttons
          Positioned(
            left: 90,
            bottom: 20,
            child: Row(
              children: [
                FloatingActionButton.small(
                  heroTag: 'scroll_left',
                  backgroundColor: Colors.blue,
                  onPressed: _scrollLeft,
                  child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                ),
                SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'scroll_right',
                  backgroundColor: Colors.blue,
                  onPressed: _scrollRight,
                  child: Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),

          // Connection Status
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: socket.connected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    socket.connected ? 'Connected' : 'Disconnected',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

 Widget _buildTopControls() {
  return Container(
    height: 80,
    padding: EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
    ),
    child: Row(
      children: [
        Text('Brush Size:', style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: _brushSizes.map(_buildBrushSizeIndicator).toList(),
          ),
        ),
        SizedBox(width: 24),
        Text('Colors:', style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: _colorPresets.map(_buildColorPreset).toList(),
          ),
        ),
        SizedBox(width: 16),
        // Add clear button to top controls
        IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: _clearAll,
          tooltip: 'Clear Canvas',
        ),
      ],
    ),
  );
}

  Widget _buildBottomControls() {
    return Container(
      height: 120,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Text('Brush Size', style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _brushSizes.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: _buildBrushSizeIndicator(_brushSizes[index]),
                );
              },
            ),
          ),
          SizedBox(height: 12),
          Text('Colors', style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colorPresets.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: _buildColorPreset(_colorPresets[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _strokesStreamController.close();
    socket.disconnect();
    super.dispose();
  }
}

enum ToolMode {
  pen,
  move,
  eraser,
  lock,
}