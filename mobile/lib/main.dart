// mobile/lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'drawing_board.dart';
import 'draw_models.dart';

void main() {
  runApp(MyApp());
}

const CANVAS_WIDTH = 8000.0;
const CANVAS_HEIGHT = 1200.0;
// Use your Render backend (secure)
const SERVER = "https://whiteboardmobileanddesktopapp.onrender.com";
const double SCROLL_STEP = 350.0; // fixed scroll distance per button press

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: WhiteboardPage());
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
  final ScrollController scrollController = ScrollController();

  Color selectedColor = Colors.black;
  double strokeWidth = 3.0;

  @override
  void initState() {
    super.initState();
    connectSocket();
  }

  // convert Flutter Color -> "#RRGGBB"
  String colorToHex(Color c) {
    final hex = c.value.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}';
  }

  void connectSocket() {
  socket = IO.io(
    SERVER,
    IO.OptionBuilder()
      .setTransports(['websocket'])
      .setPath('/socket.io/')
      .enableReconnection()
      .enableAutoConnect()
      .setReconnectionAttempts(999999)
      .setReconnectionDelay(1000)
      .build(),
  );

  socket.connect(); // VERY IMPORTANT

  socket.onConnect((_) {
    debugPrint("🟢 CONNECTED TO SERVER: ${socket.id}");
  });

  socket.onConnectError((err) {
    debugPrint("🔴 CONNECT ERROR: $err");
  });

  socket.onError((err) {
    debugPrint("❌ SOCKET ERROR: $err");
  });

  socket.onDisconnect((_) {
    debugPrint("⚪ DISCONNECTED");
  });

  // -------------------------------
  // FIXED "DRAW" LISTENER
  // -------------------------------
  socket.on("draw", (data) {
    try {
      final map = Map<String, dynamic>.from(data);
      final st = Stroke.fromJson(map);
      setState(() => strokes.add(st));
      debugPrint("📩 DRAW RECEIVED");
    } catch (e) {
      debugPrint("❌ DRAW PARSE ERROR: $e | data=$data");
    }
  });

  // -------------------------------
  // FIXED "CLEAR" LISTENER
  // -------------------------------
  socket.on("clear", (_) {
    debugPrint("🧹 CLEAR RECEIVED");
    setState(() => strokes.clear());
  });
}


  void startStroke(Offset localPosition) {
    final absX = localPosition.dx + scrollController.offset;
    final absY = localPosition.dy;
    final hex = colorToHex(selectedColor);
    currentStroke = Stroke(
      color: hex,
      width: strokeWidth,
      points: [StrokePoint(absX, absY)],
    );
    setState(() {
      strokes.add(currentStroke!);
    });
  }

  void appendStroke(Offset localPosition) {
    if (currentStroke == null) return;
    final absX = localPosition.dx + scrollController.offset;
    final absY = localPosition.dy;
    setState(() {
      currentStroke!.points.add(StrokePoint(absX, absY));
    });
  }

  void endStroke() {
    if (currentStroke != null) {
      socket.emit("draw", currentStroke!.toJson());
      currentStroke = null;
    }
  }

  void clearAll() {
    setState(() => strokes.clear());
    socket.emit("clear");
  }

  void scrollLeft() {
    final pos = (scrollController.offset - SCROLL_STEP).clamp(0.0, CANVAS_WIDTH - MediaQuery.of(context).size.width);
    scrollController.animateTo(pos, duration: Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void scrollRight() {
    final maxScroll = CANVAS_WIDTH - MediaQuery.of(context).size.width;
    final pos = (scrollController.offset + SCROLL_STEP).clamp(0.0, maxScroll);
    scrollController.animateTo(pos, duration: Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Whiteboard (Landscape)"),
        actions: [
          IconButton(icon: Icon(Icons.clear), onPressed: clearAll),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          // tool row
          Container(
            color: Colors.black12,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              // color
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedColor = selectedColor == Colors.black ? Colors.blue : Colors.black;
                  });
                },
                child: Row(children: [Icon(Icons.color_lens), SizedBox(width: 8), Text(colorToHex(selectedColor))]),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
              ),
              SizedBox(width: 12),
              Text("Width: ${strokeWidth.toInt()}"),
              Expanded(child: Slider(value: strokeWidth, min: 1, max: 30, onChanged: (v) => setState(() => strokeWidth = v))),
              SizedBox(width: 12),
              Text("Server:", style: TextStyle(fontSize: 12)),
              SizedBox(width: 6),
              Flexible(child: Text(SERVER, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12))),
            ]),
          ),

          // canvas area
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: ClampingScrollPhysics(),
              child: SizedBox(
                width: CANVAS_WIDTH,
                height: CANVAS_HEIGHT,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    final local = details.localPosition;
                    startStroke(local);
                  },
                  onPanUpdate: (details) {
                    final local = details.localPosition;
                    appendStroke(local);
                  },
                  onPanEnd: (_) => endStroke(),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size(CANVAS_WIDTH, CANVAS_HEIGHT),
                      painter: BoardPainter(strokes),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),

        // Floating scroll buttons (right side)
        Positioned(
          right: 14,
          top: 140,
          child: Column(children: [
            FloatingActionButton.small(
              heroTag: "leftBtn",
              onPressed: scrollLeft,
              child: Icon(Icons.chevron_left),
            ),
            SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: "rightBtn",
              onPressed: scrollRight,
              child: Icon(Icons.chevron_right),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    try { socket.dispose(); } catch (e) {}
    scrollController.dispose();
    super.dispose();
  }
}
