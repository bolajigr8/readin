import { Worker, type Job } from 'bullmq';
import fs from 'fs/promises';
import path from 'path';

import { createRedisConnection } from '../config/redis.js';
import type { ConversionJobData } from './queue.js';
import { calibreService } from '../services/calibre.service.js';
import { cloudinaryService } from '../services/cloudinary.service.js';
import { Book } from '../models/book.model.js';
import { Job as JobModel } from '../models/job.model.js';
import { pushNotificationService } from '../services/push-notification.service.js';

const TEMP_DIR = process.env['TEMP_DIR'] ?? '/tmp';
const CONCURRENCY = Number(process.env['MAX_CONVERSION_CONCURRENT'] ?? '2');

// ── Processor ─────────────────────────────────────────────────────────────────

const processConversion = async (job: Job<ConversionJobData>): Promise<void> => {
  const { bookId, userId, originalFilename, originalFormat, originalFileUrl } = job.data;

  const inputPath = path.join(TEMP_DIR, `${bookId}.${originalFormat}`);
  const outputPath = path.join(TEMP_DIR, `${bookId}.epub`);

  try {
    // ── 1. Mark job active ───────────────────────────────────────────────────
    await JobModel.findOneAndUpdate(
      { bookId },
      { status: 'active', startedAt: new Date(), progress: 0 },
    );

    // ── 2. Mark book converting ──────────────────────────────────────────────
    await Book.findByIdAndUpdate(bookId, { status: 'converting' });

    // ── 3. Download original from Cloudinary → write to temp file ────────────
    // (Previously this read a base64 `fileBuffer` that the controller stopped
    // sending, so EVERY conversion threw "first argument must be of type string".)
    const download = await fetch(originalFileUrl);
    if (!download.ok) {
      throw new Error(`Could not download original file (HTTP ${download.status}).`);
    }
    await fs.writeFile(inputPath, Buffer.from(await download.arrayBuffer()));

    // ── 4. Convert via Calibre ────────────────────────────────────────────────
    await calibreService.convertToEpub(inputPath, outputPath);

    // ── 5. Update progress to 50% ─────────────────────────────────────────────
    await JobModel.findOneAndUpdate({ bookId }, { progress: 50 });
    await job.updateProgress(50);

    // ── 6. Read output EPUB ───────────────────────────────────────────────────
    const epubBuffer = await fs.readFile(outputPath);

    // ── 7. Upload EPUB to Cloudinary ──────────────────────────────────────────
    const baseName = path.parse(originalFilename).name.replace(/\s+/g, '_');

    const uploadResult = await cloudinaryService.uploadFile(epubBuffer, {
      folder: 'readin/converted',
      filename: `${baseName}_${bookId}`,
      resourceType: 'raw',
    });

    // ── 8. Fetch book for publicId + title before updating ────────────────────
    const bookDoc = await Book.findById(bookId).select('originalFilePublicId title').lean();

    // ── 9. Update book → ready ────────────────────────────────────────────────
    await Book.findByIdAndUpdate(bookId, {
      convertedFileUrl: uploadResult.url,
      convertedFilePublicId: uploadResult.publicId,
      status: 'ready',
    });

    // ── 10. Delete original file from Cloudinary ──────────────────────────────
    const originalPublicId = bookDoc?.originalFilePublicId;
    if (originalPublicId) {
      await cloudinaryService.deleteFile(originalPublicId).catch((err: unknown) => {
        console.warn('[worker] Could not delete original from Cloudinary:', err);
      });
    }

    // ── 11. Mark job completed ────────────────────────────────────────────────
    await JobModel.findOneAndUpdate(
      { bookId },
      { status: 'completed', progress: 100, completedAt: new Date() },
    );

    // ── 12. Push notification ─────────────────────────────────────────────────
    const bookTitle = bookDoc?.title ?? 'Your book';
    await pushNotificationService.sendConversionComplete(userId, bookTitle, bookId);

    // ── 13. Cleanup temp files ────────────────────────────────────────────────
    await calibreService.cleanupTempFiles(inputPath, outputPath);
  } catch (err) {
    const error = err instanceof Error ? err : new Error(String(err));
    console.error(`[worker] Conversion failed for bookId ${bookId}:`, error.message);

    // Update job → failed (swallow secondary errors so we don't mask the original)
    await JobModel.findOneAndUpdate({ bookId }, { status: 'failed', error: error.message }).catch(
      () => undefined,
    );

    // Update book → failed
    await Book.findByIdAndUpdate(bookId, { status: 'failed' }).catch(() => undefined);

    // Fetch title for notification
    const bookDoc = await Book.findById(bookId)
      .select('title')
      .lean()
      .catch(() => null);
    const bookTitle = bookDoc?.title ?? 'Your book';

    // Push failure notification
    await pushNotificationService.sendConversionFailed(userId, bookTitle);

    // Cleanup whatever temp files exist
    await calibreService.cleanupTempFiles(inputPath, outputPath);

    // Re-throw so BullMQ can handle retry logic
    throw error;
  }
};

// ── Worker ────────────────────────────────────────────────────────────────────

export const conversionWorker = new Worker<ConversionJobData>('conversion', processConversion, {
  connection: createRedisConnection(), // dedicated connection for worker (BullMQ requirement)
  concurrency: CONCURRENCY,
  removeOnComplete: { count: 100 },
  removeOnFail: { count: 50 },
});

conversionWorker.on('completed', (job) => {
  console.log(`[worker] ✅ Job ${job.id} completed`);
});

conversionWorker.on('failed', (job, err) => {
  console.error(`[worker] ❌ Job ${job?.id} failed:`, err.message);
});
