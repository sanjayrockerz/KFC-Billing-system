const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'src', 'pages', 'Pos.tsx');
let content = fs.readFileSync(filePath, 'utf8');

const searchTarget = `        orderMode,
  const cashReceivedNum = Number(cashReceived) || 0`;

const replacement = `        orderType: getOrderType(),
        deliveryCharge: Number(shipping || 0),
        discountAmount: couponDiscount,
        manualDiscountAmount,
        manualDiscountType,
        manualDiscountValue: manualDiscountNumeric,
        couponCode: appliedCoupon?.code,
        couponPercentage: appliedCoupon?.percentage,
      })
      setInvoice({
        id: created.orderId,
        invoiceNo: created.invoiceNo,
        orderType: getOrderType(),
        date: created.createdAt,
        items: [...items],
        subtotal,
        shipping: Number(shipping || 0),
        couponCode: appliedCoupon?.code,
        couponDiscount,
        manualDiscountAmount,
        manualDiscountType,
        manualDiscountValue: manualDiscountNumeric,
        total,
        customerName: customer.name.trim() || 'Walk-in Customer',
        phone: normalizedPhone,
        address: customer.address.trim() || 'POS Counter',
        amountReceived: Number(cashReceived) || 0,
        balanceReturned: (Number(cashReceived) || 0) > 0 && (Number(cashReceived) || 0) >= total ? (Number(cashReceived) || 0) - total : 0,
      })
      setItems([])
      setCustomer({ name: '', phone: '', address: '' })
      void fetchProducts()
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      setError(\`Checkout Error: \${msg}\`)
    } finally {
      setSaving(false)
    }
  }

  const cashReceivedNum = Number(cashReceived) || 0`;

content = content.replace(searchTarget, replacement);

const whatsappSearch = `  const sendPosWhatsApp = (inv: InvoiceSnap) => {
    const waLink = BRAND_WHATSAPP_LINK
    const text = encodeURIComponent(
      \`*\${BRAND_EN}*\\n\` +
      \`Thank you for shopping with us! 🛍️\\n\\n\` +
      \`Total Due: \${formatCurrency(inv.total)}\\n\` +
      \`View and download your detailed digital receipt here:\\n\` +
      \`https://www.tirupathibalajinattumarunthu.com/invoice/\${inv.invoiceNo}\`
    )
    window.open(\`\${waLink}?text=\${text}\`, '_blank')
  }`;

const whatsappReplacement = `  const sendPosWhatsApp = (inv: InvoiceSnap) => {
    const phone = inv.phone || customer.phone || ''
    const cleanPhone = phone.replace(/[^0-9]/g, '')
    // Ensure we have a valid country code for wa.me if it's 10 digits
    const formattedPhone = cleanPhone.length === 10 ? \`91\${cleanPhone}\` : cleanPhone
    
    const waLink = formattedPhone ? \`https://wa.me/\${formattedPhone}\` : BRAND_WHATSAPP_LINK
    const text = encodeURIComponent(
      \`*\${BRAND_EN}*\\n\` +
      \`Kurinji Nagar, Brindhavan Circle, Kuniyamuthur\\n\\n\` +
      \`Hello \${inv.customerName || 'Customer'},\\n\` +
      \`Thank you for shopping with us! 🛍️\\n\\n\` +
      \`Total Due: \${formatCurrency(inv.total)}\\n\` +
      \`View and download your detailed digital receipt here:\\n\` +
      \`https://www.tirupathibalajinattumarunthu.com/invoice/\${inv.invoiceNo}\`
    )
    window.open(\`\${waLink}?text=\${text}\`, '_blank')
  }`;

content = content.replace(whatsappSearch, whatsappReplacement);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Pos.tsx surgically fixed!');
