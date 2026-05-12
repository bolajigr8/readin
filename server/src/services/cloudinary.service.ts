// Storage provider: Cloudinary.
// To swap to S3 or Supabase Storage, replace the methods below
// with implementations that match the same signatures.

import { type UploadApiResponse } from 'cloudinary'
import cloudinary from '../config/cloudinary.js'

interface UploadOptions {
  folder: string
  filename: string
  resourceType: 'raw' | 'image' | 'auto'
}

interface UploadResult {
  url: string
  publicId: string
}

export class CloudinaryService {
  /**
   * Upload a Buffer to Cloudinary via upload_stream.
   * Works for any resource type (PDF → raw, image → image, etc.).
   */
  uploadFile(buffer: Buffer, options: UploadOptions): Promise<UploadResult> {
    return new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: options.folder,
          public_id: options.filename,
          resource_type: options.resourceType,
          overwrite: true,
        },
        (error, result: UploadApiResponse | undefined) => {
          if (error) {
            reject(new Error(`Cloudinary upload failed: ${error.message}`))
            return
          }
          if (!result) {
            reject(new Error('Cloudinary returned no result'))
            return
          }
          resolve({ url: result.secure_url, publicId: result.public_id })
        },
      )

      stream.end(buffer)
    })
  }

  /**
   * Delete a file by its Cloudinary public_id.
   */
  async deleteFile(publicId: string): Promise<void> {
    await cloudinary.uploader.destroy(publicId, { resource_type: 'raw' })
  }

  /**
   * Generate a signed URL for private/expiring access.
   */
  getSignedUrl(publicId: string, expiresInSeconds: number): string {
    return cloudinary.url(publicId, {
      secure: true,
      sign_url: true,
      expires_at: Math.floor(Date.now() / 1000) + expiresInSeconds,
    })
  }
}

// Singleton
export const cloudinaryService = new CloudinaryService()
