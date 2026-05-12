/**
 * Extends Express's Request interface to carry the authenticated user payload
 * that auth.middleware.ts attaches after verifying the access token.
 */
declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string
        plan: string
      }
    }
  }
}

// Required to make this a module (not a script) so the global augmentation works
export {}
