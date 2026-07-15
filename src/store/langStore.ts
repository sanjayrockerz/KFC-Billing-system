import { create } from 'zustand'

type Lang = 'en' | 'ta'

type LangState = {
  lang: Lang
  setLang: (lang: Lang) => void
  t: (key: string) => string
}

export const useLangStore = create<LangState>((set) => ({
  lang: 'en',
  setLang: (lang) => set({ lang }),
  t: (key) => key,
}))
