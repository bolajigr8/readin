export const THEME = {
  colors: {
    background: '#0A0A0A',
    surface: '#141414',
    elevated: '#1E1E1E',

    primary: {
      300: '#FCD34D',
      400: '#FB923C',
      500: '#F97316',
      600: '#EA6C0A',
      700: '#C2570A',
    },

    amber: {
      300: '#FCD34D',
      400: '#FBBF24',
      500: '#F59E0B',
      600: '#D97706',
    },

    text: {
      primary: '#FFFFFF',
      secondary: '#A1A1AA',
      muted: '#52525B',
      inverse: '#0A0A0A',
    },

    border: {
      default: '#2A2A2A',
      light: '#3A3A3A',
    },

    success: {
      400: '#4ADE80',
      500: '#22C55E',
      600: '#16A34A',
    },

    error: {
      400: '#F87171',
      500: '#EF4444',
      600: '#DC2626',
    },

    warning: {
      400: '#FCD34D',
      500: '#F59E0B',
      600: '#D97706',
    },
  },

  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  },

  radius: {
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    full: 9999,
  },

  reader: {
    light: { bg: '#FFFFFF', fg: '#1A1A1A' },
    dark: { bg: '#0A0A0A', fg: '#E4E4E7' },
    sepia: { bg: '#F5E6C8', fg: '#3D2B1F' },
  },
} as const
