// desktop/src/App.jsx
import React, { useRef, useEffect, useState, useCallback } from "react";
import io from "socket.io-client";
const DEFAULT_SERVER = "https://whiteboardmobileanddesktopapp.onrender.com";
const SERVER = import.meta.env.VITE_SERVER_URL || DEFAULT_SERVER;
const CANVAS_WIDTH = 8000;
const CANVAS_HEIGHT = 1200;

// Tool types
const TOOLS = {
  PEN: 'pen',
  ERASER: 'eraser',
  LINE: 'line',
  RECTANGLE: 'rectangle',
  CIRCLE: 'circle'
};

export default function App() {
  const canvasRef = useRef(null);
  const boardRef = useRef(null);
  const socketRef = useRef(null);
  const drawing = useRef(false);
  const currentStroke = useRef(null);
  const [connectionStatus, setConnectionStatus] = useState('connecting');
  
  // Enhanced state management
  const [toolSettings, setToolSettings] = useState({
    color: "#000000",
    size: 3,
    tool: TOOLS.PEN
  });

  const [cursorPosition, setCursorPosition] = useState({ x: 0, y: 0 });

  // Convert Flutter color integer -> CSS hex
  const convertFlutterColor = useCallback((intString) => {
    if (!intString) return "#000000";
    if (typeof intString !== "string") intString = String(intString);
    if (intString.startsWith("#")) return intString;
    const intVal = parseInt(intString);
    if (Number.isNaN(intVal)) return "#000000";
    const hex = intVal.toString(16).padStart(8, "0");
    return "#" + hex.substring(2);
  }, []);

  // Socket connection management
  useEffect(() => {
    socketRef.current = io(SERVER, {
      transports: ["websocket"],
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000
    });

    socketRef.current.on("connect", () => {
      console.log("[Socket] connected", socketRef.current.id);
      setConnectionStatus('connected');
    });

    socketRef.current.on("disconnect", () => {
      setConnectionStatus('disconnected');
    });

    socketRef.current.on("connect_error", (err) => {
      console.warn("[Socket] connect_error", err.message || err);
      setConnectionStatus('error');
    });

    socketRef.current.on("reconnect_attempt", () => {
      setConnectionStatus('reconnecting');
    });

    // Draw event
    socketRef.current.on("draw", (data) => {
      if (data && data.type === "stroke") {
        drawStrokeOffline(data, canvasRef.current);
      }
    });

    // Clear event
    socketRef.current.on("clear", () => {
      const ctx = canvasRef.current.getContext("2d");
      ctx.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    });

    return () => {
      try { 
        socketRef.current.disconnect(); 
      } catch (e) {
        console.warn("Disconnect error:", e);
      }
    };
  }, []);

  // Canvas initialization
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    canvas.width = CANVAS_WIDTH;
    canvas.height = CANVAS_HEIGHT;
    const ctx = canvas.getContext("2d");
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    
    // Set initial white background
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
  }, []);

  // Get absolute position considering scroll
  const getAbsPos = useCallback((e) => {
    const canvas = canvasRef.current;
    const board = boardRef.current;
    if (!canvas || !board) return { x: 0, y: 0 };

    const rect = canvas.getBoundingClientRect();
    const scrollLeft = board.scrollLeft;
    const scrollTop = board.scrollTop;
    
    return {
      x: e.clientX - rect.left + scrollLeft,
      y: e.clientY - rect.top + scrollTop,
    };
  }, []);

  // Drawing handlers
  const handlePointerDown = useCallback((e) => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    drawing.current = true;
    const p = getAbsPos(e);
    const ctx = canvas.getContext("2d");

    ctx.beginPath();
    ctx.moveTo(p.x, p.y);

    currentStroke.current = {
      type: "stroke",
      color: toolSettings.tool === TOOLS.ERASER ? "#ffffff" : toolSettings.color,
      width: toolSettings.tool === TOOLS.ERASER ? toolSettings.size * 2 : toolSettings.size,
      points: [{ x: p.x, y: p.y }],
      tool: toolSettings.tool
    };

    setCursorPosition(p);
  }, [getAbsPos, toolSettings]);

  const handlePointerMove = useCallback((e) => {
    const p = getAbsPos(e);
    setCursorPosition(p);

    if (!drawing.current) return;

    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    ctx.lineWidth = toolSettings.tool === TOOLS.ERASER ? toolSettings.size * 2 : toolSettings.size;
    ctx.strokeStyle = toolSettings.tool === TOOLS.ERASER ? "#ffffff" : toolSettings.color;
    ctx.lineTo(p.x, p.y);
    ctx.stroke();

    if (currentStroke.current) {
      currentStroke.current.points.push({ x: p.x, y: p.y });
    }
  }, [getAbsPos, toolSettings]);

  const handlePointerUp = useCallback(() => {
    if (!drawing.current) return;
    drawing.current = false;

    if (currentStroke.current?.points.length > 0 && socketRef.current?.connected) {
      socketRef.current.emit("draw", currentStroke.current);
    }

    currentStroke.current = null;
  }, []);

  // Draw received strokes
  const drawStrokeOffline = useCallback((stroke, canvas) => {
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.beginPath();
    ctx.lineWidth = stroke.width;
    ctx.strokeStyle = stroke.color && stroke.color.startsWith("#")
      ? stroke.color
      : convertFlutterColor(stroke.color);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    const pts = stroke.points;
    if (!pts || pts.length === 0) return;

    ctx.moveTo(pts[0].x, pts[0].y);
    for (let i = 1; i < pts.length; i++) {
      ctx.lineTo(pts[i].x, pts[i].y);
    }
    ctx.stroke();
  }, [convertFlutterColor]);

  // Clear canvas
  const clearAll = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

    if (socketRef.current?.connected) {
      socketRef.current.emit("clear");
    } else {
      console.warn("[Socket] Not connected, clear not emitted");
    }
  }, []);

  // Tool selection
  const selectTool = useCallback((tool) => {
    setToolSettings(prev => ({ ...prev, tool }));
  }, []);

  // Color presets
  const colorPresets = [
    '#000000', '#ef4444', '#3b82f6', '#10b981', 
    '#f59e0b', '#8b5cf6', '#ec4899', '#64748b'
  ];

  return (
    <div className="app">
      {/* Enhanced Toolbar */}
      <div className="toolbar">
        <div className="toolbar-left">
          <div className="app-title">
            <div className="app-icon">🎨</div>
            <span>Whiteboard</span>
          </div>

          <div className="tools-section">
            {/* Tool Selection */}
            <div className="tool-buttons">
              <button 
                className={`tool-btn ${toolSettings.tool === TOOLS.PEN ? 'active' : ''}`}
                onClick={() => selectTool(TOOLS.PEN)}
                title="Pen"
              >
                ✏️
              </button>
              <button 
                className={`tool-btn ${toolSettings.tool === TOOLS.ERASER ? 'active' : ''}`}
                onClick={() => selectTool(TOOLS.ERASER)}
                title="Eraser"
              >
                🧹
              </button>
            </div>

            {/* Color Selection */}
            {toolSettings.tool !== TOOLS.ERASER && (
              <div className="color-section">
                <div className="color-presets">
                  {colorPresets.map(presetColor => (
                    <button
                      key={presetColor}
                      className={`color-preset ${toolSettings.color === presetColor ? 'active' : ''}`}
                      style={{ backgroundColor: presetColor }}
                      onClick={() => setToolSettings(prev => ({ ...prev, color: presetColor }))}
                    />
                  ))}
                </div>
                <div className="color-picker-wrapper">
                  <input
                    type="color"
                    value={toolSettings.color}
                    onChange={(e) => setToolSettings(prev => ({ ...prev, color: e.target.value }))}
                    className="color-picker"
                  />
                </div>
              </div>
            )}

            {/* Brush Size */}
            <div className="size-control">
              <label>Size: {toolSettings.size}px</label>
              <input
                type="range"
                min="1"
                max="40"
                value={toolSettings.size}
                onChange={(e) => setToolSettings(prev => ({ ...prev, size: +e.target.value }))}
                className="size-slider"
              />
            </div>
          </div>
        </div>

        <div className="toolbar-right">
          {/* Connection Status */}
          <div className={`connection-status ${connectionStatus}`}>
            <div className="status-dot"></div>
            <span>
              {connectionStatus === 'connected' && 'Connected'}
              {connectionStatus === 'connecting' && 'Connecting...'}
              {connectionStatus === 'reconnecting' && 'Reconnecting...'}
              {connectionStatus === 'disconnected' && 'Disconnected'}
              {connectionStatus === 'error' && 'Connection Error'}
            </span>
          </div>

          {/* Clear Button */}
          <button className="clear-btn" onClick={clearAll}>
            🗑️ Clear Canvas
          </button>

          {/* Cursor Position */}
          <div className="cursor-position">
            {Math.round(cursorPosition.x)} x {Math.round(cursorPosition.y)}
          </div>
        </div>
      </div>

      {/* Canvas Area */}
      <div className="board-container">
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
    </div>
  );
}