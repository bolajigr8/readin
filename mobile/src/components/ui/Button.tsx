import React from 'react'
import {
  TouchableOpacity,
  Text,
  ActivityIndicator,
  type TouchableOpacityProps,
  View,
} from 'react-native'

type Variant = 'primary' | 'secondary' | 'outline' | 'ghost'
type Size = 'sm' | 'md' | 'lg'

interface ButtonProps extends TouchableOpacityProps {
  variant?: Variant
  size?: Size
  loading?: boolean
  label: string
  leftIcon?: React.ReactNode
  rightIcon?: React.ReactNode
}

const variantClasses: Record<Variant, string> = {
  primary: 'bg-primary-500 border border-primary-500',
  secondary: 'bg-elevated border border-border',
  outline: 'bg-transparent border border-primary-500',
  ghost: 'bg-transparent border border-transparent',
}

const labelClasses: Record<Variant, string> = {
  primary: 'text-white font-sans-semibold',
  secondary: 'text-content-primary font-sans-semibold',
  outline: 'text-primary-500 font-sans-semibold',
  ghost: 'text-content-secondary font-sans-medium',
}

const sizeClasses: Record<Size, string> = {
  sm: 'px-4 py-2 rounded-sm',
  md: 'px-6 py-3 rounded-md',
  lg: 'px-8 py-4 rounded-md',
}

const labelSizeClasses: Record<Size, string> = {
  sm: 'text-sm',
  md: 'text-base',
  lg: 'text-lg',
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'md',
  loading = false,
  label,
  leftIcon,
  rightIcon,
  disabled,
  className = '',
  ...props
}) => {
  const isDisabled = disabled || loading

  return (
    <TouchableOpacity
      activeOpacity={0.75}
      disabled={isDisabled}
      className={`
        flex-row items-center justify-center gap-2
        ${variantClasses[variant]}
        ${sizeClasses[size]}
        ${isDisabled ? 'opacity-50' : 'opacity-100'}
        ${className}
      `}
      {...props}
    >
      {loading ? (
        <ActivityIndicator
          size='small'
          color={variant === 'primary' ? '#ffffff' : '#F97316'}
        />
      ) : (
        <>
          {leftIcon && (
            <View>
              <Text>{leftIcon}</Text>
            </View>
          )}
          <Text
            className={`${labelClasses[variant]} ${labelSizeClasses[size]}`}
          >
            {label}
          </Text>
          {rightIcon && <View>{rightIcon}</View>}
        </>
      )}
    </TouchableOpacity>
  )
}
