const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// CORS настройки
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(bodyParser.json());

// === БАЗА ДАННЫХ (в памяти) ===
// ⚠️ Для продакшена подключите MongoDB!
const usersDB = {};
const messagesDB = {};
const tokensDB = {};

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
function getChatKey(user1, user2) {
    return [user1, user2].sort().join('_');
}

function generateUserId() {
    return 'user_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// === РОУТЫ АУТЕНТИФИКАЦИИ ===

// Регистрация
app.post('/auth/register', async (req, res) => {
    const { username, password, name } = req.body;

    if (!username || !password || !name) {
        return res.status(400).json({ error: 'Заполните все поля' });
    }

    if (username.length < 3) {
        return res.status(400).json({ error: 'Логин должен быть не менее 3 символов' });
    }

    if (password.length < 6) {
        return res.status(400).json({ error: 'Пароль должен быть не менее 6 символов' });
    }

    if (usersDB[username]) {
        return res.status(409).json({ error: 'Пользователь уже существует' });
    }

    try {
        const passwordHash = await bcrypt.hash(password, 10);
        const userId = generateUserId();

        usersDB[username] = {
            id: userId,
            username,
            name,
            passwordHash,
            createdAt: new Date().toISOString()
        };

        const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: '24h' });
        tokensDB[token] = username;

        console.log(`[REGISTER] ${username} (${userId})`);

        res.status(201).json({
            success: true,
            token,
            user: { id: userId, username, name }
        });
    } catch (error) {
        console.error('[REGISTER ERROR]', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// Вход
app.post('/auth/login', async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ error: 'Заполните все поля' });
    }

    const user = usersDB[username];
    if (!user) {
        return res.status(401).json({ error: 'Неверный логин или пароль' });
    }

    try {
        const isValid = await bcrypt.compare(password, user.passwordHash);
        if (!isValid) {
            return res.status(401).json({ error: 'Неверный логин или пароль' });
        }

        const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: '24h' });
        tokensDB[token] = username;

        console.log(`[LOGIN] ${username}`);

        res.json({
            success: true,
            token,
            user: { id: user.id, username: user.username, name: user.name }
        });
    } catch (error) {
        console.error('[LOGIN ERROR]', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});

// Проверка токена
app.get('/auth/verify', (req, res) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token || !tokensDB[token]) {
        return res.status(401).json({ valid: false });
    }
    const username = tokensDB[token];
    const user = usersDB[username];
    res.json({
        valid: true,
        user: { id: user.id, username: user.username, name: user.name }
    });
});

// === РОУТЫ ПОЛЬЗОВАТЕЛЕЙ ===

// Получить всех пользователей
app.get('/users', (req, res) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token || !tokensDB[token]) {
        return res.status(401).json({ error: 'Неавторизован' });
    }

    const userList = Object.values(usersDB).map(u => ({
        id: u.id,
        username: u.username,
        name: u.name
    }));

    res.json({ users: userList });
});

// Поиск пользователей
app.get('/users/search', (req, res) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token || !tokensDB[token]) {
        return res.status(401).json({ error: 'Неавторизован' });
    }

    const query = (req.query.q || '').toLowerCase();
    const currentUsername = tokensDB[token];

    if (!query) {
        return res.json({ users: [] });
    }

    const filteredUsers = Object.values(usersDB)
        .filter(u => u.username !== currentUsername)
        .filter(u =>
            u.username.toLowerCase().includes(query) ||
            u.name.toLowerCase().includes(query)
        )
        .map(u => ({ id: u.id, username: u.username, name: u.name }));

    res.json({ users: filteredUsers });
});

// === РОУТЫ СООБЩЕНИЙ ===

// Отправка сообщения
app.post('/send', (req, res) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token || !tokensDB[token]) {
        return res.status(401).json({ error: 'Неавторизован' });
    }

    const username = tokensDB[token];
    const { to, text } = req.body;

    if (!to || !text) {
        return res.status(400).json({ error: 'Заполните все поля' });
    }

    if (!usersDB[to]) {
        return res.status(404).json({ error: 'Пользователь не найден' });
    }

    const message = {
        id: Date.now().toString(),
        from: username,
        to,
        text,
        timestamp: new Date().toISOString()
    };

    const chatKey = getChatKey(username, to);
    if (!messagesDB[chatKey]) {
        messagesDB[chatKey] = [];
    }
    messagesDB[chatKey].push(message);

    console.log(`[MESSAGE] ${username} → ${to}: ${text}`);

    res.status(201).json({ success: true, message });
});

// История переписки
app.get('/history/:user1/:user2', (req, res) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token || !tokensDB[token]) {
        return res.status(401).json({ error: 'Неавторизован' });
    }

    const { user1, user2 } = req.params;
    const chatKey = getChatKey(user1, user2);
    const history = messagesDB[chatKey] || [];

    res.json({
        success: true,
        count: history.length,
        messages: history.sort((a, b) => 
            new Date(a.timestamp) - new Date(b.timestamp)
        )
    });
});

// Запуск сервера
app.listen(PORT, () => {
    console.log(`🚀 Сервер запущен на порту ${PORT}`);
    console.log(`🌐 URL: http://localhost:${PORT}`);
    console.log(`🔑 JWT_SECRET: ${JWT_SECRET.substring(0, 10)}...`);
});