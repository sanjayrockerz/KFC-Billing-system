# Design System Document: The Botanical Archive

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Digital Apothecary."** Unlike generic e-commerce platforms that feel clinical and transactional, this system aims to replicate the tactile, soulful experience of a traditional *Naatu Marundhu Kadai*. 

We move beyond the "template" look by embracing **Organic Editorialism**. This means utilizing generous whitespace (the "breathing room" of a quiet shop), intentional asymmetry in product staging, and a sophisticated layering of warm, earthen tones. The goal is to make the user feel as though they are browsing a high-end botanical journal rather than an app. 

### Breaking the Grid
*   **Layered Intersections:** Allow product images to subtly break out of their container boundaries.
*   **Dual-Language Harmony:** English and Tamil are treated with equal visual weight, using a baseline-aligned typographic grid to ensure the script density of Tamil doesn't clutter the minimalist aesthetic.

---

### 2. Colors: Tonal Depth & The "No-Line" Rule
The palette is rooted in the earth. We avoid artificial high-contrast borders in favor of "Tonal Containment."

*   **The "No-Line" Rule:** 1px solid borders are strictly prohibited for sectioning. Differentiation must be achieved through background shifts. For example, a `surface-container-low` section should sit directly on a `surface` background to create a soft edge.
*   **Surface Hierarchy & Nesting:** Use the `surface-container` tiers (Lowest to Highest) to create physical depth.
    *   **Level 0 (Background):** `surface` (#fbfbe2)
    *   **Level 1 (Sectioning):** `surface-container-low` (#f5f5dc)
    *   **Level 2 (Active Cards):** `surface-container` (#efefd7)
*   **Signature Textures:** Use a subtle linear gradient on primary CTAs—transitioning from `primary` (#3d6751) to `primary-container` (#9ecbb0) at a 145-degree angle—to give buttons a "pressed leaf" organic quality.
*   **Glassmorphism:** For floating elements like the bottom navigation bar, use `surface-container-lowest` (#ffffff) at 85% opacity with a `20px` backdrop blur to allow the herbal palette to bleed through.

---

### 3. Typography: The Editorial Voice
We pair the geometric structure of **Poppins** with the fluid, organic curves of **Noto Sans Tamil**.

*   **Display & Headline (Poppins 600):** Used for product names and category titles. The high x-height conveys authority and modernism.
    *   *Scale Example:* `headline-lg` (2rem) for hero headers.
*   **Body & Labels (Noto Sans Tamil 400 / Manrope):** Noto Sans Tamil is optimized for legibility at 14-16px. In dual-language views, ensure the Tamil script leading (line height) is 1.5x to accommodate complex character clusters.
*   **The Hierarchy Goal:** Use extreme scale contrast. A large `display-md` category name paired with a much smaller `label-md` description creates a premium, curated feel.

---

### 4. Elevation & Depth: Tonal Layering
Traditional shadows are too "digital." Here, we use light to define presence.

*   **The Layering Principle:** Depth is achieved by "stacking." Place a `surface-container-lowest` card on a `surface-container-low` background. The slight shift in cream/beige creates a natural lift.
*   **Ambient Shadows:** If a card must float (e.g., a "Quick Add" modal), use an ultra-diffused shadow:
    *   `box-shadow: 0 12px 40px rgba(27, 29, 14, 0.05);` (using a tinted version of `on-surface`).
*   **The Ghost Border:** For product cards, use a "Ghost Border" of `outline-variant` (#c4c8bd) at **15% opacity**. This provides a whisper of a boundary without interrupting the visual flow.

---

### 5. Components: The Building Blocks

#### **Buttons (Large & Touch-Friendly)**
*   **Primary:** Background: `primary` (#3d6751); Text: `on-primary` (#ffffff); Radius: `md` (0.75rem).
*   **Secondary:** Background: `secondary-container` (#d1e6c3); Text: `on-secondary-container` (#55684c).
*   **Interaction:** On tap, scale the button to 0.98 to provide haptic-like visual feedback.

#### **Product Cards**
*   **Style:** No hard borders. Use `surface-container-lowest` (#ffffff) with a `xl` (1.5rem) corner radius.
*   **Content:** Image at the top, followed by Poppins Title (English) and Noto Sans Tamil subtitle (Product Name in Tamil).
*   **Pricing:** Placed in the top-right corner using a `tertiary-fixed` (#e9e2d2) pill.

#### **Dual-Language Toggle**
*   A "Glassmorphism" pill floating in the top-right of the screen. 
*   Uses `surface-bright` at 80% opacity. 
*   Active state uses `primary-fixed-dim` (#a4d1b6) to highlight the selected language (EN | தமிழ்).

#### **Search Input**
*   Full-width with `full` (9999px) roundedness.
*   Background: `surface-container-high` (#eaead1).
*   Placeholder text in `on-surface-variant` (#444840).

---

### 6. Do's and Don'ts

#### **Do:**
*   **Do** use vertical whitespace (Spacing Scale `8` or `10`) to separate categories instead of horizontal lines.
*   **Do** ensure that Tamil text is never smaller than 14px for readability.
*   **Do** use "Soft Layering"—a light card on a slightly darker background.

#### **Don't:**
*   **Don't** use pure black (#000000) for text. Use `on-surface` (#1b1d0e) to maintain the organic, warm tone.
*   **Don't** use standard Material Design blue for links or success states; use `primary` greens.
*   **Don't** use sharp 90-degree corners. Every element should have at least a `sm` (0.25rem) radius to feel "natural."
*   **Don't** use heavy drop shadows that look like "floating plastic." If it doesn't look like paper or glass, it doesn't belong.

---

### 7. Spacing & Rhythm
Use the **3.5px base unit** (as per the Spacing Scale provided). 
*   **Page Margins:** `5` (1.7rem) for mobile gutters.
*   **Card Padding:** `3.5` (1.2rem).
*   **Section Spacing:** `10` (3.5rem) to ensure a high-end, un-cluttered editorial layout.