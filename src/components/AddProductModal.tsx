import React, { useState, useEffect, useRef } from 'react'
import { X, ChevronDown } from 'lucide-react'
import { useProductStore } from '../store/store'
import { supabase } from '../lib/supabase'

interface AddProductModalProps {
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

export default function AddProductModal({ isOpen, onClose, onSuccess }: AddProductModalProps) {
  const { fetchProducts } = useProductStore()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [categories, setCategories] = useState<string[]>([])
  const [catOpen, setCatOpen] = useState(false)
  const catRef = useRef<HTMLDivElement>(null)
  const [formData, setFormData] = useState({
    name: '',
    category: 'Manual',
    price: '',
    stock: '10'
  })

  useEffect(() => {
    if (!isOpen) return
    setFormData({ name: '', category: 'Manual', price: '', stock: '10' })
    setError('')
    supabase.from('products').select('category').then(({ data }) => {
      const cats = [...new Set((data ?? []).map(r => String(r.category).trim()).filter(Boolean))]
      setCategories(cats.sort())
    })
  }, [isOpen])

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (catRef.current && !catRef.current.contains(e.target as Node)) setCatOpen(false)
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  if (!isOpen) return null

  const filtered = categories.filter(c => c.toLowerCase().includes(formData.category.toLowerCase()))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formData.name.trim()) return setError('Name is required')
    if (!formData.price) return setError('Price is required')
    
    setLoading(true)
    setError('')
    try {
      const { error: dbErr } = await supabase.from('products').insert({
        name: formData.name.trim(),
        category: formData.category.trim(),
        price: Number(formData.price),
        stock: Number(formData.stock),
        is_active: true,
        unit: '1pc',
        base_quantity: 1,
        unit_type: 'unit',
        unit_label: 'pc'
      })
      if (dbErr) throw dbErr
      await fetchProducts(true)
      onSuccess()
      onClose()
    } catch (err) {
      const msg = typeof err === 'object' && err !== null && 'message' in err
        ? String((err as { message: unknown }).message)
        : String(err)
      console.error('addProduct failed:', msg, err)
      setError(msg || 'Failed to add product')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-3xl w-full max-w-md flex flex-col shadow-2xl overflow-hidden border border-[#F0E6C8]/40">
        
        <div className="flex items-center justify-between p-6 border-b border-[#F0E6C8]/40 bg-[#F7F6F2]">
          <h2 className="text-xl font-black text-[#1A1A1A]">Add to Catalog</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-black/5 text-[#6B7280]">
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 flex flex-col gap-4">
          {error && <div className="text-red-500 text-sm font-bold bg-red-50 p-3 rounded-xl">{error}</div>}
          
          <div>
            <label className="block text-[10px] font-black text-[#6B7280] tracking-wider uppercase mb-1.5">Product Name</label>
            <input 
              type="text" 
              value={formData.name}
              onChange={e => setFormData({...formData, name: e.target.value})}
              className="w-full px-4 py-3 bg-[#F7F6F2] border border-[#F0E6C8]/60 rounded-xl focus:outline-none focus:border-[#D4A800] text-[13px] font-bold"
              placeholder="E.g. Premium Shawl"
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="relative" ref={catRef}>
              <label className="block text-[10px] font-black text-[#6B7280] tracking-wider uppercase mb-1.5">Category</label>
              <div className="relative">
                <input 
                  type="text" 
                  value={formData.category}
                  onChange={e => { setFormData({...formData, category: e.target.value}); setCatOpen(true) }}
                  onFocus={() => setCatOpen(true)}
                  className="w-full px-4 py-3 bg-[#F7F6F2] border border-[#F0E6C8]/60 rounded-xl focus:outline-none focus:border-[#D4A800] text-[13px] font-bold pr-8"
                />
                <ChevronDown size={14} className="absolute right-3 top-1/2 -translate-y-1/2 text-[#6B7280] pointer-events-none" />
              </div>
              {catOpen && filtered.length > 0 && (
                <div className="absolute z-50 top-full mt-1 left-0 right-0 bg-white border border-[#F0E6C8] rounded-xl shadow-lg max-h-36 overflow-y-auto">
                  {filtered.map(c => (
                    <button
                      key={c}
                      type="button"
                      onClick={() => { setFormData({...formData, category: c}); setCatOpen(false) }}
                      className="w-full text-left px-4 py-2.5 text-[13px] font-bold text-[#1A1A1A] hover:bg-[#F7F6F2] transition-colors"
                    >
                      {c}
                    </button>
                  ))}
                </div>
              )}
            </div>
            <div>
              <label className="block text-[10px] font-black text-[#6B7280] tracking-wider uppercase mb-1.5">Price (₹)</label>
              <input 
                type="number" 
                value={formData.price}
                onChange={e => setFormData({...formData, price: e.target.value})}
                className="w-full px-4 py-3 bg-[#F7F6F2] border border-[#F0E6C8]/60 rounded-xl focus:outline-none focus:border-[#D4A800] text-[13px] font-bold text-right"
                placeholder="0"
              />
            </div>
          </div>

          <button 
            type="submit"
            disabled={loading}
            className="mt-4 w-full py-3.5 bg-[#D4A800] hover:bg-[#C49600] text-white rounded-xl text-[13px] font-black uppercase tracking-wider transition-colors disabled:opacity-50"
          >
            {loading ? 'Adding...' : 'Save Product'}
          </button>
        </form>
      </div>
    </div>
  )
}
