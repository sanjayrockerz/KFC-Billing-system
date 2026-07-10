const fs = require('fs')
const path = require('path')

const filePath = path.join(__dirname, 'src', 'pages', 'Pos.tsx')
let content = fs.readFileSync(filePath, 'utf8')

// Add imports for the Modals
if (!content.includes('import CatalogModal')) {
  content = content.replace(
    "import { Invoice } from '../components/Invoice'",
    "import { Invoice } from '../components/Invoice'\\nimport CatalogModal from '../components/CatalogModal'\\nimport AddProductModal from '../components/AddProductModal'"
  )
}

const targetMarker = '// ══ MAIN POS SCREEN ══════════════════════════════════════════════════'
const markerIndex = content.indexOf(targetMarker)

if (markerIndex === -1) {
  console.error("Marker not found!")
  process.exit(1)
}

const beforeContent = content.substring(0, markerIndex + targetMarker.length)

const newJsx = `
  const [catalogOpen, setCatalogOpen] = useState(false)
  const [addProductOpen, setAddProductOpen] = useState(false)

  // ══ MAIN POS SCREEN ══════════════════════════════════════════════════
  return (
    <div className="flex flex-col h-full bg-[#FAFAFA] print:hidden overflow-y-auto">
      {/* Header */}
      <div className="px-6 pt-6 pb-4 shrink-0 flex items-center justify-between">
        <div>
          <h2 className="text-[22px] font-black text-[#8B2332] flex items-center gap-2">
            <div className="w-1.5 h-6 bg-[#8B2332] rounded-full"></div>
            POS Billing Panel
          </h2>
          <p className="text-[12px] text-gray-500 font-medium ml-3.5 mt-1">Quick Invoice generator & database synced checkout</p>
        </div>
        
        {/* Online/Offline Toggle */}
        <div className="flex bg-white rounded-xl border border-[#EAD7B7]/60 p-1 shadow-sm">
          <button 
            onClick={() => setOrderMode('offline')}
            className={\`px-4 py-1.5 rounded-lg text-[11px] font-black tracking-wider uppercase transition-colors \${orderMode === 'offline' ? 'bg-[#8B2332] text-white' : 'text-[#5F6D59] hover:bg-[#F7F6F2]'}\`}
          >
            Offline
          </button>
          <button 
            onClick={() => setOrderMode('online')}
            className={\`px-4 py-1.5 rounded-lg text-[11px] font-black tracking-wider uppercase transition-colors \${orderMode === 'online' ? 'bg-[#8B2332] text-white' : 'text-[#5F6D59] hover:bg-[#F7F6F2]'}\`}
          >
            Online
          </button>
        </div>
      </div>

      {/* Main Content Split */}
      <div className="flex flex-col lg:flex-row gap-6 px-6 pb-6">
        
        {/* LEFT COLUMN (approx 68%) */}
        <div className="flex-[2.1] flex flex-col gap-6">
          
          {/* Customer Details Card */}
          <div className="bg-white rounded-2xl border border-[#EAD7B7]/40 shadow-sm p-5">
            <h3 className="text-[14px] font-black text-[#2C392A] flex items-center gap-2 mb-4">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="text-[#8B2332]"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
              Customer Details
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-[10px] font-black text-[#5F6D59] tracking-wider uppercase mb-1.5">Customer Name</label>
                <input 
                  type="text" 
                  value={customer.name}
                  onChange={e => setCustomer({...customer, name: e.target.value})}
                  placeholder="Enter name"
                  className="w-full px-4 py-3 bg-white border border-[#EAD7B7]/60 rounded-xl focus:outline-none focus:border-[#8B2332] text-[13px] font-bold text-[#2C392A] placeholder:text-gray-400 placeholder:font-medium"
                />
              </div>
              <div>
                <label className="block text-[10px] font-black text-[#5F6D59] tracking-wider uppercase mb-1.5">Mobile Number (WhatsApp)</label>
                <input 
                  type="text" 
                  value={customer.phone}
                  onChange={e => setCustomer({...customer, phone: e.target.value})}
                  placeholder="Enter 10-digit number"
                  className="w-full px-4 py-3 bg-white border border-[#EAD7B7]/60 rounded-xl focus:outline-none focus:border-[#8B2332] text-[13px] font-bold text-[#2C392A] placeholder:text-gray-400 placeholder:font-medium"
                />
              </div>
            </div>
          </div>

          {/* Order Items Card */}
          <div className="bg-white rounded-2xl border border-[#EAD7B7]/40 shadow-sm flex-1 flex flex-col min-h-[400px]">
            {/* Card Header */}
            <div className="flex flex-wrap items-center justify-between p-5 border-b border-[#EAD7B7]/40">
              <h3 className="text-[14px] font-black text-[#2C392A] flex items-center gap-2">
                <Receipt size={16} className="text-[#8B2332]" />
                Order Items
              </h3>
              <div className="flex items-center gap-2">
                <button 
                  onClick={clearAll}
                  className="px-3 py-1.5 rounded-lg border border-[#EAD7B7]/60 text-[11px] font-black text-[#5F6D59] hover:bg-[#F7F6F2] transition-colors flex items-center gap-1.5"
                >
                  <Trash2 size={12} /> CLEAR ORDER
                </button>
                <button 
                  onClick={() => setCatalogOpen(true)}
                  className="px-3 py-1.5 rounded-lg border border-[#8B2332] text-[#8B2332] text-[11px] font-black hover:bg-[#8B2332]/5 transition-colors flex items-center gap-1.5"
                >
                  <Search size={12} /> SEARCH CATALOG
                </button>
                <button 
                  onClick={() => setAddProductOpen(true)}
                  className="px-3 py-1.5 rounded-lg bg-[#8B2332] text-white text-[11px] font-black hover:bg-[#6b1a25] transition-colors flex items-center gap-1.5"
                >
                  <Plus size={12} /> ADD TO CATALOG
                </button>
                <button 
                  onClick={addManualItem}
                  className="px-3 py-1.5 rounded-lg border border-[#8B2332] text-[#8B2332] text-[11px] font-black hover:bg-[#8B2332]/5 transition-colors flex items-center gap-1.5"
                >
                  + ADD CUSTOM ITEM
                </button>
              </div>
            </div>

            {/* Table Header */}
            <div className="grid grid-cols-[1fr_100px_120px_40px] gap-3 px-5 py-3 border-b border-[#EAD7B7]/20 bg-[#FAFAFA]">
              <span className="text-[10px] font-black text-[#5F6D59] tracking-wider uppercase">Item Name / Description</span>
              <span className="text-[10px] font-black text-[#5F6D59] tracking-wider uppercase text-right">Price (₹)</span>
              <span className="text-[10px] font-black text-[#5F6D59] tracking-wider uppercase text-center">Qty</span>
              <span></span>
            </div>

            {/* Table Body */}
            <div className="flex-1 overflow-y-auto p-3 space-y-2">
              {items.length === 0 && (
                <div className="flex flex-col items-center justify-center h-full text-[#5F6D59]/60">
                  <ShoppingBag size={40} className="mb-3 opacity-20" />
                  <p className="text-[13px] font-bold">No items added yet</p>
                </div>
              )}
              
              {items.map(item => (
                <div key={item.cartItemId} className="grid grid-cols-[1fr_100px_120px_40px] items-center gap-3 p-2 bg-white border border-[#EAD7B7]/30 rounded-xl hover:border-[#8B2332]/30 transition-colors">
                  
                  {/* Item Name */}
                  <div className="min-w-0 flex items-center gap-2">
                    {item.source === 'manual' ? (
                      <input 
                        type="text" 
                        value={item.name} 
                        onChange={e => updateItem(item.id, 'name', e.target.value)}
                        placeholder="Item name"
                        className="w-full px-3 py-2 bg-[#FAFAFA] border border-[#EAD7B7]/40 rounded-lg text-[13px] font-bold text-[#2C392A] focus:outline-none focus:border-[#8B2332]"
                      />
                    ) : (
                      <div className="px-3 py-2 w-full truncate border border-transparent flex items-center gap-2">
                        <span className="text-[13px] font-bold text-[#2C392A] truncate">{item.name} {item.variantName ? \`- \${item.variantName}\` : ''}</span>
                      </div>
                    )}
                    {item.source !== 'manual' && (
                      <span className="hidden sm:inline-flex px-2 py-0.5 rounded border border-[#8B2332]/20 text-[#8B2332] text-[9px] font-black tracking-wider uppercase shrink-0 bg-[#8B2332]/5">
                        CATALOG
                      </span>
                    )}
                  </div>

                  {/* Price */}
                  <div>
                    {item.source === 'manual' ? (
                      <input 
                        type="number" 
                        value={item.basePrice || ''} 
                        onChange={e => updateItem(item.id, 'basePrice', Number(e.target.value) || 0)}
                        placeholder="0"
                        className="w-full px-3 py-2 bg-[#FAFAFA] border border-[#EAD7B7]/40 rounded-lg text-[13px] font-black text-[#2C392A] text-right focus:outline-none focus:border-[#8B2332]"
                      />
                    ) : (
                      <div className="px-3 py-2 text-right">
                        <span className="text-[13px] font-black text-[#2C392A]">{item.basePrice}</span>
                      </div>
                    )}
                  </div>

                  {/* Quantity Controls */}
                  <div className="flex items-center justify-between border border-[#EAD7B7]/60 rounded-lg px-2 py-1 bg-white">
                    <button 
                      onClick={() => bumpQty(item.id, -1)}
                      className="w-6 h-6 rounded-md hover:bg-[#FAFAFA] flex items-center justify-center text-[#5F6D59] font-bold"
                    >-</button>
                    <span className="text-[13px] font-black text-[#2C392A] min-w-[20px] text-center">{item.qty}</span>
                    <button 
                      onClick={() => bumpQty(item.id, 1)}
                      className="w-6 h-6 rounded-md hover:bg-[#FAFAFA] flex items-center justify-center text-[#5F6D59] font-bold"
                    >+</button>
                  </div>

                  {/* Delete */}
                  <button 
                    onClick={() => removeItem(item.id)}
                    className="w-9 h-9 flex items-center justify-center rounded-lg border border-[#EAD7B7]/60 text-[#5F6D59] hover:bg-red-50 hover:text-red-500 hover:border-red-200 transition-colors"
                  >
                    <Trash2 size={14} />
                  </button>

                </div>
              ))}
            </div>
          </div>
        </div>

        {/* RIGHT COLUMN (approx 32%) */}
        <div className="flex-[1] flex flex-col gap-6">
          <div className="bg-[#FAF9F6] rounded-2xl border border-[#EAD7B7]/60 shadow-sm overflow-hidden flex flex-col">
            
            {/* Header */}
            <div className="flex items-center justify-between p-5 border-b border-[#EAD7B7]/60 bg-white">
              <h3 className="text-[14px] font-black text-[#2C392A] flex items-center gap-2">
                <Receipt size={16} className="text-[#8B2332]" />
                Current Order
              </h3>
              <span className={\`px-2 py-1 rounded-full border text-[9px] font-black tracking-wider uppercase flex items-center gap-1.5 \${orderMode === 'offline' ? 'border-red-200 text-red-600 bg-red-50' : 'border-green-200 text-green-600 bg-green-50'}\`}>
                <div className={\`w-1.5 h-1.5 rounded-full \${orderMode === 'offline' ? 'bg-red-500' : 'bg-green-500'}\`}></div>
                {orderMode} (POS)
              </span>
            </div>

            {/* Content body */}
            <div className="p-5 flex flex-col gap-5 bg-white flex-1">
              
              {/* Info Table */}
              <div className="border border-[#EAD7B7]/40 rounded-xl overflow-hidden text-[11px] font-bold">
                <div className="flex justify-between p-3 border-b border-[#EAD7B7]/40 bg-[#FAFAFA]">
                  <span className="text-[#5F6D59] uppercase">Source</span>
                  <span className="text-[#8B2332] border border-[#8B2332]/30 bg-[#8B2332]/5 px-1.5 rounded uppercase">{orderMode.toUpperCase()}</span>
                </div>
                <div className="flex justify-between p-3 border-b border-[#EAD7B7]/40">
                  <span className="text-[#5F6D59] uppercase">Customer</span>
                  <span className="text-[#2C392A]">{customer.name || '-'}</span>
                </div>
                <div className="flex justify-between p-3 border-b border-[#EAD7B7]/40">
                  <span className="text-[#5F6D59] uppercase">Phone</span>
                  <span className="text-[#2C392A]">{customer.phone || '-'}</span>
                </div>
                {items.length > 0 && (
                  <div className="p-3 bg-[#FAFAFA] space-y-1.5 border-b border-[#EAD7B7]/40">
                    {items.map(item => (
                      <div key={item.cartItemId} className="flex justify-between text-[#2C392A]">
                        <span className="truncate pr-2">{item.qty}x {item.name}</span>
                        <span>{formatCurrency(item.lineTotal)}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Coupon Code */}
              <div>
                <label className="block text-[10px] font-black text-[#5F6D59] tracking-wider uppercase mb-1.5">Coupon Code</label>
                <div className="flex gap-2">
                  <input 
                    type="text" 
                    value={couponInput}
                    onChange={e => setCouponInput(e.target.value.toUpperCase())}
                    placeholder="Enter code"
                    disabled={appliedCoupon !== null}
                    className="w-full px-3 py-2.5 bg-white border border-[#EAD7B7]/60 rounded-xl text-[12px] font-bold text-[#2C392A] focus:outline-none focus:border-[#8B2332] uppercase disabled:bg-gray-100"
                  />
                  {appliedCoupon ? (
                    <button 
                      onClick={removeCoupon}
                      className="px-4 py-2.5 bg-red-100 text-red-600 hover:bg-red-200 rounded-xl text-[12px] font-black transition-colors"
                    >
                      Remove
                    </button>
                  ) : (
                    <button 
                      onClick={applyCoupon}
                      disabled={couponLoading || !couponInput.trim()}
                      className="px-4 py-2.5 bg-[#5F6D59] text-white hover:bg-[#2C392A] rounded-xl text-[12px] font-black transition-colors disabled:opacity-50"
                    >
                      Apply
                    </button>
                  )}
                </div>
                {couponError && <p className="text-[10px] font-bold text-red-500 mt-1">{couponError}</p>}
                {appliedCoupon && (
                  <p className="text-[10px] font-bold text-green-600 mt-1">Applied: -{formatCurrency(appliedCoupon.discount)}</p>
                )}
              </div>

              {/* Discount */}
              <div>
                <label className="block text-[10px] font-black text-[#5F6D59] tracking-wider uppercase mb-1.5">Manual Discount</label>
                <div className="flex gap-2">
                  <div className="relative shrink-0">
                    <select 
                      value={manualDiscountType}
                      onChange={e => setManualDiscountType(e.target.value as 'flat'|'percent')}
                      className="appearance-none bg-white border border-[#EAD7B7]/60 rounded-xl pl-3 pr-8 py-2.5 text-[12px] font-black text-[#2C392A] focus:outline-none focus:border-[#8B2332]"
                    >
                      <option value="flat">₹</option>
                      <option value="percent">%</option>
                    </select>
                    <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-[#5F6D59] pointer-events-none" />
                  </div>
                  <input 
                    type="number" 
                    value={manualDiscountValue}
                    onChange={e => setManualDiscountValue(e.target.value)}
                    placeholder="0"
                    className="w-full px-3 py-2.5 bg-white border border-[#EAD7B7]/60 rounded-xl text-[12px] font-black text-[#2C392A] text-right focus:outline-none focus:border-[#8B2332]"
                  />
                </div>
              </div>

              {/* GST Toggle */}
              <div className="flex items-center justify-between py-2 border-b border-[#EAD7B7]/40">
                <span className="text-[12px] font-black text-[#5F6D59]">Enable GST on Bill</span>
                <button 
                  onClick={() => setBillGstEnabled(!billGstEnabled)}
                  className={\`w-10 h-6 rounded-full p-1 transition-colors \${billGstEnabled ? 'bg-[#8B2332]' : 'bg-[#EAD7B7]/60'}\`}
                >
                  <div className={\`w-4 h-4 rounded-full bg-white transition-transform \${billGstEnabled ? 'translate-x-4' : 'translate-x-0'}\`}></div>
                </button>
              </div>

              {/* Summary calculations */}
              <div className="space-y-2 mt-2">
                <div className="flex items-center justify-between">
                  <span className="text-[12px] font-black text-[#5F6D59]">Subtotal ({items.length} items)</span>
                  <span className="text-[13px] font-black text-[#2C392A]">{formatCurrency(subtotal)}</span>
                </div>
                
                {billGstEnabled && totalGst > 0 && (
                  <div className="flex items-center justify-between">
                    <span className="text-[12px] font-black text-[#5F6D59]">GST Amount</span>
                    <span className="text-[13px] font-black text-[#2C392A]">{formatCurrency(totalGst)}</span>
                  </div>
                )}
                
                <div className="flex items-center justify-between">
                  <span className="text-[12px] font-black text-[#5F6D59]">Delivery</span>
                  <input 
                    type="number"
                    value={shipping}
                    onChange={e => setShipping(e.target.value)}
                    className="w-24 px-2 py-1.5 bg-white border border-[#EAD7B7]/60 rounded-lg text-[12px] font-black text-[#2C392A] text-right focus:outline-none focus:border-[#8B2332]"
                  />
                </div>
              </div>

              <div className="h-px bg-[#EAD7B7]/60 my-2"></div>

              {/* Grand Total */}
              <div className="flex items-center justify-between">
                <span className="text-[14px] font-black text-[#2C392A] uppercase tracking-wider">Grand Total</span>
                <span className="text-[24px] font-black text-[#8B2332] tracking-tight">{formatCurrency(total)}</span>
              </div>

              {/* Cash Payment */}
              <div className="mt-2">
                <div className="border border-[#EAD7B7]/60 rounded-xl p-4 bg-white relative">
                  <label className="block text-[10px] font-black text-[#5F6D59] tracking-wider uppercase mb-1.5">Cash Payment</label>
                  <label className="block text-[10px] font-bold text-[#5F6D59] mb-1.5">Amount Received (₹)</label>
                  <input 
                    type="number"
                    value={cashReceived}
                    onChange={e => setCashReceived(e.target.value)}
                    placeholder="0.00"
                    className="w-full px-3 py-2.5 bg-[#FAFAFA] border border-[#EAD7B7]/40 rounded-xl text-[14px] font-black text-[#2C392A] focus:outline-none focus:border-[#8B2332]"
                  />
                  {cashReceivedNum > 0 && (
                    <div className="mt-3 flex justify-between items-center bg-[#F7F6F2] px-3 py-2 rounded-lg border border-[#EAD7B7]/40">
                      <span className="text-[11px] font-bold text-[#5F6D59]">Return Balance:</span>
                      <span className="text-[13px] font-black text-[#2C392A]">{formatCurrency(balanceToReturn)}</span>
                    </div>
                  )}
                </div>
              </div>

              {error && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-red-600 text-[11px] font-bold mt-2">
                  {error}
                </div>
              )}

              {/* Action Buttons */}
              <div className="grid grid-cols-[1fr_1fr] gap-2 mt-2">
                <button 
                  onClick={generateBill}
                  disabled={saving}
                  className="col-span-2 py-3.5 bg-[#4CAF50] hover:bg-[#45a049] text-white rounded-xl text-[13px] font-black uppercase tracking-wider transition-colors disabled:opacity-50"
                >
                  {saving ? 'Processing...' : 'Complete Sale'}
                </button>
                <button className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors">
                  Print Bill
                </button>
                <button className="py-2.5 bg-white border border-[#EAD7B7]/60 text-[#2C392A] rounded-xl text-[11px] font-black uppercase hover:bg-[#FAFAFA] transition-colors">
                  Save Draft
                </button>
              </div>

            </div>
          </div>
        </div>

      </div>

      {catalogOpen && (
        <CatalogModal 
          isOpen={catalogOpen} 
          onClose={() => setCatalogOpen(false)} 
          onAdd={(p) => {
            addItem(p)
            setCatalogOpen(false)
          }} 
        />
      )}

      {addProductOpen && (
        <AddProductModal 
          isOpen={addProductOpen}
          onClose={() => setAddProductOpen(false)}
          onSuccess={() => {}}
        />
      )}
    </div>
  )
}
`

const finalContent = beforeContent + '\\n' + newJsx
fs.writeFileSync(filePath, finalContent, 'utf8')
console.log('Pos.tsx rewritten successfully!')
