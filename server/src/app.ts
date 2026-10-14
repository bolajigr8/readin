import 'dotenv/config';
import express, { type Request, type Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';

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

// 1. Body parsing (size limits applied globally)
app.use(express.json({ limit: '10mb' }));
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
app.use('/api/v1/features', syncLimiter, featuresRouter);
app.use('/api/v1/sync', syncLimiter, syncRouter);
app.use('/api/v1/admin', adminLimiter, adminRouter);

app.get('/api/v1/health', (_req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', timestamp: new Date() });
});

// 6. 404 — must come after all valid routes
app.use(notFoundHandler);

// 7. Global error handler — must be last and have exactly 4 args
app.use(globalErrorHandler);

// ── Bootstrap ─────────────────────────────────────────────────────────────────

const PORT = process.env['PORT'] ?? '5000';

const start = async (): Promise<void> => {
  await connectDB();

  // Conversion is ON HOLD by default. Set CONVERSION_ENABLED=true to start it.
  if (process.env['CONVERSION_ENABLED'] === 'true') {
    await import('./jobs/conversion.worker.js');
    console.log('🔄 BullMQ conversion worker started');
  } else {
    console.log('⏸️  Conversion worker disabled (CONVERSION_ENABLED != true)');
  }

  app.listen(Number(PORT), () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });
};

start().catch((err: unknown) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

export default app;
