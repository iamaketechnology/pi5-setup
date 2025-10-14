# CSS Architecture - PI5 Control Center v3.5.0

Complete modular CSS architecture using `@import` statements.

## 📊 Structure

```
public/css/
├── main.css                    # Entry point (35 lines)
├── components/                 # Modular components (16 files)
│   ├── variables.css          # CSS variables (1.3K)
│   ├── base.css               # Base styles (890B)
│   ├── layout.css             # Main layout (1.0K)
│   ├── header.css             # Header component (850B)
│   ├── tabs.css               # Navigation tabs (772B)
│   ├── cards.css              # Cards & panels (2.1K)
│   ├── terminal.css           # Terminal UI (3.5K)
│   ├── buttons.css            # Button styles (897B)
│   ├── modal.css              # Modal dialogs (1.0K)
│   ├── forms.css              # Form inputs (904B)
│   ├── scripts.css            # Scripts grid (2.0K)
│   ├── docker.css             # Docker cards (1.5K)
│   ├── history.css            # History table (3.1K)
│   ├── scheduler.css          # Scheduler UI (2.1K)
│   ├── network.css            # Network tab (8.5K)
│   └── responsive.css         # Media queries (639B)
└── style.css                  # Legacy (~14K remaining)
```

**Total:** ~30K extracted into 16 modular files + ~14K legacy

## 🎯 Loading Order

```css
/* main.css */

/* 1. Core Foundation */
@import url('./components/variables.css');  /* CSS vars */
@import url('./components/base.css');       /* Reset + body */

/* 2. Layout */
@import url('./components/layout.css');     /* Container, grid */

/* 3. Components (alphabetical) */
@import url('./components/header.css');
@import url('./components/tabs.css');
@import url('./components/cards.css');
@import url('./components/terminal.css');
@import url('./components/buttons.css');
@import url('./components/modal.css');
@import url('./components/forms.css');
@import url('./components/scripts.css');
@import url('./components/docker.css');
@import url('./components/history.css');
@import url('./components/scheduler.css');
@import url('./components/network.css');

/* 4. Responsive */
@import url('./components/responsive.css');

/* 5. Legacy (minor styles) */
@import url('./style.css');  /* Pi-selector, services, etc. */
```

## 📦 Component Details

### Core Components

| Component | Size | Purpose |
|-----------|------|---------|
| `variables.css` | 1.3K | CSS custom properties (colors, spacing) |
| `base.css` | 890B | CSS reset, body, container |
| `layout.css` | 1.0K | Main layout, two-column, content wrapper |

### UI Components

| Component | Size | Purpose |
|-----------|------|---------|
| `header.css` | 850B | Top header with stats |
| `tabs.css` | 772B | Navigation tabs |
| `cards.css` | 2.1K | Cards, panels, stat boxes |
| `terminal.css` | 3.5K | Terminal UI with tabs |
| `buttons.css` | 897B | Button variants |
| `modal.css` | 1.0K | Modal dialogs |
| `forms.css` | 904B | Form inputs, labels |

### Feature Components

| Component | Size | Purpose |
|-----------|------|---------|
| `scripts.css` | 2.0K | Scripts grid cards |
| `docker.css` | 1.5K | Docker container cards |
| `history.css` | 3.1K | Execution history table |
| `scheduler.css` | 2.1K | Scheduled tasks UI |
| `network.css` | 8.5K | Network monitoring tab |

### Utilities

| Component | Size | Purpose |
|-----------|------|---------|
| `responsive.css` | 639B | Media queries for mobile |

## 🎨 Design Tokens

```css
/* variables.css */
:root {
    /* Colors */
    --bg-primary: #0f172a;
    --bg-secondary: #1e293b;
    --bg-tertiary: #334155;
    --text-primary: #f1f5f9;
    --text-secondary: #94a3b8;
    --success: #10b981;
    --error: #ef4444;
    --warning: #f59e0b;
    --info: #3b82f6;
    --border: #475569;
    --terminal-bg: #0a0e1a;
    --card-hover: #293548;
}
```

## 🔄 Migration from Monolithic

**Before (v3.4.0):**
- Single `style.css` file: 2338 lines (~44K)
- Hard to maintain
- No separation of concerns

**After (v3.5.0):**
- 16 modular component files: ~30K
- `style.css` legacy: ~14K (minor styles)
- Easy to maintain and extend
- Clear separation of concerns

## ✅ Benefits

1. **Maintainability**: Each component in its own file
2. **Reusability**: Import only what you need
3. **Scalability**: Easy to add new components
4. **Performance**: Browser caches individual files
5. **Developer Experience**: Clear structure, easy to find styles

## 📝 Adding New Components

1. Create new file: `public/css/components/your-component.css`
2. Add import in `main.css`:
   ```css
   @import url('./components/your-component.css');
   ```
3. Follow existing naming conventions
4. Use CSS variables from `variables.css`

## 🔧 Maintenance

### Extracting from Legacy

If needed to extract more from `style.css`:

1. Identify CSS section (check comments)
2. Create component file
3. Copy CSS block
4. Add import to `main.css`
5. Test UI (ensure no visual changes)
6. Remove from `style.css`

### Best Practices

- Keep components focused (single responsibility)
- Use CSS variables for consistency
- Add component header comments
- Test on all screen sizes
- Verify no duplicate rules

## 📚 Related Documentation

- [REFACTORING-PLAN.md](../../REFACTORING-PLAN.md) - Overall refactoring strategy
- [README.md](../../README.md) - Project overview
- [CHANGELOG.md](../../CHANGELOG.md) - Version history

---

**Version:** 3.5.0
**Last Updated:** 2025-01-14
**Maintainer:** PI5-SETUP Project
