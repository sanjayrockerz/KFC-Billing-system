const express = require('express')
const {
  createOrder,
  listMyOrders,
  listAllOrders,
  salesSummary,
} = require('../controllers/orderController')
const { requireAuth, requireAdmin } = require('../middleware/authMiddleware')

const router = express.Router()

router.post('/', requireAuth, createOrder)
router.get('/mine', requireAuth, listMyOrders)
router.get('/admin/all', requireAuth, requireAdmin, listAllOrders)
router.get('/admin/summary', requireAuth, requireAdmin, salesSummary)

module.exports = router
