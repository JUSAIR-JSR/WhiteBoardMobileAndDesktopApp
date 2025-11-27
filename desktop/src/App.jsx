import React, { useRef, useEffect, useState } from "react";
import io from "socket.io-client";

const SERVER = import.meta.env.VITE_SERVER_URL || "http://localhost:3000";
const CANVAS_WIDTH = 8000;
const CANVAS_HEIGHT = 1200;

export default function App() {
  const canvasRef = useRef(null);
  const boardRef = useRef(null);
  const socketRef = useRef(null);
  const drawing = useRef(false);
  const [color, setColor] = useState("#000000");
  const [size, setSize] = useState(3);

  // Convert Flutter color integer → CSS hex (#RRGGBB)
  const convertFlutterColor = (intString) => {
    const intVal = parseInt(intString);
    const hex = intVal.toString(16).padStart(8, "0");
    return "#" + hex.substring(2); // remove alpha
  };

  useEffect(() => {
    socketRef.current = io(SERVER, { transports: ["websocket"] });

    // When someone draws (mobile or another desktop)
    socketRef.current.on("draw", (data) => {
      if (data && data.type === "stroke") {
        drawStrokeOffline(data, canvasRef.current);
      }
    });

    // FIX: Clear event listener (correct version)
    socketRef.current.on("clear", () => {
      const ctx = canvasRef.current.getContext("2d");
      ctx.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    });

    return () => socketRef.current.disconnect();
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    canvas.width = CANVAS_WIDTH;
    canvas.height = CANVAS_HEIGHT;
    const ctx = canvas.getContext("2d");
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
  }, []);

  const getAbsPos = (e) => {
    const rect = canvasRef.current.getBoundingClientRect();
    const scrollLeft = boardRef.current.scrollLeft;
    return {
      x: e.clientX - rect.left + scrollLeft,
      y: e.clientY - rect.top,
    };
  };

  const currentStroke = useRef(null);

  const handlePointerDown = (e) => {
    drawing.current = true;
    const p = getAbsPos(e);
    const ctx = canvasRef.current.getContext("2d");

    ctx.beginPath();
    ctx.moveTo(p.x, p.y);

    currentStroke.current = {
      type: "stroke",
      color,
      width: size,
      points: [{ x: p.x, y: p.y }],
    };
  };

  const handlePointerMove = (e) => {
    if (!drawing.current) return;

    const p = getAbsPos(e);
    const ctx = canvasRef.current.getContext("2d");

    ctx.lineWidth = size;
    ctx.strokeStyle = color;
    ctx.lineTo(p.x, p.y);
    ctx.stroke();

    currentStroke.current.points.push({ x: p.x, y: p.y });
  };

  const handlePointerUp = () => {
    if (!drawing.current) return;
    drawing.current = false;

    // Send stroke to backend
    if (currentStroke.current?.points.length > 0) {
      socketRef.current.emit("draw", currentStroke.current);
    }

    currentStroke.current = null;
  };

  // FIXED: this now handles Flutter color format properly
  const drawStrokeOffline = (stroke, canvas) => {
    const ctx = canvas.getContext("2d");
    ctx.beginPath();
    ctx.lineWidth = stroke.width;

    // Fix Flutter int color → HTML5 color
    ctx.strokeStyle = stroke.color.startsWith("#")
      ? stroke.color
      : convertFlutterColor(stroke.color);

    const pts = stroke.points;
    if (!pts || pts.length === 0) return;

    ctx.moveTo(pts[0].x, pts[0].y);
    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);

    ctx.stroke();
  };

  const clearAll = () => {
    const ctx = canvasRef.current.getContext("2d");
    ctx.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    socketRef.current.emit("clear");
  };

  return (
    <div className="app">
      <div className="toolbar">
        <label>
          Color:{" "}
          <input
            type="color"
            value={color}
            onChange={(e) => setColor(e.target.value)}
          />
        </label>

        <label style={{ marginLeft: 12 }}>
          Size:{" "}
          <input
            type="range"
            min="1"
            max="20"
            value={size}
            onChange={(e) => setSize(+e.target.value)}
          />
        </label>

        <button style={{ marginLeft: 12 }} onClick={clearAll}>
          Clear
        </button>

        <span style={{ marginLeft: 12 }}>Connected to: {SERVER}</span>
      </div>

      <div
        ref={boardRef}
        className="board-wrap"
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        onPointerLeave={handlePointerUp}
      >
        <canvas
          ref={canvasRef}
          className="canvas"
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
        />
      </div>
    </div>
  );
}
