const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const util = require('util');
require('dotenv').config();

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
    credentials: true
  },
  transports: ['websocket'],
  path: '/socket.io/',
  pingTimeout: 60000,
  pingInterval: 25000,
  connectTimeout: 20000,
  allowEIO3: true
});

app.use(cors({ origin: "*", credentials: true }));
app.use(express.json());

const db = mysql.createConnection({
  host: process.env.DB_HOST || 'server.sparkvtc.com',
  user: process.env.DB_USER || 'aquauser',
  password: process.env.DB_PASS || '98nWVQAYUDuJ-Eal',
  database: process.env.DB_NAME || 'aquafocus'
});

// Promisify db.query
db.query = util.promisify(db.query);

db.connect(err => {
  if (err) {
    console.error('MySQL Connection Error:', err);
    return;
  }
  console.log('MySQL Connected!');
});

const userRoutes = require('./routes/userRoutes')(io);
const teamRoutes = require('./routes/teamRoutes')(io);

// API Routes
app.use('/api', userRoutes);
app.use('/api/teams', teamRoutes);

// Test endpoint
app.get('/api/test', (req, res) => {
  res.json({ message: 'API is working!' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal Server Error' });
});

io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);

  socket.on('globalEvent', (data) => {
    console.log('Global event received:', data);
    io.emit('globalEvent', data);
  });

  socket.on('joinTeam', async (data) => {
    console.log('User joining team:', data);
    socket.join(data.teamId);

    try {
      const members = await db.query(
        'SELECT u.user_id, u.name as username FROM team_members tm JOIN users u ON tm.user_id = u.user_id WHERE tm.room_id = ?',
        [data.teamId]
      );

      io.to(data.teamId).emit('teamUpdate', {
        teamId: data.teamId,
        members: members
      });

      io.to(data.teamId).emit('userJoined', {
        username: data.username,
        teamId: data.teamId
      });
    } catch (err) {
      console.error('Error fetching team members:', err);
    }
  });

  socket.on('timerStarted', (data) => io.emit('timerStarted', data));
  socket.on('timerPaused', (data) => io.emit('timerPaused', data));
  socket.on('timerUpdate', (data) => io.emit('timerUpdate', data));
  socket.on('timerCompleted', (data) => io.emit('timerCompleted', data));
  socket.on('timeAdded', (data) => io.emit('timeAdded', data));
  socket.on('timerReset', (data) => io.emit('timerReset', data));

  socket.on('userStatus', (data) => io.emit('userStatus', data));
  socket.on('message', (data) => io.emit('message', data));

  socket.on('aiExplanation', (data) => {
    console.log('AI Explanation event received:', data, 'socket.id:', socket.id);
    io.to(socket.id).emit('aiExplanation', { message: 'AI cevabı burada!' });
  });

  socket.on('requestAIInsights', (data) => {
    // ... OpenAI veya AI işlemleri ...
    io.to(socket.id).emit('aiInsights', { message: 'AI cevabı burada!' });
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });

  socket.on('error', (error) => {
    console.error('Socket error:', error);
  });
});

const PORT = process.env.PORT || 3306;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log('Socket.IO server is ready');
});
