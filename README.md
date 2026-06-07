# ReadIn 📚

> Transform any document into a beautiful reading experience. Upload PDFs, discover 10,000+ free classics, and read — anywhere.

---

## What is ReadIn?

ReadIn is a mobile reading platform that solves a real problem: getting documents and books into a clean, readable format on your phone is painful. ReadIn fixes that.

Upload a PDF from your phone. In seconds, it's converted to a beautiful EPUB and ready to read — with custom fonts, themes, highlights, and text-to-speech. No desktop required. No complicated steps.

It also connects to Project Gutenberg — giving you free, instant access to over 70,000 public domain books.

---

## Features

| Feature               | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| 📤 Upload & Convert   | Upload PDF, EPUB, DOCX, MOBI, or TXT — converted automatically |
| 📖 EPUB Reader        | Custom fonts, three themes, page navigation                    |
| 🔍 Discover           | Browse 70,000+ free books from Project Gutenberg               |
| 🎧 Audio Player       | Built-in text-to-speech — listen hands-free                    |
| ✏️ Highlights & Notes | 5 highlight colours, personal notes                            |
| 🔖 Bookmarks          | Bookmark any page, jump back instantly                         |
| 📊 Reading Stats      | Books read, time reading, completion rates                     |
| ⭐ Premium            | Unlimited books and annotations                                |

---

## Tech Stack

**Mobile:** React Native · Expo SDK 54 · NativeWind · Zustand · TanStack Query  
**Backend:** Node.js · TypeScript · Express · MongoDB · Cloudinary · BullMQ  
**Infrastructure:** Render · MongoDB Atlas · Upstash Redis · EAS Build

---

## Getting Started

```bash
# Clone
git clone https://github.com/yourusername/readin.git

# Backend
cd readin/server && npm install
cp .env.example .env
npm run dev

# Mobile
cd readin/mobile && npm install
cp .env.example .env
npx expo start
```

---

## Test Accounts

```bash
cd server && npm run seed
```

| Email             | Password         | Plan             |
| ----------------- | ---------------- | ---------------- |
| alice@readin.test | TestPassword123! | Free — empty     |
| bob@readin.test   | TestPassword123! | Free — at limits |
| carol@readin.test | TestPassword123! | Premium          |

---

Built with ❤️ by Micbol — solving real problems with real code.

npx expo install react-native-purchases
