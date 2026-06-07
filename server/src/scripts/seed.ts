/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║              ReadIn — Database Seed Script                   ║
 * ║                                                              ║
 * ║  Creates 4 test users with realistic data.                   ║
 * ║  Safe to run multiple times — cleans previous data first.   ║
 * ║                                                              ║
 * ║  Run:  npm run seed                                          ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 *  USER ACCOUNTS CREATED
 * ┌─────────────────────┬──────────────────────┬─────────┬───────────────────────────────────┐
 * │ Name                │ Email                │ Plan    │ Purpose                           │
 * ├─────────────────────┼──────────────────────┼─────────┼───────────────────────────────────┤
 * │ Alice Anderson      │ alice@readin.test     │ free    │ Empty state, first upload flow    │
 * │ Bob Brown           │ bob@readin.test       │ free    │ Freemium gates, limits reached    │
 * │ Carol Chen          │ carol@readin.test     │ premium │ Premium features, reading stats   │
 * │ Dave Davis          │ dave@readin.test      │ free    │ Google OAuth user (no password)   │
 * └─────────────────────┴──────────────────────┴─────────┴───────────────────────────────────┘
 *
 *  Password for Alice, Bob, Carol: TestPassword123!
 *  Dave has no password — simulates Google OAuth sign-in.
 */

import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import mongoose from 'mongoose';
import { connectDB } from '../config/db.js';
import { User, type IUser } from '../models/user.model.js';
import { Book } from '../models/book.model.js';
import { Annotation } from '../models/annotation.model.js';
import { Bookmark } from '../models/bookmark.model.js';
import { Progress } from '../models/progress.model.js';

// ── Constants ─────────────────────────────────────────────────────────────────

const TEST_PASSWORD = 'TestPassword123!';
const TEST_DOMAIN = '@readin.test';

// Gutenberg CDN URL builders
const epubUrl = (id: number) => `https://www.gutenberg.org/cache/epub/${id}/pg${id}.epub`;
const coverUrl = (id: number) =>
  `https://www.gutenberg.org/cache/epub/${id}/pg${id}.cover.medium.jpg`;

// ── Book catalogue ────────────────────────────────────────────────────────────

interface BookTemplate {
  gutenbergId: string;
  title: string;
  author: string;
  description: string;
  coverUrl: string;
  epubUrl: string;
  genre: string;
  pageCount: number;
}

const BOOKS: BookTemplate[] = [
  {
    gutenbergId: '1342',
    title: 'Pride and Prejudice',
    author: 'Jane Austen',
    description:
      'A romantic novel of manners that follows the Bennet family, their five daughters, and the proud Mr. Darcy. One of the most beloved novels in English literature.',
    coverUrl: coverUrl(1342),
    epubUrl: epubUrl(1342),
    genre: 'Romance',
    pageCount: 432,
  },
  {
    gutenbergId: '84',
    title: 'Frankenstein',
    author: 'Mary Wollstonecraft Shelley',
    description:
      'A young scientist creates a sapient creature in an unorthodox scientific experiment. A landmark of Gothic fiction and science fiction.',
    coverUrl: coverUrl(84),
    epubUrl: epubUrl(84),
    genre: 'Gothic Fiction',
    pageCount: 280,
  },
  {
    gutenbergId: '1661',
    title: 'The Adventures of Sherlock Holmes',
    author: 'Arthur Conan Doyle',
    description:
      'A collection of twelve short stories featuring the famous detective Sherlock Holmes and his faithful companion Dr. Watson.',
    coverUrl: coverUrl(1661),
    epubUrl: epubUrl(1661),
    genre: 'Mystery',
    pageCount: 307,
  },
  {
    gutenbergId: '1260',
    title: 'Jane Eyre',
    author: 'Charlotte Brontë',
    description:
      'The story of Jane Eyre, an orphan who becomes a governess and falls in love with her brooding employer, Mr. Rochester.',
    coverUrl: coverUrl(1260),
    epubUrl: epubUrl(1260),
    genre: 'Gothic Romance',
    pageCount: 507,
  },
  {
    gutenbergId: '2701',
    title: 'Moby Dick',
    author: 'Herman Melville',
    description:
      "The saga of Captain Ahab's obsessive quest to slay Moby Dick, the white whale that destroyed his ship and took his leg.",
    coverUrl: coverUrl(2701),
    epubUrl: epubUrl(2701),
    genre: 'Adventure',
    pageCount: 635,
  },
  {
    gutenbergId: '11',
    title: "Alice's Adventures in Wonderland",
    author: 'Lewis Carroll',
    description:
      'A young girl named Alice falls through a rabbit hole into a fantasy world populated by peculiar creatures.',
    coverUrl: coverUrl(11),
    epubUrl: epubUrl(11),
    genre: 'Fantasy',
    pageCount: 96,
  },
  {
    gutenbergId: '174',
    title: 'The Picture of Dorian Gray',
    author: 'Oscar Wilde',
    description:
      'A young man sells his soul for eternal youth and beauty while a portrait bears the burden of his corruption and age.',
    coverUrl: coverUrl(174),
    epubUrl: epubUrl(174),
    genre: 'Philosophical Fiction',
    pageCount: 254,
  },
  {
    gutenbergId: '345',
    title: 'Dracula',
    author: 'Bram Stoker',
    description:
      'A Transylvanian vampire makes his way to England to find new blood, while a small group of people attempt to stop him.',
    coverUrl: coverUrl(345),
    epubUrl: epubUrl(345),
    genre: 'Horror',
    pageCount: 418,
  },
  {
    gutenbergId: '158',
    title: 'Emma',
    author: 'Jane Austen',
    description:
      'Emma Woodhouse is a young woman who meddles in the love lives of her friends. A comedy of manners and self-discovery.',
    coverUrl: coverUrl(158),
    epubUrl: epubUrl(158),
    genre: 'Comedy',
    pageCount: 474,
  },
  {
    gutenbergId: '1184',
    title: 'The Count of Monte Cristo',
    author: 'Alexandre Dumas',
    description:
      'A man wrongfully imprisoned escapes and plots an elaborate revenge against those who betrayed him.',
    coverUrl: coverUrl(1184),
    epubUrl: epubUrl(1184),
    genre: 'Adventure',
    pageCount: 1276,
  },
  {
    gutenbergId: '2600',
    title: 'War and Peace',
    author: 'Leo Tolstoy',
    description:
      'An epic novel set during the Napoleonic Wars that follows five aristocratic Russian families through war, peace, and love.',
    coverUrl: coverUrl(2600),
    epubUrl: epubUrl(2600),
    genre: 'Historical Fiction',
    pageCount: 1225,
  },
  {
    gutenbergId: '2554',
    title: 'Crime and Punishment',
    author: 'Fyodor Dostoevsky',
    description:
      'A student commits murder and wrestles with guilt, morality, and redemption in 19th century St. Petersburg.',
    coverUrl: coverUrl(2554),
    epubUrl: epubUrl(2554),
    genre: 'Psychological Fiction',
    pageCount: 545,
  },
  {
    gutenbergId: '120',
    title: 'Treasure Island',
    author: 'Robert Louis Stevenson',
    description:
      'A young boy discovers a treasure map and sets off on a seafaring adventure with pirates in search of buried gold.',
    coverUrl: coverUrl(120),
    epubUrl: epubUrl(120),
    genre: 'Adventure',
    pageCount: 292,
  },
  {
    gutenbergId: '2852',
    title: 'The Hound of the Baskervilles',
    author: 'Arthur Conan Doyle',
    description:
      'Sherlock Holmes investigates the legend of a supernatural hound that haunts the Baskerville family on the Dartmoor moors.',
    coverUrl: coverUrl(2852),
    epubUrl: epubUrl(2852),
    genre: 'Mystery',
    pageCount: 256,
  },
  {
    gutenbergId: '74',
    title: 'The Adventures of Tom Sawyer',
    author: 'Mark Twain',
    description:
      'The adventures of a mischievous boy growing up along the Mississippi River, including a murder, a haunted house, and buried treasure.',
    coverUrl: coverUrl(74),
    epubUrl: epubUrl(74),
    genre: "Children's Literature",
    pageCount: 274,
  },
];

// ── CFI helpers ───────────────────────────────────────────────────────────────
// These are realistic-looking EPUB CFI (Canonical Fragment Identifiers)
// used to mark reading positions and annotation locations.

const makeCfi = (chapter: number, paragraph: number, start: number, end: number) =>
  `epubcfi(/6/${chapter * 2}[ch${String(chapter).padStart(2, '0')}]!/4/${paragraph * 2}/1:${start},/1:${end})`;

const makePositionCfi = (chapter: number, paragraph: number, offset: number) =>
  `epubcfi(/6/${chapter * 2}[ch${String(chapter).padStart(2, '0')}]!/4/${paragraph * 2}/1:${offset})`;

// ── Cleanup ───────────────────────────────────────────────────────────────────

async function cleanSeedData(): Promise<void> {
  console.log('🧹 Cleaning previous seed data...');

  // Find all test users first
  const testUsers = await User.find({
    email: { $regex: `${TEST_DOMAIN}$` },
  }).select('_id');

  const testUserIds = testUsers.map((u) => u._id);

  if (testUserIds.length > 0) {
    // Delete all associated data in parallel
    const [books, annotations, bookmarks, progress] = await Promise.all([
      Book.deleteMany({ userId: { $in: testUserIds } }),
      Annotation.deleteMany({ userId: { $in: testUserIds } }),
      Bookmark.deleteMany({ userId: { $in: testUserIds } }),
      Progress.deleteMany({ userId: { $in: testUserIds } }),
      User.deleteMany({ email: { $regex: `${TEST_DOMAIN}$` } }),
    ]);

    console.log(`   ✓ Removed ${testUsers.length} users`);
    console.log(`   ✓ Removed ${books.deletedCount} books`);
    console.log(`   ✓ Removed ${annotations.deletedCount} annotations`);
    console.log(`   ✓ Removed ${bookmarks.deletedCount} bookmarks`);
    console.log(`   ✓ Removed ${progress.deletedCount} progress records`);
  } else {
    console.log('   ✓ No previous seed data found');
  }
}

// ── Helper: create a discovered book ─────────────────────────────────────────

async function createDiscoveredBook(
  userId: mongoose.Types.ObjectId,
  template: BookTemplate,
  overrides: Partial<{
    status: 'uploading' | 'queued' | 'converting' | 'ready' | 'failed';
    isDownloaded: boolean;
  }> = {},
) {
  return Book.create({
    userId,
    title: template.title,
    author: template.author,
    description: template.description,
    coverUrl: template.coverUrl,
    convertedFileUrl: template.epubUrl,
    originalFormat: 'epub' as const,
    fileSize: Math.floor(Math.random() * 2_000_000) + 500_000, // 500KB–2.5MB
    pageCount: template.pageCount,
    status: overrides.status ?? 'ready',
    source: 'discover' as const,
    gutenbergId: template.gutenbergId,
    language: 'en',
    genre: template.genre,
    isDownloaded: overrides.isDownloaded ?? false,
  });
}

// ── Helper: create a fake uploaded book ──────────────────────────────────────

async function createUploadedBook(userId: mongoose.Types.ObjectId, title: string, author: string) {
  const id = uuidv4();
  return Book.create({
    userId,
    title,
    author,
    description: `Uploaded document: ${title}`,
    coverUrl: '',
    originalFileUrl: `https://res.cloudinary.com/fake/raw/upload/v1/readin/originals/${id}.pdf`,
    originalFilePublicId: `readin/originals/${id}`,
    convertedFileUrl: `https://res.cloudinary.com/fake/raw/upload/v1/readin/converted/${id}.epub`,
    convertedFilePublicId: `readin/converted/${id}`,
    originalFormat: 'pdf' as const,
    fileSize: Math.floor(Math.random() * 5_000_000) + 1_000_000, // 1MB–6MB
    pageCount: Math.floor(Math.random() * 300) + 50,
    status: 'ready' as const,
    source: 'upload' as const,
    language: 'en',
  });
}

// ── Seed: Alice (Free — Empty) ────────────────────────────────────────────────
// Perfect for testing: empty library, upload flow, onboarding

async function seedAlice(passwordHash: string) {
  console.log('\n👤 Creating Alice Anderson — Free user, empty library...');

  const alice = await User.create({
    email: 'alice' + TEST_DOMAIN,
    passwordHash,
    displayName: 'Alice Anderson',
    avatar: '',
    plan: 'free' as const,
    isEmailVerified: true,
  });

  console.log('   ✓ User created — no books, annotations, or progress');
  console.log(`   ✓ email: alice${TEST_DOMAIN}`);
  return alice;
}

// ── Seed: Bob (Free — At Limit) ───────────────────────────────────────────────
// Perfect for testing: freemium gates, upgrade prompts, limit banners

async function seedBob(passwordHash: string) {
  console.log('\n👤 Creating Bob Brown — Free user at freemium limits...');

  const bob = await User.create({
    email: 'bob' + TEST_DOMAIN,
    passwordHash,
    displayName: 'Bob Brown',
    avatar: '',
    plan: 'free' as const,
    isEmailVerified: true,
  });

  // ── 10 books (free plan limit) ──────────────────────────────────────────────
  const bobBookTemplates = BOOKS.slice(0, 10);
  const bobBooks = await Promise.all(
    bobBookTemplates.map((template) => createDiscoveredBook(bob._id, template)),
  );

  console.log(`   ✓ Created ${bobBooks.length} books (at free plan limit of 10)`);

  // ── Reading progress on 3 books ────────────────────────────────────────────
  const [book1, book2, book3] = bobBooks;

  if (book1 && book2 && book3) {
    await Promise.all([
      Progress.create({
        userId: bob._id,
        bookId: book1._id,
        currentCfi: makePositionCfi(5, 3, 120),
        percentage: 65,
        currentChapter: 4,
        currentChapterTitle: 'Chapter 5: A Curious Coincidence',
        totalChapters: 24,
        lastReadAt: new Date(Date.now() - 1000 * 60 * 60 * 2), // 2 hours ago
        isCompleted: false,
        readingTimeSeconds: 7200, // 2 hours
      }),
      Progress.create({
        userId: bob._id,
        bookId: book2._id,
        currentCfi: makePositionCfi(12, 8, 45),
        percentage: 100,
        currentChapter: 12,
        currentChapterTitle: "Chapter 12: The Creature's Demand",
        totalChapters: 12,
        lastReadAt: new Date(Date.now() - 1000 * 60 * 60 * 24 * 7), // 1 week ago
        isCompleted: true,
        completedAt: new Date(Date.now() - 1000 * 60 * 60 * 24 * 7),
        readingTimeSeconds: 9800,
      }),
      Progress.create({
        userId: bob._id,
        bookId: book3._id,
        currentCfi: makePositionCfi(3, 2, 80),
        percentage: 30,
        currentChapter: 2,
        currentChapterTitle: 'Adventure III: A Case of Identity',
        totalChapters: 12,
        lastReadAt: new Date(Date.now() - 1000 * 60 * 30), // 30 min ago
        isCompleted: false,
        readingTimeSeconds: 3600,
      }),
    ]);
    console.log('   ✓ Created reading progress (1 completed, 2 in progress)');
  }

  // ── 20 annotations (free plan limit) ───────────────────────────────────────
  // Spread across book1 (Pride and Prejudice) — real quotes

  const pridePrejudiceQuotes = [
    {
      text: 'It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.',
      chapter: 1,
      chapterTitle: 'Chapter 1',
      color: 'yellow' as const,
    },
    {
      text: 'She is tolerable, but not handsome enough to tempt me.',
      chapter: 1,
      chapterTitle: 'Chapter 1',
      color: 'green' as const,
    },
    {
      text: 'I declare after all there is no enjoyment like reading! How much sooner one tires of any thing than of a book!',
      chapter: 11,
      chapterTitle: 'Chapter 11',
      color: 'blue' as const,
    },
    {
      text: 'What are men to rocks and mountains?',
      chapter: 26,
      chapterTitle: 'Chapter 26',
      color: 'yellow' as const,
    },
    {
      text: 'You must allow me to tell you how ardently I admire and love you.',
      chapter: 34,
      chapterTitle: 'Chapter 34',
      color: 'pink' as const,
    },
    {
      text: 'In vain I have struggled. It will not do. My feelings will not be repressed.',
      chapter: 34,
      chapterTitle: 'Chapter 34',
      color: 'pink' as const,
    },
    {
      text: 'Till this moment I never knew myself.',
      chapter: 36,
      chapterTitle: 'Chapter 36',
      color: 'purple' as const,
    },
    {
      text: "A lady's imagination is very rapid; it jumps from admiration to love, from love to matrimony in a moment.",
      chapter: 6,
      chapterTitle: 'Chapter 6',
      color: 'yellow' as const,
    },
    {
      text: 'It is a truth universally acknowledged that a single woman in possession of a good fortune must be in want of nothing.',
      chapter: 1,
      chapterTitle: 'Chapter 1',
      color: 'green' as const,
    },
    {
      text: 'Vanity and pride are different things, though the words are often used synonymously.',
      chapter: 5,
      chapterTitle: 'Chapter 5',
      color: 'blue' as const,
    },
    {
      text: 'We all know him to be a proud, unpleasant sort of man; but this would be nothing if you really liked him.',
      chapter: 3,
      chapterTitle: 'Chapter 3',
      color: 'yellow' as const,
    },
    {
      text: 'Nothing is more deceitful than the appearance of humility. It is often only carelessness of opinion.',
      chapter: 10,
      chapterTitle: 'Chapter 10',
      color: 'purple' as const,
    },
    {
      text: 'My good opinion once lost is lost for ever.',
      chapter: 11,
      chapterTitle: 'Chapter 11',
      color: 'pink' as const,
    },
    {
      text: 'I am the happiest creature in the world. Perhaps other people have said so before, but not one with such justice.',
      chapter: 58,
      chapterTitle: 'Chapter 58',
      color: 'yellow' as const,
    },
    {
      text: 'She was a little less handsome than she had been the last year, but as lively and as pretty as she had been in her bloom.',
      chapter: 45,
      chapterTitle: 'Chapter 45',
      color: 'green' as const,
    },
  ];

  const frankensteinQuotes = [
    {
      text: 'Nothing is so painful to the human mind as a great and sudden change.',
      chapter: 4,
      chapterTitle: 'Chapter 4',
      color: 'purple' as const,
    },
    {
      text: 'I do know that for the sympathy of one living being, I would make peace with all.',
      chapter: 9,
      chapterTitle: 'Chapter 9',
      color: 'blue' as const,
    },
    {
      text: 'Beware; for I am fearless, and therefore powerful.',
      chapter: 20,
      chapterTitle: 'Chapter 20',
      color: 'yellow' as const,
    },
    {
      text: 'How dangerous is the acquirement of knowledge and how much happier that man is who believes his native town to be the world.',
      chapter: 4,
      chapterTitle: 'Chapter 4',
      color: 'green' as const,
    },
    {
      text: 'I, the miserable and the abandoned, am an abortion, to be spurned at, and kicked, and trampled on.',
      chapter: 24,
      chapterTitle: 'Chapter 24',
      color: 'pink' as const,
    },
  ];

  const allQuotes = [
    ...pridePrejudiceQuotes.map((q) => ({ ...q, bookIndex: 0 })),
    ...frankensteinQuotes.map((q) => ({ ...q, bookIndex: 1 })),
  ];

  // Create annotations with notes on some of them
  const notedQuoteIndices = new Set([1, 5, 9, 14, 17]);

  const annotationPromises = allQuotes.map((quote, index) => {
    const targetBook = quote.bookIndex === 0 ? book1 : book2;
    if (!targetBook) return null;

    const hasNote = notedQuoteIndices.has(index);

    return Annotation.create({
      userId: bob._id,
      bookId: targetBook._id,
      type: hasNote ? ('note' as const) : ('highlight' as const),
      cfiRange: makeCfi(quote.chapter, 2, 0, quote.text.length),
      selectedText: quote.text,
      ...(hasNote && {
        note: `My thoughts on this: Really powerful passage that connects to the main theme of ${targetBook.title}.`,
      }),
      color: quote.color,
      chapterTitle: quote.chapterTitle,
      chapterIndex: quote.chapter,
    });
  });

  const created = (await Promise.all(annotationPromises)).filter(Boolean);
  console.log(`   ✓ Created ${created.length} annotations (at free plan limit of 20)`);

  // ── 5 bookmarks spread across books ────────────────────────────────────────
  if (book1 && book2 && book3) {
    await Promise.all([
      Bookmark.create({
        userId: bob._id,
        bookId: book1._id,
        cfi: makePositionCfi(12, 4, 0),
        label: "Darcy's first proposal",
        chapterTitle: 'Chapter 12',
        chapterIndex: 12,
        percentage: 45,
      }),
      Bookmark.create({
        userId: bob._id,
        bookId: book1._id,
        cfi: makePositionCfi(36, 1, 0),
        label: "Elizabeth's realization",
        chapterTitle: 'Chapter 36',
        chapterIndex: 36,
        percentage: 65,
      }),
      Bookmark.create({
        userId: bob._id,
        bookId: book2._id,
        cfi: makePositionCfi(5, 3, 0),
        label: 'The creature speaks',
        chapterTitle: 'Chapter 5',
        chapterIndex: 5,
        percentage: 40,
      }),
      Bookmark.create({
        userId: bob._id,
        bookId: book3._id,
        cfi: makePositionCfi(2, 1, 0),
        label: 'Adventure begins',
        chapterTitle: 'Adventure II',
        chapterIndex: 2,
        percentage: 15,
      }),
      Bookmark.create({
        userId: bob._id,
        bookId: book3._id,
        cfi: makePositionCfi(7, 4, 0),
        label: 'The twist',
        chapterTitle: 'Adventure VII',
        chapterIndex: 7,
        percentage: 58,
      }),
    ]);
    console.log('   ✓ Created 5 bookmarks');
  }

  return bob;
}

// ── Seed: Carol (Premium) ─────────────────────────────────────────────────────
// Perfect for testing: premium features, reading stats, no limits

async function seedCarol(passwordHash: string) {
  console.log('\n👤 Creating Carol Chen — Premium user with full reading history...');

  const carol = await User.create({
    email: 'carol' + TEST_DOMAIN,
    passwordHash,
    displayName: 'Carol Chen',
    avatar: '',
    plan: 'premium' as const,
    isEmailVerified: true,
    expoPushToken: 'ExponentPushToken[fake-token-carol-test-001]',
  });

  // ── Mix of discovered and uploaded books ───────────────────────────────────
  const [warAndPeace, crimeAndPunishment, brothersK, treasureIsland, hound] = await Promise.all([
    createDiscoveredBook(carol._id, BOOKS[10]!), // War and Peace
    createDiscoveredBook(carol._id, BOOKS[11]!), // Crime and Punishment
    createDiscoveredBook(carol._id, BOOKS[12]!), // Brothers Karamazov (missing — no template)
    createDiscoveredBook(carol._id, BOOKS[12]!), // Treasure Island
    createDiscoveredBook(carol._id, BOOKS[13]!), // Hound of Baskervilles
  ]);

  const uploadedBook1 = await createUploadedBook(
    carol._id,
    'The Art of Product Management',
    'Various Authors',
  );
  const uploadedBook2 = await createUploadedBook(
    carol._id,
    'Design Patterns in TypeScript',
    'Research Team',
  );

  console.log('   ✓ Created 7 books (5 discovered, 2 uploaded)');

  // ── Reading progress ────────────────────────────────────────────────────────
  const threeWeeksAgo = new Date(Date.now() - 1000 * 60 * 60 * 24 * 21);
  const yesterday = new Date(Date.now() - 1000 * 60 * 60 * 24);
  const oneHourAgo = new Date(Date.now() - 1000 * 60 * 60);

  await Promise.all([
    // War and Peace — in progress
    Progress.create({
      userId: carol._id,
      bookId: warAndPeace._id,
      currentCfi: makePositionCfi(8, 5, 200),
      percentage: 45,
      currentChapter: 8,
      currentChapterTitle: 'Book II: Well — Chapter 8',
      totalChapters: 18,
      lastReadAt: oneHourAgo,
      isCompleted: false,
      readingTimeSeconds: 36000, // 10 hours
    }),

    // Crime and Punishment — completed 3 weeks ago
    Progress.create({
      userId: carol._id,
      bookId: crimeAndPunishment._id,
      currentCfi: makePositionCfi(14, 1, 0),
      percentage: 100,
      currentChapter: 14,
      currentChapterTitle: 'Epilogue',
      totalChapters: 14,
      lastReadAt: threeWeeksAgo,
      isCompleted: true,
      completedAt: threeWeeksAgo,
      readingTimeSeconds: 54000, // 15 hours
    }),

    // Hound of Baskervilles — just started yesterday
    Progress.create({
      userId: carol._id,
      bookId: hound._id,
      currentCfi: makePositionCfi(2, 1, 0),
      percentage: 12,
      currentChapter: 2,
      currentChapterTitle: 'Chapter 2: The Curse of the Baskervilles',
      totalChapters: 15,
      lastReadAt: yesterday,
      isCompleted: false,
      readingTimeSeconds: 2700, // 45 minutes
    }),

    // Uploaded book 1 — in progress
    Progress.create({
      userId: carol._id,
      bookId: uploadedBook1._id,
      currentCfi: makePositionCfi(4, 3, 0),
      percentage: 68,
      currentChapter: 4,
      currentChapterTitle: 'Chapter 4: Stakeholder Management',
      totalChapters: 7,
      lastReadAt: new Date(Date.now() - 1000 * 60 * 60 * 3),
      isCompleted: false,
      readingTimeSeconds: 14400, // 4 hours
    }),
  ]);

  console.log('   ✓ Created reading progress (1 completed, 3 in progress)');

  // ── Annotations ─────────────────────────────────────────────────────────────
  await Promise.all([
    Annotation.create({
      userId: carol._id,
      bookId: warAndPeace._id,
      type: 'highlight' as const,
      cfiRange: makeCfi(3, 2, 0, 120),
      selectedText: 'The strongest of all warriors are these two — Time and Patience.',
      color: 'yellow' as const,
      chapterTitle: 'Book I: Chapter 3',
      chapterIndex: 3,
    }),
    Annotation.create({
      userId: carol._id,
      bookId: warAndPeace._id,
      type: 'note' as const,
      cfiRange: makeCfi(6, 4, 15, 95),
      selectedText:
        'We can know only that we know nothing. And that is the highest degree of human wisdom.',
      note: "This reminds me of Socrates — the wisdom of knowing one's own ignorance.",
      color: 'purple' as const,
      chapterTitle: 'Book II: Chapter 6',
      chapterIndex: 6,
    }),
    Annotation.create({
      userId: carol._id,
      bookId: crimeAndPunishment._id,
      type: 'highlight' as const,
      cfiRange: makeCfi(1, 3, 0, 88),
      selectedText:
        'Pain and suffering are always inevitable for a large intelligence and a deep heart.',
      color: 'blue' as const,
      chapterTitle: 'Part 1: Chapter 1',
      chapterIndex: 1,
    }),
    Annotation.create({
      userId: carol._id,
      bookId: crimeAndPunishment._id,
      type: 'note' as const,
      cfiRange: makeCfi(5, 6, 0, 74),
      selectedText: 'Taking a new step, uttering a new word, is what people fear most.',
      note: 'This is exactly why innovation is so hard — fear of the unknown.',
      color: 'green' as const,
      chapterTitle: 'Part 2: Chapter 5',
      chapterIndex: 5,
    }),
    Annotation.create({
      userId: carol._id,
      bookId: uploadedBook1._id,
      type: 'highlight' as const,
      cfiRange: makeCfi(2, 1, 40, 130),
      selectedText: 'The best product managers are obsessed with the problem, not the solution.',
      color: 'yellow' as const,
      chapterTitle: 'Chapter 2: Problem Discovery',
      chapterIndex: 2,
    }),
    Annotation.create({
      userId: carol._id,
      bookId: uploadedBook1._id,
      type: 'note' as const,
      cfiRange: makeCfi(3, 5, 0, 95),
      selectedText: "Stakeholders don't care about features. They care about outcomes.",
      note: 'Need to reframe all my roadmap conversations around this principle.',
      color: 'pink' as const,
      chapterTitle: 'Chapter 3: Stakeholder Alignment',
      chapterIndex: 3,
    }),
    Annotation.create({
      userId: carol._id,
      bookId: uploadedBook2._id,
      type: 'highlight' as const,
      cfiRange: makeCfi(1, 2, 0, 80),
      selectedText:
        'Each pattern describes a problem which occurs over and over again in our environment.',
      color: 'blue' as const,
      chapterTitle: 'Introduction',
      chapterIndex: 1,
    }),
    Annotation.create({
      userId: carol._id,
      bookId: uploadedBook2._id,
      type: 'note' as const,
      cfiRange: makeCfi(4, 3, 0, 110),
      selectedText: 'Favor object composition over class inheritance.',
      note: 'This is the core of modern software design. Always ask: can I compose this instead?',
      color: 'purple' as const,
      chapterTitle: 'Chapter 4: Structural Patterns',
      chapterIndex: 4,
    }),
  ]);

  console.log('   ✓ Created 8 annotations with notes');

  // ── Bookmarks ────────────────────────────────────────────────────────────────
  await Promise.all([
    Bookmark.create({
      userId: carol._id,
      bookId: warAndPeace._id,
      cfi: makePositionCfi(8, 5, 0),
      label: 'Battle of Austerlitz begins',
      chapterTitle: 'Book II: Chapter 8',
      chapterIndex: 8,
      percentage: 45,
    }),
    Bookmark.create({
      userId: carol._id,
      bookId: crimeAndPunishment._id,
      cfi: makePositionCfi(7, 2, 0),
      label: 'Confession scene',
      chapterTitle: 'Part 3: Chapter 7',
      chapterIndex: 7,
      percentage: 55,
    }),
    Bookmark.create({
      userId: carol._id,
      bookId: uploadedBook1._id,
      cfi: makePositionCfi(4, 1, 0),
      label: 'Framework for prioritization',
      chapterTitle: 'Chapter 4: Stakeholder Management',
      chapterIndex: 4,
      percentage: 68,
    }),
    Bookmark.create({
      userId: carol._id,
      bookId: uploadedBook2._id,
      cfi: makePositionCfi(6, 1, 0),
      label: 'Observer pattern example',
      chapterTitle: 'Chapter 6: Behavioural Patterns',
      chapterIndex: 6,
      percentage: 82,
    }),
  ]);

  console.log('   ✓ Created 4 bookmarks');
  return carol;
}

// ── Seed: Dave (Google OAuth) ─────────────────────────────────────────────────
// Perfect for testing: OAuth-only user, no password, auto-verified

async function seedDave() {
  console.log('\n👤 Creating Dave Davis — Google OAuth user, no password...');

  const dave = await User.create({
    email: 'dave' + TEST_DOMAIN,
    passwordHash: null,
    googleId: 'google_seed_test_user_dave_readin_001',
    displayName: 'Dave Davis',
    avatar: 'https://lh3.googleusercontent.com/a/default-user=s96-c',
    plan: 'free' as const,
    isEmailVerified: true, // OAuth users are always verified
  });

  // ── 3 books ─────────────────────────────────────────────────────────────────
  const [tomSawyer, treasureIsland, hound] = await Promise.all([
    createDiscoveredBook(dave._id, BOOKS[14]!), // Tom Sawyer
    createDiscoveredBook(dave._id, BOOKS[12]!), // Treasure Island
    createDiscoveredBook(dave._id, BOOKS[13]!), // Hound of Baskervilles
  ]);

  console.log('   ✓ Created 3 books');

  // ── Light reading progress ──────────────────────────────────────────────────
  if (tomSawyer) {
    await Progress.create({
      userId: dave._id,
      bookId: tomSawyer._id,
      currentCfi: makePositionCfi(5, 3, 0),
      percentage: 28,
      currentChapter: 5,
      currentChapterTitle: 'Chapter 5',
      totalChapters: 20,
      lastReadAt: new Date(Date.now() - 1000 * 60 * 60 * 24 * 2), // 2 days ago
      isCompleted: false,
      readingTimeSeconds: 5400, // 1.5 hours
    });
    console.log('   ✓ Created reading progress on Tom Sawyer');
  }

  console.log('   ✓ No password — simulates Google OAuth sign-in');
  return dave;
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('╔══════════════════════════════════════════════════╗');
  console.log('║         ReadIn — Database Seed Script           ║');
  console.log('╚══════════════════════════════════════════════════╝\n');

  await connectDB();

  // Clean previous seed data
  await cleanSeedData();

  // Hash the test password once (expensive operation — do it once, reuse)
  console.log('\n🔐 Hashing test password...');
  const passwordHash = await bcrypt.hash(TEST_PASSWORD, 12);
  console.log('   ✓ Done');

  // Create all users
  const alice = await seedAlice(passwordHash);
  const bob = await seedBob(passwordHash);
  const carol = await seedCarol(passwordHash);
  const dave = await seedDave();

  // ── Summary ─────────────────────────────────────────────────────────────────
  console.log('\n╔══════════════════════════════════════════════════════════════════╗');
  console.log('║                    ✅ Seed Complete                              ║');
  console.log('╠══════════════════════════════════════════════════════════════════╣');
  console.log('║  TEST ACCOUNTS                                                   ║');
  console.log('╠═══════════════╦══════════════════════╦═════════╦═══════════════╣');
  console.log('║ Name          ║ Email                ║ Plan    ║ Notes         ║');
  console.log('╠═══════════════╬══════════════════════╬═════════╬═══════════════╣');
  console.log(`║ Alice Anderson║ alice${TEST_DOMAIN}  ║ free    ║ Empty library ║`);
  console.log(`║ Bob Brown     ║ bob${TEST_DOMAIN}    ║ free    ║ At limits     ║`);
  console.log(`║ Carol Chen    ║ carol${TEST_DOMAIN}  ║ premium ║ Full history  ║`);
  console.log(`║ Dave Davis    ║ dave${TEST_DOMAIN}   ║ free    ║ OAuth only    ║`);
  console.log('╠═══════════════╩══════════════════════╩═════════╩═══════════════╣');
  console.log(`║  Password (Alice, Bob, Carol): ${TEST_PASSWORD}           ║`);
  console.log('║  Dave: No password — Google OAuth user                           ║');
  console.log('╠══════════════════════════════════════════════════════════════════╣');
  console.log('║  WHAT TO TEST WITH EACH ACCOUNT                                  ║');
  console.log('║                                                                   ║');
  console.log('║  Alice  → Empty states, first upload, onboarding flow            ║');
  console.log('║  Bob    → Free limits, upgrade prompts, annotation gate          ║');
  console.log('║  Carol  → Premium features, reading stats, no limits             ║');
  console.log('║  Dave   → Google OAuth flow, no-password user edge cases         ║');
  console.log('╚══════════════════════════════════════════════════════════════════╝\n');

  // IDs for reference
  console.log('📋 MongoDB IDs (for API testing with tools like Postman):');
  console.log(`   Alice:  ${alice._id.toString()}`);
  console.log(`   Bob:    ${bob._id.toString()}`);
  console.log(`   Carol:  ${carol._id.toString()}`);
  console.log(`   Dave:   ${dave._id.toString()}\n`);

  await mongoose.disconnect();
  console.log('✅ Database connection closed. Seed complete.\n');
  process.exit(0);
}

main().catch((err: unknown) => {
  console.error('\n❌ Seed failed:', err);
  process.exit(1);
});
