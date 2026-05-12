import dns from 'node:dns/promises'

// Cloudflare and Google DNS servers — prevents Atlas hostname resolution
// failures that can occur with certain ISP or container DNS configurations
dns.setServers(['1.1.1.1', '1.0.0.1', '8.8.8.8', '8.8.4.4'])

import mongoose from 'mongoose'

export const connectDB = async (): Promise<void> => {
  const uri = process.env['MONGODB_URI']

  if (!uri) {
    console.error('❌ Fatal: MONGODB_URI is not set in environment variables')
    process.exit(1)
  }

  try {
    await mongoose.connect(uri)
    console.log('✅ MongoDB connected')
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error)
    process.exit(1)
  }
}
