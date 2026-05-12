import { Queue } from 'bullmq'
import { redisConnection } from '../config/redis.js'

export interface ConversionJobData {
  bookId: string
  jobId: string
  userId: string
  originalFileUrl: string // ← Cloudinary URL — worker downloads from here
  originalFilename: string
  originalFormat: string
}

export const conversionQueue = new Queue<ConversionJobData>('conversion', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
  },
})
