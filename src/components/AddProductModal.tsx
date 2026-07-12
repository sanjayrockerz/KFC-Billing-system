import React, { useState, useEffect } from 'react'
import { X, Plus } from 'lucide-react'
import { useProductStore } from '../store/store'
import { supabase } from '../lib/supabase'

interface AddProductModalProps {
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

type CategoryOption = { id: string | number; name_en: string }

export default function AddProductModal({ isOpen, onClose, onSuccess }: AddProductModalProps) {
  const { fetchProducts } = useProductStore()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [categories, setCategories] = useState<CategoryOption[]>([])
  const [newCategory, setNewCategory] = useState('')
  const [addCategoryOpen, setAddCategoryOpen] = useState(false)
  const [addingCategory, setAddingCategory] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    category: '',
    categoryId: null as string | number | null,
    price: '',
    stock: '10'
  })

  useEffect(() => {
    if (!isOpen) return
    setFormData({ name: '', category: '', categoryId: null, price: '', stock: '10' })
    setError('')
    setNewCategory('')
    setAddCategoryOpen(false)
    Promise.all([
      supabase.from('categories').select('id, name_en').eq('is_active', true).order('sort_order'),
    ]).then(([categoryResult]) => {
      setCategories((categoryResult.data ?? []) as CategoryOption[])
    })
  }, [isOpen])

  if (!isOpen) return null

  const addCategory = async () => {
    const name = newCategory.trim()
    if (!name) return
    setAddingCategory(true)
    const { data, error: categoryError } = await supabase.from('categories')
      .insert({ name_en: name, name_ta: '', is_active: true })
      .select('id, name_en')
      .single()
    if (categoryError) setError(categoryError.message)
    else {
      const categoryName = String(data?.name_en || name)
      const categoryId = data?.id ?? null
      if (categoryId == null) {
        setError('Category was created without an id')
      } else {
        setCategories(prev => [...prev, { id: categoryId, name_en: categoryName }].sort((a, b) => a.name_en.localeCompare(b.name_en)))
        setFormData(prev => ({ ...prev, category: categoryName, categoryId }))
      }
      setNewCategory('')
      setAddCategoryOpen(false)
    }
    setAddingCategory(false)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formData.name.trim()) return setError('Name is required')
    if (!formData.category.trim()) return setError('Please select a category')
    if (!formData.price) return setError('Price is required')
    
    setLoading(true)
    setError('')
    try {
      const { error: dbErr } = await supabase.from('products').insert({
        name: formData.name.trim(),
        category: formData.category.trim(),
        category_id: formData.categoryId,
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

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="block text-[10px] font-black text-[#6B7280] tracking-wider uppercase mb-1.5">Category</label>
              <div className="flex gap-2">
                <select value={formData.category} onChange={e => {
                  const selected = categories.find(category => category.name_en === e.target.value)
                  setFormData({...formData, category: e.target.value, categoryId: selected?.id ?? null})
                }}
                  className="h-12 min-w-0 flex-1 px-4 bg-[#F7F6F2] border border-[#F0E6C8]/60 rounded-xl focus:outline-none focus:border-[#D4A800] text-[13px] font-bold">
                  <option value="">Select category</option>
                  {categories.map(c => <option key={c.id} value={c.name_en}>{c.name_en}</option>)}
                </select>
                <button type="button" onClick={() => setAddCategoryOpen(v => !v)} title="Add category"
                  className="flex h-[46px] w-[34px] shrink-0 items-center justify-center rounded-xl border border-[#F0E6C8] bg-[#FFFDF5] text-[#9B2335] hover:bg-[#F0E6C8]/40">
                  <Plus size={14} />
                </button>
              </div>
              {addCategoryOpen && (
                <div className="mt-2 flex gap-2">
                  <input autoFocus value={newCategory} onChange={e => setNewCategory(e.target.value)} placeholder="New category name"
                    onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); void addCategory() } }}
                    className="min-w-0 flex-1 rounded-xl border border-[#F0E6C8]/60 bg-white px-3 py-2.5 text-[12px] font-semibold outline-none focus:border-[#D4A800]" />
                  <button type="button" disabled={addingCategory || !newCategory.trim()} onClick={() => void addCategory()}
                    className="rounded-xl bg-[#9B2335] px-3 text-[11px] font-black text-white disabled:opacity-50">{addingCategory ? '...' : 'Add'}</button>
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
