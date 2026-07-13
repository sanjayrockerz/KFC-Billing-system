const express = require('express')
const {
  listProducts,
  getProduct,
  createProduct,
  updateProduct,
  deleteProduct,
} = require('../controllers/productController')
const {
  listFavorites,
  addFavorite,
  removeFavorite,
} = require('../controllers/favoriteController')
const { requireAuth, requireAdmin } = require('../middleware/authMiddleware')

const router = express.Router()

router.get('/user/favorites/list', requireAuth, listFavorites)
router.post('/user/favorites', requireAuth, addFavorite)
router.delete('/user/favorites/:productId', requireAuth, removeFavorite)

router.get('/', listProducts)
router.get('/:id', getProduct)

router.post('/', requireAuth, requireAdmin, createProduct)
router.put('/:id', requireAuth, requireAdmin, updateProduct)
router.delete('/:id', requireAuth, requireAdmin, deleteProduct)

module.exports = router
