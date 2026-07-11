import React, { useState, useMemo, useEffect } from 'react'
import { X, Search, ShoppingBag, Edit2, Trash2 } from 'lucide-react'
import { useProductStore, type Product } from '../store/store'
import { supabase } from '../lib/supabase'

interface CatalogModalProps {
  isOpen: boolean
  onClose: () => void
  onAdd: (product: Product) => void
}

export default function CatalogModal({ isOpen, onClose, onAdd }: CatalogModalProps) {
  const { fetchProducts, products, error } = useProductStore()
  const [search, setSearch] = useState('')
  const [activeCategory, setActiveCategory] = useState('All')
  const [editingProduct, setEditingProduct] = useState<Product | null>(null)
  const [editForm, setEditForm] = useState({ name: '', category: '', price: '' })
  const [editLoading, setEditLoading] = useState(false)
  const [editError, setEditError] = useState('')
  const [categoryRows, setCategoryRows] = useState<{ id: string | number; name_en: string; is_active?: boolean }[]>([])
  const [newCategory, setNewCategory] = useState('')
  const [addingCategory, setAddingCategory] = useState(false)

  const categories = useMemo(() => {
    const productCats = products.filter(p => p.isActive).map(p => p.category)
    const managedCats = categoryRows.filter(c => c.is_active !== false).map(c => c.name_en)
    const cats = Array.from(new Set([...managedCats, ...productCats])).filter(Boolean)
    return ['All', ...cats]
  }, [products, categoryRows])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    let src = products.filter(p => p.isActive)
    if (activeCategory !== 'All') src = src.filter(p => p.category === activeCategory)
    if (q) src = src.filter(p =>
      p.name.toLowerCase().includes(q) ||
      (p.nameTa || '').toLowerCase().includes(q) ||
      p.category.toLowerCase().includes(q)
    )
    return src.slice(0, 120)
  }, [products, search, activeCategory])

  const startEdit = (p: Product) => {
    setEditingProduct(p)
    setEditForm({ name: p.name, category: p.category, price: String(p.price) })
    setEditError('')
  }

  const cancelEdit = () => {
    setEditingProduct(null)
    setEditError('')
  }

  const saveEdit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingProduct) return
    if (!editForm.name.trim()) { setEditError('Name is required'); return }
    if (!editForm.price) { setEditError('Price is required'); return }
    setEditLoading(true)
    setEditError('')
    const { error } = await supabase.from('products').update({
      name: editForm.name.trim(),
      category: editForm.category.trim(),
      price: Number(editForm.price),
    }).eq('id', editingProduct.id)
    if (error) { setEditError(error.message); setEditLoading(false); return }
    await fetchProducts(true)
    setEditLoading(false)
    cancelEdit()
  }

  const handleDelete = async (p: Product) => {
    if (!window.confirm(`Delete "${p.name}"? This will deactivate it.`)) return
    await supabase.from('products').update({ is_active: false }).eq('id', p.id)
    await fetchProducts(true)
  }

  const addCategory = async () => {
    const name = newCategory.trim()
    if (!name) return
    setAddingCategory(true)
    const { data, error: categoryError } = await supabase.from('categories')
      .insert({ name_en: name, name_ta: '', is_active: true })
      .select('id, name_en, is_active')
      .single()
    if (categoryError) setEditError(categoryError.message)
    else if (data) {
      setCategoryRows(prev => [...prev, data])
      setEditForm(prev => ({ ...prev, category: data.name_en }))
      setNewCategory('')
    }
    setAddingCategory(false)
  }

  const deleteCategory = async (category: { id: string | number; name_en: string }) => {
    if (!window.confirm(`Delete category "${category.name_en}"?`)) return
    setEditError('')
    const { error: categoryError } = await supabase.from('categories').delete().eq('id', category.id)
    if (categoryError) {
      setEditError(categoryError.message)
      return
    }
    setCategoryRows(prev => prev.filter(row => row.id !== category.id))
    if (editForm.category === category.name_en) {
      setEditForm(prev => ({ ...prev, category: '' }))
    }
  }

  useEffect(() => {
    if (!isOpen) return
    void fetchProducts()
    void supabase.from('categories').select('id, name_en, is_active').order('sort_order').then(({ data }) => {
      setCategoryRows((data || []) as { id: string | number; name_en: string; is_active?: boolean }[])
    })
  }, [isOpen, fetchProducts])

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-3xl w-full max-w-4xl flex flex-col shadow-2xl overflow-hidden border border-[#F0E6C8]/40 max-h-[85vh]">

        {editingProduct ? (
          <>
            <div className="flex items-center justify-between p-6 border-b border-[#F0E6C8]/40 bg-[#F7F6F2]">
              <h2 className="text-xl font-black text-[#1A1A1A]">Edit Product</h2>
              <button onClick={cancelEdit} className="p-2 rounded-xl hover:bg-black/5 text-[#6B7280]">
                <X size={20} />
              </button>
            </div>
            <form onSubmit={saveEdit} className="p-6 flex flex-col gap-4">
              {editError && <div className="text-red-500 text-sm font-bold bg-red-50 p-3 rounded-xl">{editError}</div>}
              <div>
                <label className="block text-[10px] font-black text-[#6B7280] tracking-wider uppercase mb-1.5">Product Name</label>
                <input type="text" value={editForm.name}
                  onChange={e => setEditForm({...editForm, name: e.target.value})}
                  className="w-full px-4 py-3 bg-[#F7F6F2] border border-[#F0E6C8]/60 rounded-xl focus:outline-none focus:border-[#D4A800] text-[13px] font-bold" />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[10px] font-black text-[#6B7280] tracking-wider uppercase mb-1.5">Category</label>
                  <div className="flex gap-2">
                    <select required value={editForm.category} onChange={e => setEditForm({...editForm, category: e.target.value})}
                      className="min-w-0 flex-1 px-4 py-3 bg-[#F7F6F2] border border-[#F0E6C8]/60 rounded-xl focus:outline-none focus:border-[#D4A800] text-[13px] font-bold">
                      <option value="">Select category...</option>
                      {categories.filter(c => c !== 'All').map(category => <option key={category} value={category}>{category}</option>)}
                    </select>
                  </div>
                  <div className="mt-2 flex gap-2">
                    <input value={newCategory} onChange={e => setNewCategory(e.target.value)} placeholder="New category name"
                      onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); void addCategory() } }}
                      className="min-w-0 flex-1 rounded-xl border border-[#F0E6C8]/60 bg-white px-3 py-2 text-[12px] font-semibold outline-none focus:border-[#D4A800]" />
                    <button type="button" disabled={addingCategory || !newCategory.trim()} onClick={() => void addCategory()}
                      className="rounded-xl bg-[#1A1A1A] px-3 py-2 text-[11px] font-black text-white disabled:opacity-50">{addingCategory ? 'Adding…' : 'Add'}</button>
                  </div>
                  {categoryRows.filter(category => category.is_active !== false).length > 0 && (
                    <div className="mt-3 rounded-xl border border-[#F0E6C8]/50 bg-white p-3">
                      <p className="mb-2 text-[10px] font-black uppercase tracking-wider text-[#6B7280]">Manage categories</p>
                      <div className="space-y-1.5">
                        {categoryRows.filter(category => category.is_active !== false).map(category => (
                          <div key={category.id} className="flex items-center justify-between gap-2 rounded-lg bg-[#F7F6F2] px-3 py-2">
                            <span className="truncate text-[12px] font-bold text-[#1A1A1A]">{category.name_en}</span>
                            <button type="button" onClick={() => void deleteCategory(category)} title={`Delete ${category.name_en}`} aria-label={`Delete ${category.name_en}`}
                              className="shrink-0 rounded-lg p-1.5 text-red-400 transition-colors hover:bg-red-50 hover:text-red-600">
                              <Trash2 size={14} />
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
                <div>
                  <label className="block text-[10px] font-black text-[#6B7280] tracking-wider uppercase mb-1.5">Price (₹)</label>
                  <input type="number" value={editForm.price}
                    onChange={e => setEditForm({...editForm, price: e.target.value})}
                    className="w-full px-4 py-3 bg-[#F7F6F2] border border-[#F0E6C8]/60 rounded-xl focus:outline-none focus:border-[#D4A800] text-[13px] font-bold text-right" placeholder="0" />
                </div>
              </div>
              <button type="submit" disabled={editLoading}
                className="mt-4 w-full py-3.5 bg-[#D4A800] hover:bg-[#C49600] text-white rounded-xl text-[13px] font-black uppercase tracking-wider transition-colors disabled:opacity-50">
                {editLoading ? 'Saving...' : 'Save Changes'}
              </button>
            </form>
          </>
        ) : (
          <>
            <div className="flex items-center justify-between p-5 border-b border-[#F0E6C8]/40 bg-[#F7F6F2]">
              <h2 className="text-[18px] font-black text-[#1A1A1A] flex items-center gap-2">
                <Search size={18} className="text-[#D4A800]" />
                Search Catalog
              </h2>
              <button onClick={onClose} className="p-2 rounded-xl hover:bg-black/5 text-[#6B7280]">
                <X size={20} />
              </button>
            </div>
            <div className="p-4 border-b border-[#F0E6C8]/40 bg-white space-y-3">
              <div className="relative">
                <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#6B7280]" />
                <input type="text" value={search}
                  onChange={e => setSearch(e.target.value)}
                  placeholder="Search by product name, Tamil name, or category..."
                  className="w-full pl-10 pr-4 py-3 bg-[#FAFAFA] border border-[#F0E6C8]/60 rounded-xl focus:outline-none focus:border-[#D4A800] text-[13px] font-bold text-[#1A1A1A]" />
              </div>
              <div className="flex gap-2 overflow-x-auto pb-1 no-scrollbar">
                {categories.map(cat => (
                  <button key={cat} onClick={() => setActiveCategory(cat)}
                    className={`px-4 py-2 rounded-xl text-[11px] font-black uppercase tracking-wider whitespace-nowrap transition-colors ${activeCategory === cat ? 'bg-[#D4A800] text-white' : 'bg-[#FAFAFA] text-[#6B7280] hover:bg-[#F7F6F2] border border-[#F0E6C8]/60'}`}>
                    {cat}
                  </button>
                ))}
              </div>
            </div>
              <div className="flex-1 overflow-y-auto p-3 md:p-4 bg-[#FAFAFA]">
                {error && (
                  <div className="mb-3 p-3 rounded-xl bg-red-50 border border-red-200 text-red-600 text-[11px] font-bold">
                    {error}
                  </div>
                )}
                {filtered.length === 0 ? (
                  <div className="flex flex-col items-center justify-center h-full text-[#6B7280]/60 py-12">
                    <ShoppingBag size={48} className="mb-4 opacity-20" />
                    <p className="text-[14px] font-bold">No products found</p>
                  </div>
                ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2 md:gap-3">
                  {filtered.map(product => (
                    <div key={product.id}
                      className="bg-white border border-[#F0E6C8]/60 rounded-2xl p-3 flex flex-col gap-2 hover:border-[#D4A800]/40 hover:shadow-md transition-all group relative">
                      <div className="absolute top-2 right-2 flex gap-1 z-10">
                        <button onClick={(e) => { e.stopPropagation(); startEdit(product) }} title="Edit product"
                          className="p-2 rounded-lg bg-white border border-[#F0E6C8]/60 text-[#6B7280] hover:text-[#D4A800] hover:border-[#D4A800]/40 shadow-sm transition-colors">
                          <Edit2 size={16} />
                        </button>
                        <button onClick={(e) => { e.stopPropagation(); void handleDelete(product) }} title="Delete product"
                          className="p-2 rounded-lg bg-white border border-[#F0E6C8]/60 text-red-400 hover:text-red-600 hover:border-red-300 shadow-sm transition-colors">
                          <Trash2 size={16} />
                        </button>
                      </div>
                      <div onClick={() => onAdd(product)} className="cursor-pointer flex-1">
                        <h4 className="text-[13px] font-black text-[#1A1A1A] leading-tight group-hover:text-[#D4A800] transition-colors">{product.name}</h4>
                        {product.nameTa && <p className="text-[10px] font-bold text-[#6B7280] mt-0.5">{product.nameTa}</p>}
                      </div>
                      <div onClick={() => onAdd(product)} className="cursor-pointer">
                        <div className="flex items-end justify-between mt-2 pt-2 border-t border-[#F0E6C8]/30">
                          <span className="text-[14px] font-black text-[#1A1A1A]">₹{product.price}</span>
                          <span className="text-[9px] font-black text-[#6B7280] uppercase tracking-wider bg-[#F7F6F2] px-2 py-1 rounded border border-[#F0E6C8]/40">{product.category}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}

      </div>
    </div>
  )
}
