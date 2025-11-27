import express from "express";
import http from "http";
import { Server } from "socket.io";
import cors from "cors";

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
    cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

io.on("connection", (socket) => {
  console.log("Client connected:", socket.id);

  // broadcast drawing to others
  socket.on("draw", (data) => {
    // data: { type:'stroke', points:[{x,y}], color, width }
    socket.broadcast.emit("draw", data);
  });

  // optional: clear
  socket.on("clear", () => {
    io.emit("clear");
  });

  socket.on("disconnect", () => {
    console.log("Client disconnected:", socket.id);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Socket server running on ${PORT}`));
