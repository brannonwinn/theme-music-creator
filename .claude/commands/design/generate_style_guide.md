# Generate Style Guide Document

Generate a comprehensive style guide document for any project by analyzing existing documentation and creating concrete, production-ready design specifications.

## What This Command Does

This command helps you create a world-class style guide by:
1. Finding or asking for your project's documentation directory
2. Reading existing design docs (especially design_principles.md if it exists)
3. Analyzing your project's technology stack and design system
4. Generating a comprehensive style guide with:
   - Complete color system (with hex, HSL/OKLCH, Tailwind values)
   - Typography hierarchy and font specifications
   - Spacing system and layout patterns
   - Component specifications with production-ready code examples
   - Icons, shadows, borders, animations
   - Accessibility standards and implementation
   - Code examples for all major components

## Usage

```bash
/design:generate_style_guide
```

The command will guide you through the process interactively.

---

## Agent Instructions

You are an expert style guide architect. Your goal is to create an EXCELLENT and PRODUCTION-READY style guide that developers can immediately use to build consistent, accessible interfaces.

### Phase 1: Discover Documentation Directory

**Step 1**: Try to automatically find the documentation directory by searching for common patterns:

```bash
# Search for common documentation directories
find . -type d -name "docs" -o -name "ai_docs" -o -name "documentation" -o -name "design" 2>/dev/null | grep -v node_modules | head -10
```

**Step 2**: If multiple directories are found OR no directory is found, use the AskUserQuestion tool to get the documentation directory:

```typescript
AskUserQuestion({
  questions: [{
    question: "Where should I place the style guide document? (We found these options, or you can specify a custom path)",
    header: "Docs Path",
    multiSelect: false,
    options: [
      {
        label: "./ai_docs/context/core_docs/",
        description: "AI documentation directory (recommended for Claude Code projects)"
      },
      {
        label: "./docs/design/",
        description: "Standard docs directory"
      },
      {
        label: "./documentation/design/",
        description: "Documentation directory"
      },
      // If you found specific directories, add them here dynamically
    ]
  }]
})
```

**Important**: The "Other" option is automatically provided by AskUserQuestion, so users can write in a custom path.

**Step 3**: Store the selected path and ensure the directory exists:

```bash
mkdir -p <selected_path>
```

---

### Phase 2: Gather Project Context

**Step 1**: Search for existing design and project documentation:

```bash
# Find design-related documents (PRIORITY ORDER)
find . -type f \( -name "*design_principles*.md" -o -name "*style*.md" -o -name "*design_system*.md" \) 2>/dev/null | grep -v node_modules

# Find project context documents
find . -type f \( -name "*prd*.md" -o -name "*charter*.md" -o -name "*README*.md" \) 2>/dev/null | grep -v node_modules | head -10

# Find frontend/UI configuration files
find . -type f \( -name "tailwind.config.*" -o -name "globals.css" -o -name "theme.ts" -o -name "theme.js" \) 2>/dev/null | grep -v node_modules

# Find brand assets (logos, brand guidelines, icons)
find . -type f \( -name "*logo*" -o -name "*brand*" \) \( -name "*.svg" -o -name "*.png" -o -name "*.jpg" -o -name "*.md" \) 2>/dev/null | grep -v node_modules | head -10

# Find icon/asset directories
find . -type d \( -name "icons" -o -name "assets" -o -name "images" -o -name "public" \) 2>/dev/null | grep -v node_modules | head -5
```

**Step 2**: Read the most relevant documents found:

Priority order:
1. **design_principles.md** (if exists - this is the foundation!)
2. **Brand guidelines** (if exists - brand.md, brand_guidelines.md, etc.)
3. Existing style_guide.md (if any - to update/enhance)
4. tailwind.config.js/ts (current color/spacing config)
5. globals.css (current CSS variables)
6. **Logo files** (if found - use Read tool to view images and extract colors)
7. Main README.md (tech stack info)
8. Any other design-related docs

Use parallel Read calls to fetch multiple documents efficiently.

**Step 3**: If a style guide template exists in `.claude/commands/design/`, read it:

```bash
# Check for template
ls ./.claude/commands/design/*style*template*.md 2>/dev/null
```

---

### Phase 3: Understand Technology Stack & Design System

**Step 1**: Analyze the gathered documentation to understand:
- **Frontend framework**: React? Vue? Svelte? Native? Plain HTML/CSS?
- **CSS approach**: Tailwind? CSS Modules? Styled Components? Vanilla CSS?
- **Component library**: shadcn/ui? Material-UI? Chakra? Custom?
- **Design tokens**: CSS variables? JS tokens? Tailwind config?
- **Color space**: HSL? OKLCH? RGB? Hex only?
- **Typography**: System fonts? Custom fonts? Monospace for code?

**Step 2**: If critical information is missing, ask the user:

```typescript
AskUserQuestion({
  questions: [
    {
      question: "What is your frontend technology stack?",
      header: "Tech Stack",
      multiSelect: true,
      options: [
        { label: "React/Next.js", description: "React-based with JSX/TSX" },
        { label: "Tailwind CSS", description: "Utility-first CSS framework" },
        { label: "shadcn/ui", description: "Radix UI + Tailwind components" },
        { label: "TypeScript", description: "Type-safe JavaScript" }
      ]
    },
    {
      question: "What color system does your project use?",
      header: "Color System",
      multiSelect: false,
      options: [
        { label: "OKLCH (modern)", description: "Perceptually uniform, modern color space" },
        { label: "HSL", description: "Hue, Saturation, Lightness" },
        { label: "RGB/Hex only", description: "Traditional hex colors" },
        { label: "Don't know / not sure", description: "I'll inspect the codebase" }
      ]
    },
    {
      question: "What is the primary interface mode?",
      header: "Theme Mode",
      multiSelect: false,
      options: [
        { label: "Dark mode first", description: "Dark mode is primary, light mode optional" },
        { label: "Light mode first", description: "Light mode is primary, dark mode optional" },
        { label: "Equal support", description: "Both modes are equally important" }
      ]
    },
    {
      question: "What type of project is this?",
      header: "Project Type",
      multiSelect: false,
      options: [
        { label: "Dashboard/Admin Tool", description: "Data-heavy, charts, tables, monitoring" },
        { label: "Consumer Web App", description: "Marketing site, e-commerce, public-facing" },
        { label: "Developer Tool", description: "CLI, IDE, dev platform, code editor" },
        { label: "Mobile App", description: "React Native, iOS, Android" }
      ]
    },
    {
      question: "Do you have existing brand assets that should guide the style guide?",
      header: "Brand Assets",
      multiSelect: true,
      options: [
        { label: "Logo with brand colors", description: "Logo file with specific color palette to extract" },
        { label: "Brand guidelines", description: "Existing brand/design guidelines document" },
        { label: "Icon library", description: "Specific icon system already in use (Lucide, Heroicons, etc.)" },
        { label: "None / Starting fresh", description: "No existing brand assets to consider" }
      ]
    }
  ]
})
```

---

### Phase 4: Generate Style Guide Document

**Step 1**: Create a comprehensive style guide that includes:

#### Required Sections:

**1. Document Overview**
- Version, status, last updated, purpose
- Target audience (developers, designers, product)
- How to use this guide

**2. Design System Foundation**
- Design philosophy (1-2 sentences from design_principles.md if exists)
- Key design values
- Relationship to design principles document

**3. Color System** (MOST IMPORTANT SECTION)

**IMPORTANT**: If brand assets were found (logo, brand guidelines), extract and incorporate brand colors into the color system. Use the primary brand color for semantic "primary" color, and build the palette around brand identity.

Must include complete tables with:
- **Brand Colors** (if logo/brand guidelines exist - extract and document these FIRST)
- **Neutral Colors** (backgrounds, surfaces, borders, text)
- **Semantic Colors** (primary, success, error, warning, info - use brand colors where appropriate)
- **Domain-Specific Colors** (agent colors, status colors, etc. based on project)

Each color must have:
- Purpose/name
- Hex value
- Tailwind class (if applicable)
- HSL or OKLCH value
- Usage description
- Accessibility notes (contrast ratios)

Example table format:
```markdown
### Neutral Colors (Dark Mode)

| Purpose | Hex | Tailwind | OKLCH | Usage | Contrast |
|---------|-----|----------|-------|-------|----------|
| **Background** | `#0A0A0A` | `zinc-950` | `oklch(0.04 0 0)` | Main app background | - |
| **Text Primary** | `#E5E5E5` | `zinc-200` | `oklch(0.9 0 0)` | Body text, headings | 17.8:1 ✅ |
```

**4. Typography** (PRODUCTION-READY)

Must include:
- **Font families**: Display, body, code with fallbacks
- **Type scale table**: All text levels with size, line-height, weight, Tailwind classes
- **Usage guidelines**: When to use each level
- **Implementation examples**: Code snippets showing proper usage

Example table format:
```markdown
### Type Scale

| Level | Size | Line Height | Weight | Tailwind | Usage |
|-------|------|-------------|--------|----------|-------|
| **Display** | 36px | 40px | Bold (700) | `text-4xl font-bold` | Dashboard titles |
| **H1** | 30px | 36px | Semibold (600) | `text-3xl font-semibold` | Page titles |
| **Body** | 14px | 20px | Regular (400) | `text-sm` | Default body text |
| **Code** | 13px | 18px | Regular (400) | `text-[13px] font-mono` | Code, timestamps |
```

**5. Spacing System**

Must include:
- **Base unit**: (e.g., 4px, 8px)
- **Scale**: All spacing values (4, 8, 12, 16, 24, 32, 40, 48, 64, 80, 96)
- **Tailwind mapping**: (e.g., 4px = `p-1`, 8px = `p-2`)
- **Usage guidelines**: Component padding, margins, gaps
- **Examples**: Common spacing patterns

**6. Layout & Grid**

- Container widths
- Breakpoints (mobile, tablet, desktop)
- Grid system (if applicable)
- Common layout patterns

**7. Component Specifications** (WITH PRODUCTION CODE)

For each major component type, include:
- **Purpose and usage**
- **Visual specifications** (sizes, colors, states)
- **Accessibility requirements**
- **Production-ready code example** (React/Vue/etc.)

Minimum components to document:
- Buttons (primary, secondary, destructive)
- Cards
- Inputs (text, select, checkbox, radio)
- Badges/Pills
- Tables
- Modals/Dialogs
- Navigation (if applicable)

Example format:
```markdown
### Button Component

**Purpose**: Primary interactive elements for user actions

**Variants**:
- **Primary**: Main actions (blue background)
- **Secondary**: Alternative actions (outline)
- **Destructive**: Dangerous actions (red background)

**States**: Default, hover, active, disabled, loading

**Code Example** (React + Tailwind):
```tsx
import { Button } from "@/components/ui/button"

// Primary button
<Button className="bg-blue-500 hover:bg-blue-600 text-white">
  Save Changes
</Button>

// Secondary button
<Button variant="outline" className="border-zinc-700 text-zinc-200">
  Cancel
</Button>

// Destructive button
<Button variant="destructive" className="bg-red-500 hover:bg-red-600">
  Delete
</Button>
```

**Accessibility**:
- Minimum 44px touch target
- ARIA labels for icon-only buttons
- Focus visible states
```

**8. Icons**

**IMPORTANT**: If an icon library was identified (from user input or asset discovery), document that specific library. If custom icons were found in assets, document those.

- Icon library name and version (Lucide, Heroicons, custom, etc.)
- Standard sizes (sm: 16px, md: 20px, lg: 24px, xl: 32px)
- Usage guidelines (when to use icons, icon-only buttons)
- Color and accessibility (sufficient contrast, aria-labels)
- Installation/import instructions for the specific library

**9. Shadows & Elevation**

- Shadow scale (sm, md, lg, xl)
- Usage for depth hierarchy
- CSS values or Tailwind classes

**10. Borders & Dividers**

- Border widths (1px, 2px)
- Border radius scale (sm, md, lg, full)
- Border colors
- Usage guidelines

**11. Animations & Transitions**

- Timing values (duration, easing)
- Common animation patterns
- Performance considerations
- Reduced motion support

**12. Accessibility Standards**

- WCAG compliance level (AA minimum)
- Contrast ratio requirements (4.5:1 for text)
- Keyboard navigation patterns
- Screen reader considerations
- Focus management
- Color blindness considerations

**13. Code Examples**

Include 2-3 complete, production-ready component examples that demonstrate:
- Proper color usage
- Typography hierarchy
- Spacing system
- Accessibility features
- Responsive design

Examples should be copy-paste ready for the project's tech stack.

**14. Design Tokens Reference** (if applicable)

- Where tokens are defined (tailwind.config.js, globals.css, etc.)
- How to update colors/spacing
- Integration with design tools (Figma, tweakcn.com, etc.)

---

**Step 2**: Write the document to the selected path:

```typescript
Write({
  file_path: "<selected_path>/style_guide.md",
  content: "<generated_content>"
})
```

---

### Phase 5: Summary and Next Steps

**Step 1**: Provide a summary of what was created:

```markdown
✅ Style Guide Document Created

**Location**: <path>
**Sections**: <count> sections with production-ready specifications
**Key Highlights**:
- Complete color system with <X> colors documented
- Typography scale with <Y> levels
- <Z> component specifications with code examples
- Accessibility standards (WCAG <level>)

**Technology Stack Documented**:
- Framework: <framework>
- CSS: <css_approach>
- Components: <component_library>
- Color Space: <color_space>

**Next Steps**:
1. Review component examples and customize for your needs
2. Share with your team for feedback
3. Use as reference when building new features
4. Keep synchronized with design_principles.md
```

**Step 2**: Offer to create related documentation:

```markdown
Would you like me to also create:
- [ ] Component Library Storybook/Documentation
- [ ] Design Tokens Implementation (if not using tweakcn.com workflow)
- [ ] Figma/Design Tool Integration Guide
- [ ] Accessibility Testing Checklist
```

---

## Style Guide Quality Checklist

The generated document MUST be:

✅ **Production-Ready**: All code examples are copy-paste ready and functional
✅ **Complete**: Every color, font size, spacing value documented with usage
✅ **Accessible**: WCAG standards clearly defined with contrast ratios
✅ **Technology-Specific**: Tailored to the actual tech stack (React, Vue, etc.)
✅ **Visual**: Tables and code blocks make information scannable
✅ **Consistent**: Follows naming conventions from design_principles.md
✅ **Implementable**: Developers can build features using only this guide
✅ **Maintainable**: Clear structure for updates as system evolves
✅ **Cross-Referenced**: Links to design_principles.md and other relevant docs
✅ **Example-Rich**: Real component examples, not abstract descriptions

---

## Example Output Structure

```markdown
# [Project Name] Style Guide

**Version**: 1.0
**Status**: Active
**Last Updated**: YYYY-MM-DD
**Purpose**: Visual design specifications and component implementation guide

## Document Overview
[How to use, audience, relationship to design principles]

## Design System Foundation
[Philosophy, values, principles reference]

## Color System

### Neutral Colors (Dark Mode)
[Complete table with hex, Tailwind, OKLCH, usage, contrast]

### Semantic Colors
[Primary, success, error, warning, info with all details]

### Domain-Specific Colors
[Agent colors, status colors, etc. - project-specific]

## Typography

### Font Families
[Display, body, code with fallbacks and installation]

### Type Scale
[Complete table with all levels, sizes, weights, classes, usage]

### Implementation Examples
[Code showing proper usage in context]

## Spacing System

### Base Unit & Scale
[4px base with full scale and Tailwind mapping]

### Usage Guidelines
[Component padding, margins, gaps with examples]

## Layout & Grid

### Container Widths
[Max widths for different breakpoints]

### Breakpoints
[Mobile, tablet, desktop with pixel values]

## Component Specifications

### Buttons
[Purpose, variants, states, code example, accessibility]

### Cards
[Purpose, variants, states, code example, accessibility]

[... more components ...]

## Icons
[Library, sizes, usage, accessibility]

## Shadows & Elevation
[Scale, usage, CSS values]

## Borders & Dividers
[Widths, radius, colors, usage]

## Animations & Transitions
[Timing, patterns, performance, reduced motion]

## Accessibility Standards
[WCAG level, contrast requirements, keyboard navigation, screen readers]

## Complete Component Examples

### Example 1: [Component Name]
[Full production-ready component with all features]

### Example 2: [Component Name]
[Full production-ready component with all features]

## Design Tokens Reference
[Where tokens are defined, how to update, tool integration]

## Maintenance
[Update process, version history, feedback mechanism]
```

---

## Tips for Success

1. **Read design_principles.md first**: Align style guide with strategic principles
2. **Inspect actual code**: Find real colors, fonts, spacing values in use
3. **Generate real examples**: Use the actual component library (shadcn/ui, etc.)
4. **Document what exists**: Don't invent new systems unless explicitly asked
5. **Be specific**: "14px text-sm Inter Regular" not "small body text"
6. **Show contrast ratios**: Include actual WCAG compliance for each color pairing
7. **Use project's tech**: If they use Tailwind, show Tailwind classes
8. **Make it scannable**: Tables, code blocks, clear headings
9. **Link to sources**: Reference where tokens are defined in codebase

---

## Common Mistakes to Avoid

❌ **Abstract descriptions**: "Use blue for primary actions" - too vague
✅ **Concrete specs**: "Primary: #3B82F6 (blue-500), oklch(0.598 0.215 263.711)"

❌ **Missing code examples**: Just showing designs without implementation
✅ **Production code**: Full React/Vue components ready to copy-paste

❌ **Incomplete tables**: Missing Tailwind classes or color values
✅ **Complete reference**: Every color with hex, Tailwind, OKLCH, usage, contrast

❌ **Generic components**: Button examples that don't match the project
✅ **Project-specific**: Use actual component library (shadcn/ui Button, etc.)

❌ **Ignoring accessibility**: No contrast ratios or WCAG guidance
✅ **Accessibility-first**: Every color pairing shows contrast ratio

❌ **No relationship to principles**: Style guide disconnected from philosophy
✅ **Aligned**: Reference design principles and show how specs support them

---

**Remember**: A style guide is the bridge between design principles (WHY) and implementation (HOW). Make it EXCELLENT, CLEAR, and IMMEDIATELY USABLE!
