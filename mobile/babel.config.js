module.exports = function (api) {
  api.cache(true)
  return {
    presets: [
      // jsxImportSource: "nativewind" is all NativeWind v4 needs in Expo.
      // It tells Babel to use NativeWind's JSX transform so className works.
      ['babel-preset-expo', { jsxImportSource: 'nativewind' }],
    ],
    plugins: [
      // Reanimated plugin must be last. With New Architecture + Reanimated v4,
      // this handles worklet transpilation.
      'react-native-reanimated/plugin',
    ],
  }
}
