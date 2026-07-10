import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAdminAuthStore } from '../store/store'
import { BRAND_EN } from '../lib/brand'

export default function AdminLogin() {
  const [id, setId] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const login = useAdminAuthStore((s) => s.login)
  const navigate = useNavigate()

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    if (!id.trim() || !password.trim()) {
      setError('Enter ID and password')
      return
    }
    if (login(id.trim(), password)) {
      navigate('/dashboard', { replace: true })
    } else {
      setError('Invalid ID or password')
    }
  }

  return (
    <div className="min-h-screen bg-bgMain flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-white rounded-3xl shadow-xl border border-[#F0E6C8] p-8">
        <div className="text-center mb-8">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl overflow-hidden bg-white border border-[#F0E6C8] shadow-sm p-1.5">
            <img src="/logo.png" alt="Logo" className="w-full h-full object-contain" />
          </div>
          <h1 className="text-2xl font-black text-[#1A1A1A]">{BRAND_EN}</h1>
          <p className="text-[13px] font-medium text-[#6B7280] mt-1">Admin Panel</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-[11px] font-black uppercase tracking-wider text-[#6B7280] mb-1.5">ID</label>
            <input
              type="text"
              value={id}
              onChange={(e) => setId(e.target.value)}
              placeholder="Enter shop ID"
              className="w-full h-12 px-4 bg-[#FAFAFA] border border-[#F0E6C8]/60 rounded-xl text-[15px] font-bold text-[#1A1A1A] focus:outline-none focus:border-[#D4A800]"
              autoFocus
            />
          </div>
          <div>
            <label className="block text-[11px] font-black uppercase tracking-wider text-[#6B7280] mb-1.5">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter password"
              className="w-full h-12 px-4 bg-[#FAFAFA] border border-[#F0E6C8]/60 rounded-xl text-[15px] font-bold text-[#1A1A1A] focus:outline-none focus:border-[#D4A800]"
            />
          </div>

          {error && (
            <p className="text-[12px] font-bold text-red-500 text-center">{error}</p>
          )}

          <button
            type="submit"
            className="w-full h-12 bg-[#D4A800] hover:bg-[#C49600] text-white rounded-xl text-[14px] font-black uppercase tracking-wider transition-colors"
          >
            Sign In
          </button>
        </form>
      </div>
    </div>
  )
}
