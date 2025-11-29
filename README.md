# 📒 whiteBoardProStudent  
### Realtime Multi-Device Whiteboard (Mobile ↔ Laptop Sync)

whiteBoardProStudent allows students and teachers to **write on mobile** and instantly **view the whiteboard on a laptop/desktop** via the website.  
A perfect tool for **project presentations, classroom teaching, online tutoring, diagrams, and brainstorming**.

---

## 🌟 Key Features

### ✍️ Write on Mobile → View on Laptop in Real-Time  
Everything you draw on the mobile app updates instantly on the browser.

### 💻📱 Works on Both Website & Mobile App  
Use the app on any smartphone + open the whiteboard in any browser.

### ⚡ Ultra Fast Sync  
Powered by your own WebSocket server hosted on Render — no lag.

### 🎨 Drawing Tools  
- Pen  
- Eraser  
- Brush Sizes  
- Colors  
- Lock Mode  
- Smooth scrolling over 8000px canvas  

### 🔒 No Login Required  
Just open the app or website and start drawing — zero authentication.

---

## 🌐 Live Website  
Use the whiteboard on your laptop or projector:

👉 https://whiteboardmobileanddesktopapp-1.onrender.com/

---

## 📱 Android APK (Download)  
Install the app directly from GitHub Releases:

👉 **whiteBoardProStudent-v1.0.apk**

---

## 🛠 How It Works

The system uses:

| Component | Description |
|----------|-------------|
| **Mobile App (Flutter)** | Sends your drawing strokes live |
| **Website (React/Node)** | Displays all strokes from the socket stream |
| **Socket Server (Render)** | Handles real-time communication |
| **No Database** | Data is not stored anywhere |
| **No Login** | You join instantly |

Your phone becomes the writing pad  
Your laptop becomes the presentation board

Perfect for classrooms and college project presentations.

---

## 📡 Your Socket Server  
This project uses your Render server for realtime sync:

