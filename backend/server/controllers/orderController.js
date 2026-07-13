const prisma = require('../prisma/client')

async function createOrder(req, res) {
  try {
    const { items } = req.body

    if (!Array.isArray(items) || !items.length) {
      return res.status(400).json({ message: 'Order items are required' })
    }

    const productIds = items.map((item) => Number(item.productId))
    const products = await prisma.product.findMany({ where: { id: { in: productIds } } })
    const productMap = new Map(products.map((product) => [product.id, product]))

    for (const item of items) {
      const product = productMap.get(Number(item.productId))
      if (!product) {
        return res.status(404).json({ message: `Product ${item.productId} not found` })
      }
      if (product.stock < Number(item.quantity)) {
        return res.status(400).json({ message: `Insufficient stock for ${product.name}` })
      }
    }

    const totalPrice = items.reduce((sum, item) => {
      const product = productMap.get(Number(item.productId))
      return sum + product.price * Number(item.quantity)
    }, 0)

    const order = await prisma.$transaction(async (tx) => {
      const created = await tx.order.create({
        data: {
          userId: req.user.id,
          totalPrice,
          items: {
            create: items.map((item) => ({
              productId: Number(item.productId),
              quantity: Number(item.quantity),
            })),
          },
        },
        include: {
          items: {
            include: {
              product: true,
            },
          },
        },
      })

      for (const item of items) {
        await tx.product.update({
          where: { id: Number(item.productId) },
          data: { stock: { decrement: Number(item.quantity) } },
        })
      }

      return created
    })

    return res.status(201).json(order)
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create order' })
  }
}

async function listMyOrders(req, res) {
  try {
    const orders = await prisma.order.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
      include: {
        items: {
          include: {
            product: true,
          },
        },
      },
    })

    return res.json(orders)
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch orders' })
  }
}

async function listAllOrders(req, res) {
  try {
    const orders = await prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, name: true, email: true } },
        items: {
          include: {
            product: true,
          },
        },
      },
    })

    return res.json(orders)
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch all orders' })
  }
}

async function salesSummary(req, res) {
  try {
    const [productCount, orderCount, revenueAgg] = await Promise.all([
      prisma.product.count(),
      prisma.order.count(),
      prisma.order.aggregate({ _sum: { totalPrice: true } }),
    ])

    return res.json({
      totalProducts: productCount,
      totalOrders: orderCount,
      totalRevenue: revenueAgg._sum.totalPrice || 0,
    })
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch sales summary' })
  }
}

module.exports = {
  createOrder,
  listMyOrders,
  listAllOrders,
  salesSummary,
}
