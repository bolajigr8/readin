import 'dotenv/config';
import express, { type Request, type Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import mongoose from 'mongoose';

import { connectDB } from './config/db.js';
import { generalLimiter, authLimiter, adminLimiter, syncLimiter } from './middleware/rateLimit.middleware.js';
import { globalErrorHandler, notFoundHandler } from './middleware/error.middleware.js';

import authRouter from './routes/auth.routes.js';
import filesRouter from './routes/files.routes.js';
import usersRouter from './routes/users.routes.js';
import libraryRouter from './routes/library.routes.js';
import annotationsRouter from './routes/annotations.routes.js';
import bookmarksRouter from './routes/bookmarks.routes.js';
import progressRouter from './routes/progress.routes.js';
import webhooksRouter from './routes/webhooks.routes.js';
import featuresRouter from './routes/features.routes.js';
import syncRouter from './routes/sync.routes.js';
import adminRouter from './routes/admin.routes.js';
import configRouter from './routes/config.routes.js';
import paymentsRouter from './routes/payments.routes.js';
import pagesRouter from './routes/pages.routes.js';
import { notFoundHtml } from './controllers/pages.controller.js';

// ── CORS origin helper ────────────────────────────────────────────────────────

const getCorsOrigin = (): string | string[] => {
  if (process.env['NODE_ENV'] === 'production') {
    const origin = process.env['CLIENT_ORIGIN'];
    if (!origin) {
      console.warn(
        '[cors] CLIENT_ORIGIN is not set in production — all browser origins will be blocked',
      );
      return [];
    }
    return [origin];
  }
  return '*';
};

// ── App ───────────────────────────────────────────────────────────────────────

const app = express();

// SECURITY / CORRECTNESS: the API runs behind Render's reverse proxy (1 hop).
// Without this every request appears to come from the proxy's IP, so the rate
// limiters treated ALL users as one person (e.g. 10 logins per 15 min in total)
// and the admin audit log recorded the wrong IP.
app.set('trust proxy', 1);

// 0. Health check — FIRST, before body parsing and every rate limiter, so uptime
// pings (cron-job.org, Render's health check) can never be answered with 429 or
// slowed down, and never touch the database. GET and HEAD both work.
const health = (_req: Request, res: Response): void => {
  res.set('Cache-Control', 'no-store');
  res.status(200).json({
    status: 'ok',
    db: mongoose.connection.readyState === 1 ? 'connected' : 'connecting',
    uptime: Math.round(process.uptime()),
    timestamp: new Date(),
  });
};
app.get(['/api/v1/health', '/health'], health);
app.head(['/api/v1/health', '/health'], health);

// 1. Body parsing (size limits applied globally).
// `rawBody` keeps the exact bytes of webhook requests: Paystack signs them.
app.use(
  express.json({
    limit: '10mb',
    verify: (req, _res, buf) => {
      if (req.url?.startsWith('/api/v1/webhooks')) (req as Request & { rawBody?: Buffer }).rawBody = buf;
    },
  }),
);
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());

// 2. Security headers
app.use(
  helmet({
    contentSecurityPolicy: false, // mobile apps don't need CSP
    crossOriginEmbedderPolicy: false, // required for Expo / React Native
  }),
);

// 3. CORS
app.use(
  cors({
    origin: getCorsOrigin(),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  }),
);

// 4. Global rate limiter
app.use(generalLimiter);

// 5. Routes ────────────────────────────────────────────────────────────────────
app.use('/api/v1/auth', authLimiter, authRouter);
app.use('/api/v1/files', filesRouter); // uploadLimiter scoped inside route file
app.use('/api/v1/users', usersRouter);
app.use('/api/v1/library', libraryRouter);
app.use('/api/v1/annotations', annotationsRouter);
app.use('/api/v1/bookmarks', bookmarksRouter);
app.use('/api/v1/progress', progressRouter);
app.use('/api/v1/webhooks', webhooksRouter);
app.use('/api/v1/config', configRouter);
app.use('/api/v1/payments', paymentsRouter);
app.use('/api/v1/features', syncLimiter, featuresRouter);
app.use('/api/v1/sync', syncLimiter, syncRouter);
app.use('/api/v1/admin', adminLimiter, adminRouter);

// Browser pages: confirm e-mail, reset password, payment result (HTML, not JSON)
app.use('/', pagesRouter);

// 6. 404 — must come after all valid routes. Browsers get a page, apps get JSON.
app.use((req: Request, res: Response, next) => {
  if (!req.path.startsWith('/api/') && req.accepts(['json', 'html']) === 'html') {
    notFoundHtml(req, res);
    return;
  }
  next();
});
app.use(notFoundHandler);

// 7. Global error handler — must be last and have exactly 4 args
app.use(globalErrorHandler);

// ── Bootstrap ─────────────────────────────────────────────────────────────────

const PORT = process.env['PORT'] ?? '5000';

const start = async (): Promise<void> => {
  // Start answering right away (health checks / wake-ups); the database connects next.
  app.listen(Number(PORT), () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });

  await connectDB();

  // Conversion is ON HOLD by default. Set CONVERSION_ENABLED=true to start it.
  if (process.env['CONVERSION_ENABLED'] === 'true') {
    await import('./jobs/conversion.worker.js');
    console.log('🔄 BullMQ conversion worker started');
  } else {
    console.log('⏸️  Conversion worker disabled (CONVERSION_ENABLED != true)');
  }
};

start().catch((err: unknown) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

export default app;
