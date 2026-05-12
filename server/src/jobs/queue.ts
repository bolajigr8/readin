import { Queue } from 'bullmq'
import { redisConnection } from '../config/redis.js'

export interface ConversionJobData {
  bookId: string
  jobId: string
  userId: string
  fileBuffer: string // base64 encoded — buffers can't be serialised to Redis directly
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
