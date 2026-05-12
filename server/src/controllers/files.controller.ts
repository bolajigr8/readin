import type { Request, Response } from 'express'
import asyncHandler from 'express-async-handler'
import { v4 as uuidv4 } from 'uuid'
import path from 'path'
import pdfParseMod from 'pdf-parse'

import { cloudinaryService } from '../services/cloudinary.service.js'
import { Book } from '../models/book.model.js'
import { Job } from '../models/job.model.js'
import { conversionQueue, type ConversionJobData } from '../jobs/queue.js'
import { successResponse, errorResponse } from '../utils/response.utils.js'
import type { OriginalFormat } from '../models/book.model.js'

// ── pdf-parse v2.x cast ───────────────────────────────────────────────────────
interface PdfData {
  text: string
  numpages: number
}
type PdfParseFn = (dataBuffer: Buffer) => Promise<PdfData>
const pdfParse = pdfParseMod as unknown as PdfParseFn

// ── MIME → format map ─────────────────────────────────────────────────────────
const MIME_TO_FORMAT: Record<string, OriginalFormat> = {
  'application/pdf': 'pdf',
  'application/epub+zip': 'epub',
  'application/x-mobipocket-ebook': 'mobi',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
    'docx',
  'text/plain': 'txt',
}

const MIN_TEXT_LENGTH = 100

// ── uploadFile ────────────────────────────────────────────────────────────────

export const uploadFile = asyncHandler(async (req: Request, res: Response) => {
  if (!req.file) {
    errorResponse(
      res,
      "No file provided. Send a multipart/form-data request with a 'file' field.",
      400,
    )
    return
  }

  const { buffer, mimetype, originalname, size } = req.file

  // PDF text-based check
  if (mimetype === 'application/pdf') {
    try {
      const pdfData = await pdfParse(buffer)
      if (pdfData.text.trim().length < MIN_TEXT_LENGTH) {
        errorResponse(
          res,
          'This PDF appears to be scanned or image-based. Only text-based PDFs are supported.',
          400,
        )
        return
      }
    } catch {
      errorResponse(
        res,
        'Could not parse the uploaded PDF. The file may be corrupted.',
        400,
      )
      return
    }
  }

  const originalFormat = MIME_TO_FORMAT[mimetype]
  if (!originalFormat) {
    errorResponse(res, 'Unsupported file type.', 400)
    return
  }

  const baseName = path.parse(originalname).name.replace(/\s+/g, '_')
  const filename = `${baseName}_${uuidv4()}`

  // Upload original to Cloudinary
  let uploadResult: { url: string; publicId: string }
  try {
    uploadResult = await cloudinaryService.uploadFile(buffer, {
      folder: 'readin/originals',
      filename,
      resourceType: 'raw',
    })
  } catch (err) {
    console.error('[cloudinary] Upload failed:', err)
    errorResponse(res, 'File storage failed. Please try again.', 502)
    return
  }

  if (!req.user) {
    errorResponse(res, 'Not authenticated.', 401)
    return
  }

  const { userId } = req.user

  // Create Book document
  const book = await Book.create({
    userId,
    title: baseName.replace(/_/g, ' '),
    originalFileUrl: uploadResult.url,
    originalFilePublicId: uploadResult.publicId,
    originalFormat,
    fileSize: size,
    status: 'queued',
  })

  // Create Job document
  const tempJobId = uuidv4()
  await Job.create({
    jobId: tempJobId,
    userId,
    bookId: book._id,
    status: 'waiting',
  })

  // ── Dispatch BullMQ job ───────────────────────────────────────────────────
  // No base64 buffer — worker downloads directly from Cloudinary.
  // This keeps Redis payloads tiny (~200 bytes) regardless of file size.
  const jobPayload: ConversionJobData = {
    bookId: book._id.toString(),
    jobId: tempJobId,
    userId,
    originalFileUrl: uploadResult.url, // ← Cloudinary URL only
    originalFilename: originalname,
    originalFormat,
  }

  const bullJob = await conversionQueue.add('convert', jobPayload)

  const finalJobId = bullJob.id ?? tempJobId
  await Job.findOneAndUpdate({ jobId: tempJobId }, { jobId: finalJobId })
  book.jobId = finalJobId
  await book.save()

  successResponse(
    res,
    {
      bookId: book._id.toString(),
      jobId: finalJobId,
      status: 'queued',
      message: 'File uploaded. Conversion queued.',
    },
    'File uploaded successfully.',
    201,
  )
})

// ── getJobStatus ──────────────────────────────────────────────────────────────

export const getJobStatus = asyncHandler(
  async (req: Request, res: Response) => {
    const jobId = req.params['jobId']

    if (!jobId) {
      errorResponse(res, 'jobId parameter is required.', 400)
      return
    }

    if (!req.user) {
      errorResponse(res, 'Not authenticated.', 401)
      return
    }

    const job = await Job.findOne({ jobId, userId: req.user.userId })

    if (!job) {
      errorResponse(res, 'Job not found.', 404)
      return
    }

    const responseData: {
      jobId: string
      bookId: string
      status: string
      progress: number
      startedAt: Date | null
      completedAt: Date | null
      error?: string
    } = {
      jobId: job.jobId,
      bookId: job.bookId.toString(),
      status: job.status,
      progress: job.progress,
      startedAt: job.startedAt,
      completedAt: job.completedAt,
    }

    if (job.error !== null) {
      responseData.error = job.error
    }

    successResponse(res, responseData, 'Job status retrieved.')
  },
)
