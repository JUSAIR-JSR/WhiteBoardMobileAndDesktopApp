// desktop/src/App.jsx
import React, { useRef, useEffect, useState } from "react";
import io from "socket.io-client";

const DEFAULT_SERVER = "https://whiteboardmobileanddesktopapp.onrender.com";
const SERVER = import.meta.env.VITE_SERVER_URL || DEFAULT_SERVER;
const CANVAS_WIDTH = 8000;
const CANVAS_HEIGHT = 1200;

export default function App() {
  const canvasRef = useRef(null);
  const boardRef = useRef(null);
  const socketRef = useRef(null);
  const drawing = useRef(false);
  const [color, setColor] = useState("#000000");
  const [size, setSize] = useState(3);
  const currentStroke = useRef(null);

  // Convert Flutter color integer -> CSS hex (fallback)
  const convertFlutterColor = (intString) => {
    if (!intString) return "#000000";
    if (typeof intString !== "string") intString = String(intString);
    if (intString.startsWith("#")) return intString;
    const intVal = parseInt(intString);
    if (Number.isNaN(intVal)) return "#000000";
    const hex = intVal.toString(16).padStart(8, "0");
    return "#" + hex.substring(2); // drop alpha
  };

  useEffect(() => {
    socketRef.current = io(SERVER, {
      transports: ["websocket"],
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000
    });

    socketRef.current.on("connect", () => {
      console.log("[Socket] connected", socketRef.current.id);
    });

    socketRef.current.on("connect_error", (err) => {
      console.warn("[Socket] connect_error", err.message || err);
    });

    // draw event
    socketRef.current.on("draw", (data) => {
      if (data && data.type === "stroke") {
        drawStrokeOffline(data, canvasRef.current);
      }
    });

    // clear event
    socketRef.current.on("clear", () => {
      const ctx = canvasRef.current.getContext("2d");
      ctx.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    });

    return () => {
      try { socketRef.current.disconnect(); } catch (e) {}
    };
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
    if (currentStroke.current?.points.length > 0) {
      socketRef.current.emit("draw", currentStroke.current);
    }
    currentStroke.current = null;
  };

  const drawStrokeOffline = (stroke, canvas) => {
    const ctx = canvas.getContext("2d");
    ctx.beginPath();
    ctx.lineWidth = stroke.width;
    // use stroke.color (hex) or convert from Flutter int
    ctx.strokeStyle = stroke.color && stroke.color.startsWith("#")
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
    if (socketRef.current && socketRef.current.connected) {
      socketRef.current.emit("clear");
    } else {
      console.warn("[Socket] Not connected, clear not emitted");
    }
  };

  return (
    <div className="app">
      <div className="toolbar">
        <div className="group">
          <div className="title">Whiteboard</div>

          <div className="color-input">
            <input
              type="color"
              value={color}
              onChange={(e) => setColor(e.target.value)}
            />
          </div>

          <div className="size-slider">
            <label style={{ color: "#98a0b3", fontSize: 13 }}>Size</label>
            <input
              type="range"
              min="1"
              max="40"
              value={size}
              onChange={(e) => setSize(+e.target.value)}
            />
          </div>

          <button className="button" onClick={clearAll}>Clear</button>
        </div>

        <div className="status">
          <span>Connected to:</span>
          <strong style={{ color: "#dff8ea", marginLeft: 8 }}>{SERVER}</strong>
        </div>
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
