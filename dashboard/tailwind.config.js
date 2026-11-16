/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        navy: {
          950: '#070D19',
          900: '#0B192C',
          800: '#10233F',
          700: '#1A335B',
          600: '#264A7E',
        },
        brand: {
          DEFAULT: '#0F9D8A',
          hover: '#0C8373',
          light: '#DDF7F1',
          subtle: '#E8FAF6',
          dark: '#0A6B5E',
        },
        surface: {
          light: '#FFFFFF',
          dark: '#111827',
          elevated: '#1F2937',
        },
        border: {
          light: '#E2E8F0',
          dark: '#1F2937',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
      boxShadow: {
        'subtle': '0 1px 3px 0 rgba(0, 0, 0, 0.05), 0 1px 2px -1px rgba(0, 0, 0, 0.05)',
        'elevated': '0 4px 6px -1px rgba(0, 0, 0, 0.07), 0 2px 4px -2px rgba(0, 0, 0, 0.07)',
        'premium': '0 10px 15px -3px rgba(16, 35, 63, 0.08), 0 4px 6px -4px rgba(16, 35, 63, 0.04)',
      }
    },
  },
  plugins: [],
}
