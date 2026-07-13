const prisma = require('../prisma/client')

async function listFavorites(req, res) {
  try {
    const favorites = await prisma.favorite.findMany({
      where: { userId: req.user.id },
      include: { product: true },
      orderBy: { productId: 'asc' },
    })

    return res.json(favorites.map((entry) => entry.product))
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch favorites' })
  }
}

async function addFavorite(req, res) {
  try {
    const productId = Number(req.body.productId)

    if (!productId) {
      return res.status(400).json({ message: 'productId is required' })
    }

    await prisma.favorite.upsert({
      where: { userId_productId: { userId: req.user.id, productId } },
      update: {},
      create: { userId: req.user.id, productId },
    })

    return res.status(201).json({ message: 'Added to favorites' })
  } catch (error) {
    return res.status(500).json({ message: 'Failed to add favorite' })
  }
}

async function removeFavorite(req, res) {
  try {
    const productId = Number(req.params.productId)

    await prisma.favorite.delete({
      where: { userId_productId: { userId: req.user.id, productId } },
    })

    return res.json({ message: 'Removed from favorites' })
  } catch (error) {
    return res.status(500).json({ message: 'Failed to remove favorite' })
  }
}

module.exports = {
  listFavorites,
  addFavorite,
  removeFavorite,
}
