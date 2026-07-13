const express = require('express')
const cors = require('cors')
const dotenv = require('dotenv')

dotenv.config()

const authRoutes = require('./routes/authRoutes')
const productRoutes = require('./routes/productRoutes')
const orderRoutes = require('./routes/orderRoutes')
const prisma = require('./prisma/client')

const app = express()
const PORT = process.env.PORT || 5000

const allowedOrigins = new Set([
  'http://localhost:5173',
  'http://localhost:3000',
  'https://naatu-shop.vercel.app',
])

if (process.env.CLIENT_ORIGIN) {
  process.env.CLIENT_ORIGIN
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
    .forEach((origin) => allowedOrigins.add(origin))
}

const corsOptions = {
  origin(origin, callback) {
    if (!origin) {
      return callback(null, true)
    }
    if (allowedOrigins.has(origin) || origin.endsWith('.vercel.app')) {
      return callback(null, true)
    }
    return callback(new Error('Not allowed by CORS'))
  },
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}

app.use(
  cors(corsOptions),
)
app.use(express.json())

app.get('/api/health', async (req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`
    res.json({ status: 'ok', service: 'Sri Siddha backend', database: 'connected' })
  } catch (error) {
    res.status(503).json({
      status: 'degraded',
      service: 'Sri Siddha backend',
      database: 'disconnected',
      message: 'Database connection is not configured correctly.',
    })
  }
})

app.use('/api/auth', authRoutes)
app.use('/api/products', productRoutes)
app.use('/api/orders', orderRoutes)

app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' })
})

if (process.env.VERCEL !== '1') {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`)
  })
}

process.on('SIGINT', async () => {
  await prisma.$disconnect()
  process.exit(0)
})

module.exports = app
