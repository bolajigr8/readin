import { User } from '../models/user.model.js'

// ── Expo Push API types ───────────────────────────────────────────────────────

interface ExpoPushMessage {
  to: string
  title: string
  body: string
  data?: Record<string, unknown>
}

interface ExpoPushTicket {
  status: 'ok' | 'error'
  details?: {
    error?: string
  }
}

interface ExpoPushResponse {
  data: ExpoPushTicket[]
}

// ── Service ───────────────────────────────────────────────────────────────────

export class PushNotificationService {
  private readonly apiUrl = 'https://exp.host/--/api/v2/push/send'

  /**
   * Send a push notification via Expo's free push API.
   * Never throws — push failures must never crash the conversion pipeline.
   */
  async sendNotification(
    expoPushToken: string,
    title: string,
    body: string,
    data?: Record<string, unknown>,
  ): Promise<void> {
    const message: ExpoPushMessage = { to: expoPushToken, title, body }

    // Only attach data key when a value is provided (exactOptionalPropertyTypes safe)
    if (data !== undefined) {
      message.data = data
    }

    try {
      const response = await fetch(this.apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'Accept-Encoding': 'gzip, deflate',
        },
        body: JSON.stringify(message),
      })

      if (!response.ok) {
        console.error('[push] Expo API non-OK status:', response.status)
        return
      }

      const result = (await response.json()) as ExpoPushResponse
      const ticket = result.data[0]

      if (ticket !== undefined && ticket.status === 'error') {
        if (ticket.details?.error === 'DeviceNotRegistered') {
          // Token is stale — clear it so we stop trying
          await User.updateOne(
            { expoPushToken },
            { $set: { expoPushToken: null } },
          )
          console.warn('[push] DeviceNotRegistered — push token cleared')
        } else {
          console.error('[push] Push ticket error:', ticket.details)
        }
      }
    } catch (err) {
      // Intentionally swallowed — push should never affect core flow
      console.error('[push] Failed to send notification:', err)
    }
  }

  async sendConversionComplete(
    userId: string,
    bookTitle: string,
    bookId: string,
  ): Promise<void> {
    const user = await User.findById(userId).select('expoPushToken').lean()
    const token = user?.expoPushToken
    if (!token) return

    await this.sendNotification(
      token,
      'Conversion Complete 📚',
      `${bookTitle} is ready to read`,
      { bookId },
    )
  }

  async sendConversionFailed(userId: string, bookTitle: string): Promise<void> {
    const user = await User.findById(userId).select('expoPushToken').lean()
    const token = user?.expoPushToken
    if (!token) return

    await this.sendNotification(
      token,
      'Conversion Failed',
      `We could not convert ${bookTitle}. Please try again.`,
    )
  }
}

export const pushNotificationService = new PushNotificationService()
