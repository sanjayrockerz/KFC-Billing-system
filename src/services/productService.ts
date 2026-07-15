import { supabase } from '../lib/supabase'

export function fetchAllProducts() {
  return supabase
    .from('products')
    .select('*')
    .order('sort_order', { ascending: true })
    .order('name', { ascending: true })
}

export function fetchAllCategories() {
  return supabase
    .from('categories')
    .select('id,name_en,name_ta,is_active,sort_order')
    .order('sort_order', { ascending: true })
    .order('name_en', { ascending: true })
}
