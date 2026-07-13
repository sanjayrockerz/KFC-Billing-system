/**
 * Main JavaScript File
 * Handles global UI interactions, navigation, and common components
 */

document.addEventListener('DOMContentLoaded', () => {
    // Mobile menu toggle
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    if (mobileMenuBtn) {
        mobileMenuBtn.addEventListener('click', () => {
            // Implement mobile menu toggle logic here
            mobileMenuBtn.classList.toggle('bg-cardBg');
            console.log('Mobile menu toggled');
            // Ideally toggle a full-screen mobile menu layer
        });
    }

    // Initialize subtle animations
    initScrollAnimations();
});

/**
 * Handle scroll based animations
 */
function initScrollAnimations() {
    const glassNav = document.querySelector('.glass-nav');
    
    window.addEventListener('scroll', () => {
        if (window.scrollY > 20) {
            glassNav?.classList.add('shadow-md', 'bg-bgMain/95');
            glassNav?.classList.remove('bg-bgMain/90');
        } else {
            glassNav?.classList.remove('shadow-md', 'bg-bgMain/95');
            glassNav?.classList.add('bg-bgMain/90');
        }
    });
}
