const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

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

// Хранилище
const bots = new Map(); // botId -> bot info
const commands = new Map(); // botId -> array of commands
const botStatuses = new Map(); // botId -> last status
let owner = null;

// ========== WebSocket для ОВНЕРА ==========
io.on('connection', (socket) => {
  console.log('WebSocket подключение:', socket.id);

  socket.on('register_owner', (data) => {
    owner = socket.id;
    console.log('Овнер подключен:', data.displayName);
    
    // Отправляем список всех ботов
    const botsList = Array.from(bots.values()).map(bot => ({
      ...bot,
      status: botStatuses.get(bot.id) || 'idle'
    }));
    
    socket.emit('bots_update', botsList);
    socket.emit('registered', { success: true, role: 'owner' });
  });

  socket.on('command', (data) => {
    if (socket.id !== owner) return;
    
    const { targetBots, command, params } = data;
    console.log(`Команда: ${command}`, params);
    
    if (targetBots === 'all') {
      bots.forEach((bot, botId) => {
        if (!commands.has(botId)) commands.set(botId, []);
        commands.get(botId).push({ command, params, timestamp: Date.now() });
      });
    } else if (Array.isArray(targetBots)) {
      targetBots.forEach(botId => {
        if (!commands.has(botId)) commands.set(botId, []);
        commands.get(botId).push({ command, params, timestamp: Date.now() });
      });
    }
    
    // Подтверждение овнеру
    socket.emit('command_sent', { success: true });
  });

  socket.on('disconnect', () => {
    if (socket.id === owner) {
      console.log('Овнер отключен');
      owner = null;
    }
  });
});

// ========== HTTP API для БОТОВ (Roblox) ==========

// Регистрация бота
app.post('/api/bot/register', (req, res) => {
  const { username, displayName, userId } = req.body;
  const botId = `bot_${userId}`;
  
  const botInfo = {
    id: botId,
    username,
    displayName,
    userId,
    lastSeen: Date.now(),
    connectedAt: bots.has(botId) ? bots.get(botId).connectedAt : Date.now()
  };
  
  bots.set(botId, botInfo);
  
  // Уведомляем овнера
  if (owner) {
    const botsList = Array.from(bots.values()).map(bot => ({
      ...bot,
      status: botStatuses.get(bot.id) || 'idle'
    }));
    io.to(owner).emit('bots_update', botsList);
  }
  
  res.json({ success: true, botId });
});

// Получение команд для бота (polling)
app.get('/api/bot/commands/:botId', (req, res) => {
  const { botId } = req.params;
  
  // Обновляем lastSeen
  if (bots.has(botId)) {
    const bot = bots.get(botId);
    bot.lastSeen = Date.now();
    bots.set(botId, bot);
  }
  
  // Получаем команды
  const botCommands = commands.get(botId) || [];
  commands.set(botId, []); // Очищаем после отправки
  
  res.json({ commands: botCommands });
});

// Обновление статуса бота
app.post('/api/bot/status', (req, res) => {
  const { botId, status, message } = req.body;
  
  botStatuses.set(botId, { status, message, timestamp: Date.now() });
  
  // Отправляем овнеру
  if (owner) {
    io.to(owner).emit('bot_status_update', {
      botId,
      status,
      message
    });
  }
  
  res.json({ success: true });
});

// ========== ЭНДПОИНТЫ ДЛЯ ОВНЕРА ==========

// Получить список всех ботов
app.get('/api/owner/bots', (req, res) => {
  const botsList = Array.from(bots.values()).map(bot => ({
    ...bot,
    status: botStatuses.get(bot.id)?.status || 'idle',
    message: botStatuses.get(bot.id)?.message || ''
  }));
  
  res.json({ bots: botsList });
});

// Отправить команду ботам
app.post('/api/owner/command', (req, res) => {
  const { targetBots, command, params, owner } = req.body;
  
  // Проверка овнера (можно добавить токен)
  console.log(`Команда от ${owner}: ${command}`, params);
  
  if (targetBots === 'all') {
    bots.forEach((bot, botId) => {
      if (!commands.has(botId)) commands.set(botId, []);
      commands.get(botId).push({ command, params, timestamp: Date.now() });
    });
  } else if (Array.isArray(targetBots)) {
    targetBots.forEach(botId => {
      if (!commands.has(botId)) commands.set(botId, []);
      commands.get(botId).push({ command, params, timestamp: Date.now() });
    });
  }
  
  res.json({ success: true });
});

// Health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'online',
    bots: bots.size,
    owner: owner ? 'connected' : 'disconnected'
  });
});

// Очистка неактивных ботов (каждые 30 сек)
setInterval(() => {
  const now = Date.now();
  const timeout = 60000; // 1 минута
  
  bots.forEach((bot, botId) => {
    if (now - bot.lastSeen > timeout) {
      console.log(`Бот таймаут: ${bot.displayName}`);
      bots.delete(botId);
      commands.delete(botId);
      botStatuses.delete(botId);
      
      if (owner) {
        const botsList = Array.from(bots.values()).map(b => ({
          ...b,
          status: botStatuses.get(b.id) || 'idle'
        }));
        io.to(owner).emit('bots_update', botsList);
      }
    }
  });
}, 30000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Сервер запущен на порту ${PORT}`);
});