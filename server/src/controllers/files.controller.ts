import type { Request, Response } from 'express';
import asyncHandler from 'express-async-handler';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';

import { cloudinaryService } from '../services/cloudinary.service.js';
import { Book } from '../models/book.model.js';
import { Job } from '../models/job.model.js';
import { successResponse, errorResponse } from '../utils/response.utils.js';
import type { OriginalFormat } from '../models/book.model.js';

// ── Feature flag ──────────────────────────────────────────────────────────────
// Conversion (PDF/DOCX/MOBI/TXT → EPUB via Calibre) is ON HOLD.
// While CONVERSION_ENABLED !== 'true' the server simply stores PDF and EPUB
// files as-is and marks them "ready". The mobile app reads both natively.
// Flip the env var to 'true' later to bring the queue back.
export const CONVERSION_ENABLED = process.env['CONVERSION_ENABLED'] === 'true';

const FREE_PLAN_LIBRARY_LIMIT = 10;

// ── Format detection ──────────────────────────────────────────────────────────
// Phones very often send "application/octet-stream" (or nothing) for .epub
// files, so we CANNOT trust the mimetype alone. Resolve in this order:
// 1. known mimetype  2. file extension  3. magic bytes sanity check.

const MIME_TO_FORMAT: Record<string, OriginalFormat> = {
  'application/pdf': 'pdf',
  'application/epub+zip': 'epub',
  'application/x-mobipocket-ebook': 'mobi',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
  'text/plain': 'txt',
};

const EXT_TO_FORMAT: Record<string, OriginalFormat> = {
  '.pdf': 'pdf', '.epub': 'epub', '.mobi': 'mobi', '.azw3': 'azw3', '.fb2': 'fb2',
  '.cbz': 'cbz', '.cbr': 'cbr', '.docx': 'docx', '.doc': 'doc', '.odt': 'odt',
  '.rtf': 'rtf', '.xlsx': 'xlsx', '.xls': 'xls', '.csv': 'csv', '.pptx': 'pptx',
  '.ppt': 'ppt', '.txt': 'txt', '.md': 'md', '.html': 'html', '.htm': 'htm',
};

const resolveFormat = (mimetype: string, originalname: string): OriginalFormat | null => {
  const ext = path.extname(originalname).toLowerCase();
  // The extension wins: phones send generic MIME types for most files.
  return EXT_TO_FORMAT[ext] ?? MIME_TO_FORMAT[mimetype] ?? null;
};

const ZIP_FORMATS = new Set<OriginalFormat>(['epub', 'docx', 'xlsx', 'pptx', 'odt', 'cbz']);

/** Cheap content sniffing so a renamed/corrupt file is rejected up-front. */
const looksLikeFormat = (buf: Buffer, format: OriginalFormat): boolean => {
  if (format === 'pdf') return buf.subarray(0, 5).toString('latin1') === '%PDF-';
  if (ZIP_FORMATS.has(format)) return buf.length > 4 && buf[0] === 0x50 && buf[1] === 0x4b; // "PK" zip
  return true;
};

// Only used when conversion is enabled. pdf-parse v2 is a CLASS api
// (new PDFParse({ data }).getText()) — the old v1 `pdfParse(buffer)` call does
// not exist and used to make EVERY PDF upload fail with "Could not read this PDF".
const MIN_TEXT_LENGTH = 100;
const isTextBasedPdf = async (buffer: Buffer): Promise<boolean> => {
  const mod = (await import('pdf-parse')) as unknown as {
    PDFParse: new (opts: { data: Uint8Array }) => {
      getText: () => Promise<{ text: string }>;
      destroy?: () => Promise<void>;
    };
  };
  const parser = new mod.PDFParse({ data: new Uint8Array(buffer) });
  try {
    const result = await parser.getText();
    return result.text.trim().length >= MIN_TEXT_LENGTH;
  } finally {
    await parser.destroy?.().catch(() => undefined);
  }
};

// ── uploadFile ────────────────────────────────────────────────────────────────

export const uploadFile = asyncHandler(async (req: Request, res: Response) => {
  if (!req.file) {
    errorResponse(
      res,
      "No file provided. Send a multipart/form-data request with a 'file' field.",
      400,
    );
    return;
  }

  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401);
    return;
  }

  const { buffer, mimetype, originalname, size } = req.file;
  const { userId, plan } = req.user;

  // ── Validate format ───────────────────────────────────────────────────────
  const originalFormat = resolveFormat(mimetype, originalname);
  if (!originalFormat) {
    errorResponse(res, 'Unsupported file type.', 400);
    return;
  }

  if (!looksLikeFormat(buffer, originalFormat)) {
    errorResponse(
      res,
      `This file does not look like a valid ${originalFormat.toUpperCase()}. It may be corrupted.`,
      400,
    );
    return;
  }

  // ── Free-plan library limit (same rule the Discover flow already enforces) ─
  if (plan === 'free') {
    const count = await Book.countDocuments({ userId, status: 'ready' });
    if (count >= FREE_PLAN_LIBRARY_LIMIT) {
      errorResponse(
        res,
        `Free plan is limited to ${FREE_PLAN_LIBRARY_LIMIT} books. Upgrade to Premium for unlimited access.`,
        403,
      );
      return;
    }
  }

  // ── Conversion path only: PDF must be text-based ──────────────────────────
  if (CONVERSION_ENABLED && originalFormat === 'pdf') {
    try {
      if (!(await isTextBasedPdf(buffer))) {
        errorResponse(
          res,
          'This PDF appears to be scanned or image-based. Only text-based PDFs can be converted.',
          400,
        );
        return;
      }
    } catch (err) {
      console.error('[upload] pdf-parse failed:', err);
      errorResponse(res, 'Could not read this PDF. It may be password-protected or corrupted.', 400);
      return;
    }
  }

  // ── Upload original to Cloudinary ─────────────────────────────────────────
  // The extension is part of the public_id for raw files, so the delivery URL
  // ends in .pdf / .epub (readers and CDNs rely on that).
  const baseName = path.parse(originalname).name.replace(/[^\w.-]+/g, '_').slice(0, 80) || 'book';
  const filename = `${baseName}_${uuidv4()}.${originalFormat}`;

  let uploadResult: { url: string; publicId: string };
  try {
    uploadResult = await cloudinaryService.uploadFile(buffer, {
      folder: 'readin/originals',
      filename,
      resourceType: 'raw',
    });
  } catch (err) {
    console.error('[cloudinary] Upload failed:', err);
    errorResponse(res, 'File storage failed. Please try again.', 502);
    return;
  }

  const title = path.parse(originalname).name.replace(/[_]+/g, ' ').trim() || 'Untitled';

  // ── Native formats: ready immediately, no queue ───────────────────────────
  if (!CONVERSION_ENABLED || originalFormat === 'epub') {
    // Cloud backup of ANY supported format: stored as-is, readable on the phone.
    const book = await Book.create({
      userId,
      title,
      originalFileUrl: uploadResult.url,
      originalFilePublicId: uploadResult.publicId,
      // Same file serves as the readable file — the app opens it natively.
      convertedFileUrl: uploadResult.url,
      convertedFilePublicId: uploadResult.publicId,
      originalFormat,
      fileSize: size,
      status: 'ready',
      source: 'upload',
    });

    const jobId = uuidv4();
    await Job.create({
      jobId,
      userId,
      bookId: book._id,
      status: 'completed',
      progress: 100,
      originalFilename: originalname,
      originalFormat,
      originalFileUrl: uploadResult.url,
      completedAt: new Date(),
    });

    successResponse(
      res,
      {
        bookId: book._id.toString(),
        jobId,
        status: 'ready',
        message: `${originalFormat.toUpperCase()} imported. Ready to read!`,
      },
      `${originalFormat.toUpperCase()} imported successfully.`,
      201,
    );
    return;
  }

  // ── Conversion path (CONVERSION_ENABLED=true): queue for Calibre ──────────
  const { conversionQueue } = await import('../jobs/queue.js');

  const book = await Book.create({
    userId,
    title,
    originalFileUrl: uploadResult.url,
    originalFilePublicId: uploadResult.publicId,
    originalFormat,
    fileSize: size,
    status: 'queued',
    source: 'upload',
  });

  const tempJobId = uuidv4();
  await Job.create({
    jobId: tempJobId,
    userId,
    bookId: book._id,
    status: 'waiting',
    originalFilename: originalname,
    originalFormat,
    originalFileUrl: uploadResult.url,
  });

  const bullJob = await conversionQueue.add('convert', {
    bookId: book._id.toString(),
    jobId: tempJobId,
    userId,
    originalFileUrl: uploadResult.url,
    originalFilename: originalname,
    originalFormat,
  });

  const finalJobId = bullJob.id ?? tempJobId;
  await Job.findOneAndUpdate({ jobId: tempJobId }, { jobId: finalJobId });
  book.jobId = finalJobId;
  await book.save();

  successResponse(
    res,
    {
      bookId: book._id.toString(),
      jobId: finalJobId,
      status: 'queued',
      message: 'File uploaded. Converting to EPUB — this usually takes under 2 minutes.',
    },
    'File uploaded successfully.',
    201,
  );
});

// ── getJobStatus ──────────────────────────────────────────────────────────────

export const getJobStatus = asyncHandler(async (req: Request, res: Response) => {
  const jobId = req.params['jobId'];

  if (!jobId) {
    errorResponse(res, 'jobId parameter is required.', 400);
    return;
  }

  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401);
    return;
  }

  const job = await Job.findOne({ jobId, userId: req.user.userId });

  if (!job) {
    errorResponse(res, 'Job not found.', 404);
    return;
  }

  const responseData: {
    jobId: string;
    bookId: string;
    status: string;
    progress: number;
    startedAt: Date | null;
    completedAt: Date | null;
    error?: string;
  } = {
    jobId: job.jobId,
    bookId: job.bookId.toString(),
    status: job.status,
    progress: job.progress,
    startedAt: job.startedAt,
    completedAt: job.completedAt,
  };

  if (job.error !== null && job.error !== undefined) {
    responseData.error = job.error;
  }

  successResponse(res, responseData, 'Job status retrieved.');
});
