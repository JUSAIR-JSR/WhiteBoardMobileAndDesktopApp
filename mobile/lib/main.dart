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
// const SERVER = "http://localhost:3000"; // change to your machine IP when testing on device
const SERVER = "http://xxx.x.x.x:3000";  // your IP

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

  void connectSocket() {
    socket = IO.io(SERVER, IO.OptionBuilder().setTransports(['websocket']).build());
    socket.onConnect((_) => print("connected ${socket.id}"));
    socket.on("draw", (data) {
      if (data == null) return;
      if (data is Map && data['type'] == 'stroke') {
        final st = Stroke.fromJson(Map<String, dynamic>.from(data));
        setState(() => strokes.add(st));
      } else if (data == 'clear') {
        setState(() => strokes.clear());
      }
    });
  }

  void startStroke(Offset localPosition) {
    // convert to absolute canvas coordinates: localX + scrollOffset
    final absX = localPosition.dx + scrollController.offset;
    final absY = localPosition.dy;
    currentStroke = Stroke(
      color: selectedColor.value.toString(),
      width: strokeWidth,
      points: [StrokePoint(absX, absY)],
    );
    setState(() { strokes.add(currentStroke!); });
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

  @override
  Widget build(BuildContext context) {
    // Force landscape-like layout by rotating if needed is optional
    return Scaffold(
      appBar: AppBar(title: Text("Whiteboard (Landscape)")),
      body: Column(children: [
        Row(children: [
          IconButton(icon: Icon(Icons.clear), onPressed: clearAll),
          IconButton(icon: Icon(Icons.color_lens), onPressed: (){
            // simple color cycle
            setState(()=> selectedColor = selectedColor == Colors.black ? Colors.blue : Colors.black);
          }),
          Text("Width: ${strokeWidth.toInt()}"),
          Slider(value: strokeWidth, min:1, max:20, onChanged:(v){ setState(()=> strokeWidth = v); })
        ]),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal, // horizontal only
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
    );
  }

  @override
  void dispose() {
    socket.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
