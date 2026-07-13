module.exports = {
  content: [
    "./html/**/*.{html,js}",
    "./js/**/*.js"
  ],
  theme: {
    extend: {
      colors: {
        bgMain: "#F7F6F2",
        cardBg: "#FFF8E7",
        accentPrimary: "#B2C7A5",
        accentSecondary: "#A8D5BA",
        accentSand: "#EAD7B7",
        accentOlive: "#C7D3A4",
        btnHover: "#7DAA8F",
        textMain: "#2C392A",
        textMuted: "#5F6D59",
      },
      fontFamily: {
        headline: ["Poppins", "sans-serif"],
        body: ["Inter", "sans-serif"],
      },
      boxShadow: {
        'soft': '0 4px 12px rgba(0,0,0,0.06)',
      },
      borderRadius: {
        'xl': '12px',
      }
    },
  },
  plugins: [],
}
