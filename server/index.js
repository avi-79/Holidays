import express from 'express';
import Database from 'better-sqlite3';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const PORT = Number(process.env.PORT || 3001);
const HOST = process.env.HOST || '127.0.0.1';
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET || JWT_SECRET.length < 32) {
  console.error('JWT_SECRET must be at least 32 characters. Set it in the environment.');
  process.exit(1);
}
const COOKIE_SECURE = process.env.COOKIE_SECURE === 'true';
const DB_PATH = process.env.DB_PATH || './data/holidays.sqlite';
fs.mkdirSync(path.dirname(path.resolve(DB_PATH)), { recursive: true });

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
db.pragma('busy_timeout = 5000');
db.exec(
  "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE COLLATE NOCASE, password_hash TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT (datetime('now')));" +
  "CREATE TABLE IF NOT EXISTS bookings (id INTEGER PRIMARY KEY AUTOINCREMENT, reference TEXT NOT NULL UNIQUE, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, stay_id INTEGER NOT NULL, stay_name TEXT NOT NULL, location TEXT NOT NULL, nightly_price INTEGER NOT NULL, check_in TEXT NOT NULL, check_out TEXT NOT NULL, guests INTEGER NOT NULL, guest_name TEXT NOT NULL, phone TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Saved - demo only', created_at TEXT NOT NULL DEFAULT (datetime('now')));" +
  "CREATE INDEX IF NOT EXISTS idx_bookings_user_created ON bookings(user_id, created_at DESC);"
);

// Remove legacy placeholder booking rows created by the earlier demo-only flow.
// This targets only rows explicitly marked as demo-only and leaves other records intact.
db.prepare("DELETE FROM bookings WHERE status = 'Saved - demo only'").run();

const stays = {
  1: { name: 'The Palm House', location: 'Candolim, Goa', price: 7800 },
  2: { name: 'Misty Mountain Retreat', location: 'Munnar, Kerala', price: 6200 },
  3: { name: 'The Blue Door Villa', location: 'Udaipur, Rajasthan', price: 9400 },
  4: { name: 'Coastal Cove', location: 'Varkala, Kerala', price: 5100 },
  5: { name: 'Saffron Sky Resort', location: 'Jaipur, Rajasthan', price: 8900 },
  6: { name: 'Forest & Fern Lodge', location: 'Coorg, Karnataka', price: 5700 }
};

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(helmet());
app.use(express.json({ limit: '20kb' }));
app.use(cookieParser());

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: 'Too many sign-in attempts. Please try again later.' }
});
const cookieOptions = {
  httpOnly: true,
  secure: COOKIE_SECURE,
  sameSite: 'strict',
  path: '/',
  maxAge: 8 * 60 * 60 * 1000
};

function issueSession(res, user) {
  const token = jwt.sign(
    { sub: String(user.id), email: user.email },
    JWT_SECRET,
    { expiresIn: '8h', issuer: 'holidays-app', audience: 'holidays-web' }
  );
  res.cookie('holidays_session', token, cookieOptions);
}
function publicUser(user) {
  return { id: user.id, name: user.name, email: user.email };
}
function requireAuth(req, res, next) {
  try {
    const token = req.cookies.holidays_session;
    if (!token) return res.status(401).json({ error: 'Please sign in to continue.' });
    const payload = jwt.verify(token, JWT_SECRET, {
      issuer: 'holidays-app',
      audience: 'holidays-web'
    });
    const user = db.prepare('SELECT id, name, email FROM users WHERE id = ?').get(Number(payload.sub));
    if (!user) return res.status(401).json({ error: 'Session is no longer valid. Please sign in again.' });
    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: 'Your session has expired. Please sign in again.' });
  }
}
function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(value + 'T00:00:00.000Z');
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

app.get('/api/health', (_req, res) => res.json({ status: 'ok', service: 'holidays-api' }));

app.post('/api/auth/register', authLimiter, async (req, res) => {
  const name = String(req.body?.name || '').trim();
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = req.body?.password;
  if (name.length < 2 || name.length > 80) return res.status(400).json({ error: 'Enter a name between 2 and 80 characters.' });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) return res.status(400).json({ error: 'Enter a valid email address.' });
  if (typeof password !== 'string' || password.length < 10 || password.length > 72) return res.status(400).json({ error: 'Password must be between 10 and 72 characters.' });
  try {
    const hash = await bcrypt.hash(password, 12);
    const result = db.prepare('INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)').run(name, email, hash);
    const user = db.prepare('SELECT id, name, email FROM users WHERE id = ?').get(result.lastInsertRowid);
    issueSession(res, user);
    return res.status(201).json({ user: publicUser(user) });
  } catch (error) {
    if (error.code === 'SQLITE_CONSTRAINT_UNIQUE') return res.status(409).json({ error: 'An account with this email already exists. Please sign in.' });
    console.error('Registration failed:', error.message);
    return res.status(500).json({ error: 'Could not create the account.' });
  }
});

app.post('/api/auth/login', authLimiter, async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = req.body?.password;
  if (!email || typeof password !== 'string') return res.status(400).json({ error: 'Enter your email and password.' });
  const user = db.prepare('SELECT id, name, email, password_hash FROM users WHERE email = ?').get(email);
  const ok = user ? await bcrypt.compare(password, user.password_hash) : false;
  if (!ok) return res.status(401).json({ error: 'Email or password is incorrect.' });
  issueSession(res, user);
  return res.json({ user: publicUser(user) });
});

app.post('/api/auth/logout', (_req, res) => {
  res.clearCookie('holidays_session', {
    httpOnly: true, secure: COOKIE_SECURE, sameSite: 'strict', path: '/'
  });
  res.status(200).json({ success: true });
});

app.get('/api/auth/me', requireAuth, (req, res) => res.json({ user: publicUser(req.user) }));

app.get('/api/bookings', requireAuth, (req, res) => {
  const bookings = db.prepare(
    'SELECT reference, stay_id, stay_name, location, nightly_price, check_in, check_out, guests, guest_name, phone, status, created_at FROM bookings WHERE user_id = ? ORDER BY id DESC'
  ).all(req.user.id);
  res.json({ bookings });
});

app.post('/api/bookings', requireAuth, (req, res) => {
  const stayId = Number(req.body?.stay_id);
  const stay = stays[stayId];
  const checkIn = req.body?.check_in;
  const checkOut = req.body?.check_out;
  const guests = Number(req.body?.guests);
  const guestName = String(req.body?.guest_name || '').trim();
  const phone = String(req.body?.phone || '').trim();
  if (!stay) return res.status(400).json({ error: 'Please select a valid stay.' });
  if (!validDate(checkIn) || !validDate(checkOut) || checkOut <= checkIn || checkIn < new Date().toISOString().slice(0, 10)) return res.status(400).json({ error: 'Choose valid future check-in and check-out dates.' });
  if (!Number.isInteger(guests) || guests < 1 || guests > 8) return res.status(400).json({ error: 'Guest count must be between 1 and 8.' });
  if (guestName.length < 2 || guestName.length > 80) return res.status(400).json({ error: 'Enter a valid guest name.' });
  if (phone.length < 7 || phone.length > 25) return res.status(400).json({ error: 'Enter a valid contact number.' });
  const reference = 'HOL-' + crypto.randomBytes(4).toString('hex').toUpperCase();
  const result = db.prepare(
    'INSERT INTO bookings (reference, user_id, stay_id, stay_name, location, nightly_price, check_in, check_out, guests, guest_name, phone) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(reference, req.user.id, stayId, stay.name, stay.location, stay.price, checkIn, checkOut, guests, guestName, phone);
  const saved = db.prepare(
    'SELECT reference, stay_id, stay_name, location, nightly_price, check_in, check_out, guests, guest_name, phone, status, created_at FROM bookings WHERE id = ? AND user_id = ?'
  ).get(result.lastInsertRowid, req.user.id);
  res.status(201).json({ booking: saved });
});

app.use((error, _req, res, _next) => {
  console.error('API error:', error.message);
  res.status(500).json({ error: 'An unexpected server error occurred.' });
});

app.listen(PORT, HOST, () => console.log('Holidays API listening on http://' + HOST + ':' + PORT));
