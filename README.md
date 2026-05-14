arkdown# ReadIn

A production-ready, mobile-first document conversion and reading platform.

## Structure

readin/
├── server/ ← Node.js / Express / MongoDB backend
└── mobile/ ← React Native Expo app (Prompt 10)

## Getting Started

```bash
cd server
pnpm install
cp .env.example .env   # fill in your values
pnpm dev
```

npx expo start

husky to lint

cd server
pnpm exec lint-staged
pnpm run typecheck
cd ..

cd mobile
pnpm run lint
cd ..
