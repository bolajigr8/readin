import React, { useRef, useState, useCallback } from 'react'
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  useWindowDimensions,
  type ViewToken,
  Platform,
} from 'react-native'
import { SafeAreaView } from 'react-native-safe-area-context'
import { useSafeAreaInsets } from 'react-native-safe-area-context'
import { Ionicons } from '@expo/vector-icons'
import { router } from 'expo-router'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { StatusBar } from 'expo-status-bar'
import { THEME } from '@/constants/theme'

// ── Storage key ───────────────────────────────────────────────────────────────

export const ONBOARDING_KEY = '@readin/onboarding_complete'

// ── Slide data ────────────────────────────────────────────────────────────────

type IoniconsName = keyof typeof Ionicons.glyphMap

interface Slide {
  id: string
  icon: IoniconsName
  color: string
  badge: string
  headline: string
  description: string
  caption: string
}

const SLIDES: Slide[] = [
  {
    id: '1',
    icon: 'book',
    color: '#F97316',
    badge: 'Welcome',
    headline: 'Read More,\nRead Better',
    description:
      'Your personal library that fits in your pocket. Upload documents, discover classics, and build a reading habit that lasts.',
    caption: 'The smarter way to read.',
  },
  {
    id: '2',
    icon: 'cloud-upload',
    color: '#FBBF24',
    badge: 'Upload',
    headline: 'Any Format,\nPerfect Reading',
    description:
      'Drop in PDFs, Word docs, and ebooks. ReadIn converts them into a beautiful, optimised reading experience in seconds.',
    caption: 'PDF, EPUB, DOCX, MOBI and more.',
  },
  {
    id: '3',
    icon: 'compass',
    color: '#22C55E',
    badge: 'Discover',
    headline: '10,000+ Books,\nAll Free',
    description:
      'Explore the entire Project Gutenberg library. Every classic ever written — from Jane Austen to Dostoevsky — completely free.',
    caption: 'No subscription needed for classics.',
  },
  {
    id: '4',
    icon: 'create-outline',
    color: '#3B82F6',
    badge: 'Annotate',
    headline: 'Never Lose\na Thought',
    description:
      'Highlight passages, write notes, and bookmark pages. Your annotations sync automatically and stay with you forever.',
    caption: 'Your reading, your way.',
  },
  {
    id: '5',
    icon: 'headset',
    color: '#A855F7',
    badge: 'Listen',
    headline: 'Read With\nYour Ears',
    description:
      'Turn any book into an audiobook with built-in text-to-speech. Perfect for commutes, workouts, and multitasking.',
    caption: 'Available on every book in your library.',
  },
]

// ── Glow decoration ───────────────────────────────────────────────────────────

function GlowBackground({ color }: { color: string }) {
  return (
    <>
      {/* Outer diffuse glow */}
      <View
        style={[
          styles.glowOuter,
          { backgroundColor: color + '08' }, // 3% opacity
        ]}
      />
      {/* Mid glow */}
      <View
        style={[
          styles.glowMid,
          { backgroundColor: color + '12' }, // 7% opacity
        ]}
      />
      {/* Inner concentrated glow */}
      <View
        style={[
          styles.glowInner,
          { backgroundColor: color + '1E' }, // 12% opacity
        ]}
      />
    </>
  )
}

// ── Decorative dots ───────────────────────────────────────────────────────────

function FloatingDots({ color }: { color: string }) {
  const positions = [
    { top: '12%', left: '8%', size: 4 },
    { top: '25%', right: '10%', size: 6 },
    { top: '8%', right: '25%', size: 3 },
    { top: '35%', left: '15%', size: 5 },
    { top: '18%', left: '40%', size: 4 },
  ]

  return (
    <>
      {positions.map((pos, i) => (
        <View
          key={i}
          style={[
            styles.floatingDot,
            {
              top: pos.top as unknown as number,
              left: ('left' in pos ? pos.left : undefined) as
                | number
                | undefined,
              right: ('right' in pos ? pos.right : undefined) as
                | number
                | undefined,
              width: pos.size,
              height: pos.size,
              borderRadius: pos.size / 2,
              backgroundColor: color + '40',
            },
          ]}
        />
      ))}
    </>
  )
}

// ── Single slide ──────────────────────────────────────────────────────────────

function SlideItem({ slide, width }: { slide: Slide; width: number }) {
  return (
    <View style={[styles.slide, { width }]}>
      {/* Hero visual area */}
      <View style={styles.heroArea}>
        {/* Background glow layers */}
        <GlowBackground color={slide.color} />

        {/* Floating decorative dots */}
        <FloatingDots color={slide.color} />

        {/* Icon container */}
        <View
          style={[
            styles.iconWrapper,
            {
              borderColor: slide.color + '30',
              backgroundColor: slide.color + '15',
            },
          ]}
        >
          {/* Inner icon ring */}
          <View
            style={[styles.iconInner, { backgroundColor: slide.color + '25' }]}
          >
            <Ionicons name={slide.icon} size={52} color={slide.color} />
          </View>
        </View>

        {/* Subtle horizontal line accent */}
        <View style={styles.accentLineWrapper}>
          <View
            style={[styles.accentLine, { backgroundColor: slide.color + '30' }]}
          />
          <View
            style={[styles.accentLineDot, { backgroundColor: slide.color }]}
          />
          <View
            style={[styles.accentLine, { backgroundColor: slide.color + '30' }]}
          />
        </View>
      </View>

      {/* Content area */}
      <View style={styles.contentArea}>
        {/* Badge pill */}
        <View
          style={[
            styles.badge,
            {
              backgroundColor: slide.color + '20',
              borderColor: slide.color + '40',
            },
          ]}
        >
          <Text style={[styles.badgeText, { color: slide.color }]}>
            {slide.badge}
          </Text>
        </View>

        {/* Headline */}
        <Text style={styles.headline}>{slide.headline}</Text>

        {/* Description */}
        <Text style={styles.description}>{slide.description}</Text>

        {/* Caption */}
        <Text style={[styles.caption, { color: slide.color }]}>
          ✦ {slide.caption}
        </Text>
      </View>
    </View>
  )
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

function DotIndicator({
  count,
  activeIndex,
  activeColor,
}: {
  count: number
  activeIndex: number
  activeColor: string
}) {
  return (
    <View style={styles.dotsContainer}>
      {Array.from({ length: count }).map((_, i) => (
        <View
          key={i}
          style={[
            styles.dot,
            i === activeIndex
              ? [styles.dotActive, { backgroundColor: activeColor, width: 24 }]
              : styles.dotInactive,
          ]}
        />
      ))}
    </View>
  )
}

// ── Main screen ───────────────────────────────────────────────────────────────

export default function OnboardingScreen() {
  const { width: SCREEN_WIDTH } = useWindowDimensions()
  const insets = useSafeAreaInsets()
  const flatListRef = useRef<FlatList<Slide>>(null)
  const [activeIndex, setActiveIndex] = useState(0)

  const activeSlide = SLIDES[activeIndex] ?? SLIDES[0]!
  const isLastSlide = activeIndex === SLIDES.length - 1

  // ── Track active slide ────────────────────────────────────────────────────

  const viewabilityConfig = useRef({ viewAreaCoveragePercentThreshold: 50 })

  const onViewableItemsChanged = useCallback(
    ({ viewableItems }: { viewableItems: ViewToken[] }) => {
      const first = viewableItems[0]
      if (
        first !== undefined &&
        first.index !== null &&
        first.index !== undefined
      ) {
        setActiveIndex(first.index)
      }
    },
    [],
  )

  // ── Actions ───────────────────────────────────────────────────────────────

  const completeOnboarding = async () => {
    await AsyncStorage.setItem(ONBOARDING_KEY, 'true')
    router.replace('/(auth)/login')
  }

  const goNext = () => {
    if (isLastSlide) {
      completeOnboarding()
      return
    }
    flatListRef.current?.scrollToIndex({
      index: activeIndex + 1,
      animated: true,
    })
  }

  const skip = () => {
    completeOnboarding()
  }

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <View style={styles.container}>
      <StatusBar style='light' />

      {/* Skip button — always top right */}
      <View style={[styles.skipContainer, { paddingTop: insets.top + 8 }]}>
        <TouchableOpacity
          onPress={skip}
          activeOpacity={0.7}
          hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
        >
          <Text style={styles.skipText}>Skip</Text>
        </TouchableOpacity>
      </View>

      {/* Slides */}
      <FlatList
        ref={flatListRef}
        data={SLIDES}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <SlideItem slide={item} width={SCREEN_WIDTH} />
        )}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        bounces={false}
        onViewableItemsChanged={onViewableItemsChanged}
        viewabilityConfig={viewabilityConfig.current}
        getItemLayout={(_, index) => ({
          length: SCREEN_WIDTH,
          offset: SCREEN_WIDTH * index,
          index,
        })}
      />

      {/* Bottom controls */}
      <View
        style={[
          styles.bottomControls,
          { paddingBottom: Math.max(insets.bottom, 24) },
        ]}
      >
        {/* Dot indicator */}
        <DotIndicator
          count={SLIDES.length}
          activeIndex={activeIndex}
          activeColor={activeSlide.color}
        />

        {/* CTA button */}
        <TouchableOpacity
          activeOpacity={0.85}
          onPress={goNext}
          style={[styles.ctaButton, { backgroundColor: activeSlide.color }]}
        >
          <Text style={styles.ctaText}>
            {isLastSlide ? 'Get Started' : 'Continue'}
          </Text>
          <Ionicons
            name={isLastSlide ? 'arrow-forward' : 'arrow-forward'}
            size={18}
            color='#FFFFFF'
            style={{ marginLeft: 8 }}
          />
        </TouchableOpacity>

        {/* Slide counter */}
        <Text style={styles.slideCounter}>
          {activeIndex + 1} of {SLIDES.length}
        </Text>
      </View>
    </View>
  )
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: THEME.colors.background,
  },

  // Skip button
  skipContainer: {
    position: 'absolute',
    top: 0,
    right: 20,
    zIndex: 10,
  },
  skipText: {
    color: THEME.colors.text.secondary,
    fontFamily: 'Inter_500Medium',
    fontSize: 15,
  },

  // Slide
  slide: {
    flex: 1,
  },

  // Hero area (top 55%)
  heroArea: {
    flex: 0.55,
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
    overflow: 'hidden',
  },

  // Glow layers (centered, absolutely positioned)
  glowOuter: {
    position: 'absolute',
    width: 380,
    height: 380,
    borderRadius: 190,
    top: '50%',
    left: '50%',
    marginTop: -190,
    marginLeft: -190,
  },
  glowMid: {
    position: 'absolute',
    width: 260,
    height: 260,
    borderRadius: 130,
    top: '50%',
    left: '50%',
    marginTop: -130,
    marginLeft: -130,
  },
  glowInner: {
    position: 'absolute',
    width: 160,
    height: 160,
    borderRadius: 80,
    top: '50%',
    left: '50%',
    marginTop: -80,
    marginLeft: -80,
  },

  // Floating decorative dots
  floatingDot: {
    position: 'absolute',
  },

  // Icon
  iconWrapper: {
    width: 130,
    height: 130,
    borderRadius: 40,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconInner: {
    width: 108,
    height: 108,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },

  // Accent line below icon
  accentLineWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 28,
    gap: 10,
  },
  accentLine: {
    height: 1,
    width: 60,
  },
  accentLineDot: {
    width: 5,
    height: 5,
    borderRadius: 2.5,
  },

  // Content area (bottom 45%)
  contentArea: {
    flex: 0.45,
    paddingHorizontal: 32,
    paddingTop: 24,
  },

  badge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 20,
    borderWidth: 1,
    marginBottom: 14,
  },
  badgeText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },

  headline: {
    fontFamily: 'Inter_700Bold',
    fontSize: 36,
    lineHeight: 44,
    color: THEME.colors.text.primary,
    marginBottom: 14,
  },

  description: {
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    lineHeight: 24,
    color: THEME.colors.text.secondary,
    marginBottom: 16,
  },

  caption: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    letterSpacing: 0.3,
  },

  // Bottom controls
  bottomControls: {
    paddingHorizontal: 24,
    paddingTop: 12,
    gap: 16,
    backgroundColor: THEME.colors.background,
  },

  dotsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
  },
  dot: {
    height: 4,
    borderRadius: 2,
  },
  dotActive: {
    height: 4,
    borderRadius: 2,
  },
  dotInactive: {
    width: 6,
    height: 4,
    borderRadius: 2,
    backgroundColor: THEME.colors.border.light,
  },

  ctaButton: {
    height: 56,
    borderRadius: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  ctaText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: '#FFFFFF',
  },

  slideCounter: {
    textAlign: 'center',
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: THEME.colors.text.muted,
    marginBottom: 4,
  },
})
