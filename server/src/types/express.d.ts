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
      /** Set by requireStaff (admin.middleware.ts): the team member's role and admin-panel permissions (S5). */
      staff?: {
        role: import('../services/roles.logic.js').Role
        permissions: import('../services/roles.logic.js').Permission[]
      }
    }
  }
}

// Required to make this a module (not a script) so the global augmentation works
export {}
