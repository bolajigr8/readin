import React, { useState } from 'react'
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  type TextInputProps,
} from 'react-native'
import { Ionicons } from '@expo/vector-icons'
import { THEME } from '@/constants/theme'

interface InputProps extends TextInputProps {
  label?: string
  error?: string
  leftIcon?: keyof typeof Ionicons.glyphMap
  rightIcon?: keyof typeof Ionicons.glyphMap
  onRightIconPress?: () => void
}

export const Input: React.FC<InputProps> = ({
  label,
  error,
  leftIcon,
  rightIcon,
  onRightIconPress,
  secureTextEntry,
  ...props
}) => {
  const [isPasswordVisible, setIsPasswordVisible] = useState(false)
  const isPassword = secureTextEntry

  return (
    <View className='gap-1.5 w-full'>
      {label && (
        <Text className='text-content-secondary text-sm font-sans-medium ml-0.5'>
          {label}
        </Text>
      )}

      <View
        className={`
          flex-row items-center bg-surface border rounded-md px-4 h-14
          ${error ? 'border-error-500' : 'border-border'}
        `}
      >
        {leftIcon && (
          <Ionicons
            name={leftIcon}
            size={18}
            color={THEME.colors.text.muted}
            style={{ marginRight: 10 }}
          />
        )}

        <TextInput
          className='flex-1 text-content-primary text-base font-sans'
          placeholderTextColor={THEME.colors.text.muted}
          secureTextEntry={isPassword && !isPasswordVisible}
          autoCapitalize='none'
          autoCorrect={false}
          {...props}
        />

        {isPassword ? (
          <TouchableOpacity
            onPress={() => setIsPasswordVisible((v) => !v)}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Ionicons
              name={isPasswordVisible ? 'eye-off-outline' : 'eye-outline'}
              size={18}
              color={THEME.colors.text.muted}
            />
          </TouchableOpacity>
        ) : rightIcon ? (
          <TouchableOpacity
            onPress={onRightIconPress}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <Ionicons
              name={rightIcon}
              size={18}
              color={THEME.colors.text.muted}
            />
          </TouchableOpacity>
        ) : null}
      </View>

      {error && (
        <Text className='text-error-500 text-xs font-sans ml-0.5'>{error}</Text>
      )}
    </View>
  )
}
