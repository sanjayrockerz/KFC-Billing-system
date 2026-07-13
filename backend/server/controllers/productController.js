const prisma = require('../prisma/client')

async function listProducts(req, res) {
  try {
    const { q, category } = req.query

    const where = {
      ...(q
        ? {
            OR: [
              { name: { contains: q, mode: 'insensitive' } },
              { benefits: { contains: q, mode: 'insensitive' } },
              { description: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
      ...(category ? { category } : {}),
    }

    const products = await prisma.product.findMany({ where, orderBy: { id: 'asc' } })
    return res.json(products)
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch products' })
  }
}

async function getProduct(req, res) {
  try {
    const id = Number(req.params.id)
    const product = await prisma.product.findUnique({ where: { id } })

    if (!product) {
      return res.status(404).json({ message: 'Product not found' })
    }

    return res.json(product)
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch product details' })
  }
}

async function createProduct(req, res) {
  try {
    const { name, category, price, description, benefits, imageUrl, stock } = req.body

    if (!name || !category || price == null || !description || !benefits || !imageUrl) {
      return res.status(400).json({ message: 'Missing required fields' })
    }

    const product = await prisma.product.create({
      data: {
        name,
        category,
        price: Number(price),
        description,
        benefits,
        imageUrl,
        stock: Number(stock ?? 0),
      },
    })

    return res.status(201).json(product)
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create product' })
  }
}

async function updateProduct(req, res) {
  try {
    const id = Number(req.params.id)
    const { name, category, price, description, benefits, imageUrl, stock } = req.body

    const product = await prisma.product.update({
      where: { id },
      data: {
        ...(name != null ? { name } : {}),
        ...(category != null ? { category } : {}),
        ...(price != null ? { price: Number(price) } : {}),
        ...(description != null ? { description } : {}),
        ...(benefits != null ? { benefits } : {}),
        ...(imageUrl != null ? { imageUrl } : {}),
        ...(stock != null ? { stock: Number(stock) } : {}),
      },
    })

    return res.json(product)
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update product' })
  }
}

async function deleteProduct(req, res) {
  try {
    const id = Number(req.params.id)
    await prisma.product.delete({ where: { id } })
    return res.json({ message: 'Product deleted' })
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete product' })
  }
}

module.exports = {
  listProducts,
  getProduct,
  createProduct,
  updateProduct,
  deleteProduct,
}
