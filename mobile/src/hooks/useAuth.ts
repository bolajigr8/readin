import { useAuthStore } from '@/store/authStore'

export const useAuth = () => {
  const user = useAuthStore((s) => s.user)
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated)
  const isLoading = useAuthStore((s) => s.isLoading)
  const isHydrated = useAuthStore((s) => s.isHydrated)
  const login = useAuthStore((s) => s.login)
  const logout = useAuthStore((s) => s.logout)
  const setUser = useAuthStore((s) => s.setUser)

  return {
    user,
    isAuthenticated,
    isLoading,
    isHydrated,
    login,
    logout,
    setUser,
  }
}
