import mongoose, { type Document, Schema, type Types } from 'mongoose'

/** Who changed what in the admin API (append-only trail). */
export interface IAdminAudit extends Document {
  adminId: Types.ObjectId
  action: string
  targetUserId: Types.ObjectId | null
  details: unknown
  ip: string
  createdAt: Date
}

const adminAuditSchema = new Schema<IAdminAudit>(
  {
    adminId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    action: { type: String, required: true },
    targetUserId: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    details: { type: Schema.Types.Mixed, default: null },
    ip: { type: String, default: '' },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
)

adminAuditSchema.index({ createdAt: -1 })

export const AdminAudit = mongoose.model<IAdminAudit>('AdminAudit', adminAuditSchema)
