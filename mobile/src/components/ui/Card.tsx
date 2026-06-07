import React from 'react'
import { TouchableOpacity, View, type ViewProps } from 'react-native'

interface CardProps extends ViewProps {
  onPress?: () => void
  elevated?: boolean
  noPadding?: boolean
}

export const Card: React.FC<CardProps> = ({
  children,
  onPress,
  elevated = false,
  noPadding = false,
  className = '',
  ...props
}) => {
  const baseClasses = `
    ${elevated ? 'bg-elevated' : 'bg-surface'}
    border border-border rounded-md
    ${noPadding ? '' : 'p-4'}
    ${className}
  `

  if (onPress) {
    return (
      <TouchableOpacity
        activeOpacity={0.8}
        onPress={onPress}
        className={baseClasses}
        {...(props as object)}
      >
        {children}
      </TouchableOpacity>
    )
  }

  return (
    <View className={baseClasses} {...props}>
      {children}
    </View>
  )
}
