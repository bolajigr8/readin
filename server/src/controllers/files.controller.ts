import type { Request, Response } from 'express';
import asyncHandler from 'express-async-handler';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import pdfParseMod from 'pdf-parse';

import { cloudinaryService } from '../services/cloudinary.service.js';
import { Book } from '../models/book.model.js';
import { Job } from '../models/job.model.js';
import { conversionQueue, type ConversionJobData } from '../jobs/queue.js';
import { successResponse, errorResponse } from '../utils/response.utils.js';
import type { OriginalFormat } from '../models/book.model.js';

// ── pdf-parse v2.x cast ───────────────────────────────────────────────────────
interface PdfData {
  text: string;
  numpages: number;
}
type PdfParseFn = (dataBuffer: Buffer) => Promise<PdfData>;
const pdfParse = pdfParseMod as unknown as PdfParseFn;

// ── MIME → format map ─────────────────────────────────────────────────────────
const MIME_TO_FORMAT: Record<string, OriginalFormat> = {
  'application/pdf': 'pdf',
  'application/epub+zip': 'epub',
  'application/x-mobipocket-ebook': 'mobi',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'text/plain': 'txt',
};

// Minimum characters for a PDF to be considered text-based.
// Below this threshold it's likely scanned/image-only.
const MIN_TEXT_LENGTH = 100;

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
  const { userId } = req.user;

  // ── Validate format ───────────────────────────────────────────────────────
  const originalFormat = MIME_TO_FORMAT[mimetype];
  if (!originalFormat) {
    errorResponse(
      res,
      `Unsupported file type "${mimetype}". Accepted formats: PDF, EPUB, DOCX, MOBI, TXT.`,
      400,
    );
    return;
  }

  // ── PDF: validate it is text-based, not a scanned image ──────────────────
  // Scanned/image PDFs have no extractable text. Calibre cannot convert them.
  // We check upfront so the user gets a clear error immediately.
  if (mimetype === 'application/pdf') {
    try {
      const pdfData = await pdfParse(buffer);
      if (pdfData.text.trim().length < MIN_TEXT_LENGTH) {
        errorResponse(
          res,
          'This PDF appears to be scanned or image-based. Only text-based PDFs can be converted. ' +
            'Tip: If you have the original document (Word, etc.), upload that instead.',
          400,
        );
        return;
      }
    } catch {
      errorResponse(
        res,
        'Could not read this PDF. The file may be password-protected or corrupted. ' +
          'Please try a different PDF.',
        400,
      );
      return;
    }
  }

  // ── Upload original to Cloudinary ─────────────────────────────────────────
  const baseName = path.parse(originalname).name.replace(/\s+/g, '_');
  const filename = `${baseName}_${uuidv4()}`;

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

  // ── Create Book document ──────────────────────────────────────────────────
  const book = await Book.create({
    userId,
    title: baseName.replace(/_/g, ' '),
    originalFileUrl: uploadResult.url,
    originalFilePublicId: uploadResult.publicId,
    originalFormat,
    fileSize: size,
    status: 'queued',
    source: 'upload',
  });

  // ── EPUB: no conversion needed — mark ready immediately ───────────────────
  // EPUBs are already in the format that the reader (epub.js) consumes.
  // Sending them through Calibre is unnecessary and wastes queue resources.
  // We store the original file as the "converted" file and skip the queue.
  if (originalFormat === 'epub') {
    const epubJobId = uuidv4();

    // Update book: ready to read right now
    await Book.findByIdAndUpdate(book._id, {
      status: 'ready',
      convertedFileUrl: uploadResult.url, // same URL — no conversion
      convertedFilePublicId: uploadResult.publicId,
    });

    // Create a completed job record for consistency
    // (the mobile app polls this to know the book is ready)
    await Job.create({
      jobId: epubJobId,
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
        jobId: epubJobId,
        status: 'ready',
        message: 'EPUB imported. Ready to read!',
      },
      'EPUB imported successfully.',
      201,
    );
    return;
  }

  // ── Other formats (PDF, DOCX, MOBI, TXT): queue for Calibre conversion ───
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

  // Dispatch to BullMQ. The worker downloads from Cloudinary URL directly.
  // We never store the file buffer in Redis — keeps payloads tiny.
  const jobPayload: ConversionJobData = {
    bookId: book._id.toString(),
    jobId: tempJobId,
    userId,
    originalFileUrl: uploadResult.url,
    originalFilename: originalname,
    originalFormat,
  };

  const bullJob = await conversionQueue.add('convert', jobPayload);

  // BullMQ generates its own internal ID. Sync it with our Job document.
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
