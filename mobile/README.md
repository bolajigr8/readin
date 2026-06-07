# ReadIn — Complete Developer Documentation

## Architecture

Phone (React Native + Expo) → HTTPS → Render Backend (Node + Express)
↓ ↓
MongoDB Atlas Cloudinary
↓
Upstash Redis (BullMQ)

## Backend File Structure

server/src/
├── app.ts # Express setup + all routes
├── config/
│ ├── db.ts # MongoDB connection
│ ├── cloudinary.ts # Cloudinary config
│ └── redis.ts # IORedis for BullMQ
├── models/
│ ├── user.model.ts # User schema
│ ├── book.model.ts # Book schema
│ ├── job.model.ts # Conversion job schema
│ ├── annotation.model.ts # Highlights + notes
│ ├── bookmark.model.ts # Bookmarks
│ └── progress.model.ts # Reading progress
├── controllers/ # All route handlers
├── routes/ # Express routers
├── middleware/
│ ├── auth.middleware.ts # JWT verification
│ ├── error.middleware.ts # Global error handler
│ ├── rateLimit.middleware.ts # Rate limiting
│ └── upload.middleware.ts # Multer config
├── services/
│ ├── cloudinary.service.ts # File upload/delete
│ ├── calibre.service.ts # PDF→EPUB conversion
│ └── push-notification.service.ts
├── jobs/
│ ├── queue.ts # BullMQ queue
│ └── conversion.worker.ts # Background worker
└── scripts/
└── seed.ts # Test data

## Mobile File Structure

mobile/src/
├── app/
│ ├── \_layout.tsx # Root: providers, auth gate
│ ├── onboarding.tsx # 5-slide welcome (once only)
│ ├── upload.tsx # Upload modal
│ ├── upgrade.tsx # Premium paywall
│ ├── audio-player.tsx # TTS audio player
│ ├── (auth)/login|register|forgot-password
│ ├── (tabs)/index|library|discover|profile
│ ├── reader/[bookId].tsx # Full EPUB reader
│ └── book-detail/[id].tsx # Gutenberg book detail
├── components/
│ ├── AppDrawer.tsx # Hamburger drawer
│ ├── AppHeader.tsx # Header + hamburger
│ ├── BookCard.tsx # Book card (grid/list)
│ ├── BookGrid.tsx # FlatList grid
│ ├── ContinueReadingBanner.tsx
│ ├── DiscoverBookCard.tsx
│ ├── EmptyState.tsx
│ ├── HighlightMenu.tsx # Colour picker for text
│ ├── MiniPlayer.tsx # Audio mini player
│ ├── NoteEditor.tsx # Note input modal
│ ├── AnnotationsList.tsx # Highlights bottom sheet
│ ├── PremiumBanner.tsx
│ ├── ReaderWebView.tsx # epub.js in WebView
│ ├── ReaderToolbar.tsx # Reader controls
│ ├── ChapterDrawer.tsx # TOC panel
│ ├── ReaderSettings.tsx # Font/theme settings
│ ├── UploadProgressCard.tsx
│ └── ui/Button|Card|Input|LoadingSpinner
├── context/
│ ├── DrawerContext.tsx # Drawer open/close state
│ └── ToastContext.tsx # Global toasts
├── hooks/
│ ├── useAuth.ts
│ ├── useLibrary.ts
│ ├── useUpload.ts # Document picker + polling
│ ├── useReader.ts # Load + download EPUB
│ ├── useAnnotations.ts
│ ├── useBookmarks.ts
│ ├── useDiscover.ts # Gutendex API
│ ├── useAudio.ts # expo-speech controls
│ └── usePremium.ts # RevenueCat
├── services/
│ ├── api.ts # Axios + auto token refresh
│ └── gutendex.ts # Gutendex API
├── store/
│ ├── authStore.ts # User + tokens
│ ├── libraryStore.ts # Active uploads
│ ├── readerStore.ts # CFI, chapter, font, theme
│ ├── settingsStore.ts # Preferences (AsyncStorage)
│ └── audioStore.ts # TTS state
└── constants/theme.ts # All design tokens

## Key Flows

### Conversion Pipeline

Upload → Cloudinary (original) → BullMQ job → Worker downloads →
Calibre converts → Cloudinary (EPUB) → Book status: 'ready'

### Auth Flow

Login → JWT (15min) + RefreshToken (7 days) → SecureStore →
On 401: auto-refresh → retry original request

### Reader Flow

Tap book → useReader() → check local file → download if needed →
ReaderWebView (epub.js HTML) → bidirectional JS bridge →
Progress sync every 30s + on unmount

## Environment Variables

### Backend (.env)

PORT=3000
NODE*ENV=production
MONGODB_URI=mongodb+srv://...
JWT_SECRET=min_32_chars
JWT_REFRESH_SECRET=different_min_32_chars
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
RESEND_API_KEY=re*...
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
UPSTASH_REDIS_URL=rediss://...
REVENUECAT_WEBHOOK_SECRET=...

### Mobile (.env)

EXPO_PUBLIC_API_URL=https://your-backend.onrender.com/api/v1
EXPO_PUBLIC_GOOGLE_CLIENT_ID=web_client_id
EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID=ios_client_id
EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID=android_client_id
EXPO_PUBLIC_REVENUECAT_API_KEY=your_key

## Quick Commands

npm run dev # Start backend dev server
npm run seed # Seed test accounts
npx expo start # Start mobile dev server
npx expo start --clear # Clear cache + start
eas build --platform android --profile preview # Build APK
eas build --platform android --profile production # Build AAB (Play Store)
