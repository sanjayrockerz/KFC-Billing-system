/**
 * Cart Module
 * Handled via localStorage for mock persistence across pages
 */

class CartManager {
    constructor() {
        this.items = JSON.parse(localStorage.getItem('sri_siddha_cart')) || [];
        this.init();
    }

    init() {
        document.addEventListener('DOMContentLoaded', () => {
            this.updateTotalCountUI();
            if (document.getElementById('cart-items-container')) {
                this.renderCartPage();
            }
        });
    }

    add(id, name, price, image) {
        const existing = this.items.find(i => i.id === id);
        if (existing) {
            existing.qty += 1;
        } else {
            this.items.push({ id, name, price, image, qty: 1 });
        }
        this.save();
        this.showToast(`${name} added to cart!`);
    }

    remove(id) {
        this.items = this.items.filter(i => i.id !== id);
        this.save();
        this.renderCartPage();
    }

    updateQty(id, newQty) {
        if (newQty < 1) return this.remove(id);
        const item = this.items.find(i => i.id === id);
        if (item) item.qty = newQty;
        this.save();
        this.renderCartPage();
    }

    save() {
        localStorage.setItem('sri_siddha_cart', JSON.stringify(this.items));
        this.updateTotalCountUI();
    }

    updateTotalCountUI() {
        const counters = document.querySelectorAll('#cart-count');
        const count = this.items.reduce((sum, i) => sum + i.qty, 0);
        counters.forEach(c => {
            c.textContent = count;
            c.classList.add('animate-bounce');
            setTimeout(() => c.classList.remove('animate-bounce'), 500);
        });
    }

    showToast(message) {
        const toast = document.createElement('div');
        toast.className = 'fixed bottom-20 md:bottom-10 left-1/2 -translate-x-1/2 bg-[#00a651] text-white px-6 py-3 rounded-full shadow-2xl font-bold text-sm z-[100] animate-fade-in-up';
        toast.textContent = message;
        document.body.appendChild(toast);
        setTimeout(() => toast.remove(), 3000);
    }

    renderCartPage() {
        const container = document.getElementById('cart-items-container');
        const summary = document.getElementById('cart-summary-total');
        if (!container) return;

        if (this.items.length === 0) {
            container.innerHTML = `
                <div class="text-center py-16">
                    <span class="material-symbols-outlined text-6xl text-gray-300 mb-4">production_quantity_limits</span>
                    <h3 class="text-xl font-bold mb-2">Your cart is empty</h3>
                    <p class="text-textMuted mb-6">Looks like you haven't added anything yet.</p>
                    <a href="products.html" class="bg-accentPrimary hover:bg-[#8ba97f] text-white px-6 py-3 rounded-lg font-bold">Start Shopping</a>
                </div>
            `;
            if (summary) summary.innerHTML = '₹ 0.00';
            return;
        }

        let html = '';
        let total = 0;

        this.items.forEach(item => {
            const itemTotal = item.price * item.qty;
            total += itemTotal;
            html += `
                <div class="flex flex-col sm:flex-row items-center gap-4 border-b border-gray-100 py-6">
                    <img src="${item.image}" alt="${item.name}" class="w-24 h-24 object-contain bg-gray-50 rounded-lg p-2 shrink-0">
                    <div class="flex-grow">
                        <h4 class="font-bold text-textMain">${item.name}</h4>
                        <p class="text-sm font-bold text-gray-500 mt-1">₹${item.price} / each</p>
                    </div>
                    <div class="flex items-center gap-3">
                        <div class="flex items-center border border-gray-200 rounded-lg bg-white">
                            <button onclick="window.cartSys.updateQty(${item.id}, ${item.qty - 1})" class="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-black hover:bg-gray-100 rounded-l-lg">-</button>
                            <span class="w-10 text-center font-bold text-sm">${item.qty}</span>
                            <button onclick="window.cartSys.updateQty(${item.id}, ${item.qty + 1})" class="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-black hover:bg-gray-100 rounded-r-lg">+</button>
                        </div>
                        <div class="w-24 text-right">
                            <span class="font-bold text-lg">₹${itemTotal}</span>
                        </div>
                        <button onclick="window.cartSys.remove(${item.id})" class="ml-2 w-8 h-8 bg-red-50 text-red-500 rounded-full flex items-center justify-center hover:bg-red-500 hover:text-white transition-colors">
                            <span class="material-symbols-outlined text-sm">delete</span>
                        </button>
                    </div>
                </div>
            `;
        });

        container.innerHTML = html;
        if (summary) {
            document.getElementById('cart-subtotal').textContent = `₹${total}`;
            document.getElementById('cart-tax').textContent = `₹${Math.round(total * 0.05)}`; // 5% tax mock
            document.getElementById('cart-summary-total').textContent = `₹${total + Math.round(total * 0.05)}`;
        }
    }
}

window.cartSys = new CartManager();
