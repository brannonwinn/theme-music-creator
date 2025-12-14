# Design Review: {CHANGE_DESCRIPTION}

**Date**: {ISO_TIMESTAMP}
**Worktree**: {WORKTREE_COLOR}
**Branch**: {BRANCH_NAME}
**Status**: Pending Review

## Preview Environment

**URL**: {PREVIEW_URL}
**Viewport Testing**: Desktop (1440px), Tablet (768px), Mobile (375px)

## Git Range

**Base SHA**: {BASE_SHA}
**Head SHA**: {HEAD_SHA}

```bash
git diff {BASE_SHA}...{HEAD_SHA} --stat
git log {BASE_SHA}..{HEAD_SHA} --oneline
```

## Changes Summary

{WHAT_CHANGED_DESCRIPTION}

**Modified files:**
- frontend/app/{page}.tsx - Main page implementation
- frontend/components/{component}.tsx - Reusable component
- frontend/styles/{styles}.css - Styling updates

**Key design decisions:**
- Component architecture choices
- Styling approach (Tailwind/CSS modules/etc.)
- Accessibility considerations
- Responsive design strategy

## Design Review Checklist

Use Chrome DevTools MCP to systematically review:

### Phase 0: Preparation
- [ ] Navigate to preview URL
- [ ] Set initial viewport (1440x900 desktop)
- [ ] Capture initial screenshot (visual)
- [ ] Capture initial snapshot (accessibility tree)

### Phase 1: Interaction & User Flow
- [ ] Test primary user flow
- [ ] Verify all interactive states (hover, active, disabled)
- [ ] Check destructive action confirmations
- [ ] Assess perceived performance

### Phase 2: Responsiveness Testing
- [ ] Desktop (1440px) - Full page screenshot
- [ ] Tablet (768px) - Resize + screenshot
- [ ] Mobile (375px) - Resize + screenshot
- [ ] Check for horizontal scrolling, overlaps, broken layouts

### Phase 3: Visual Polish
- [ ] Layout & spacing consistency
- [ ] Typography hierarchy
- [ ] Color palette consistency
- [ ] Visual hierarchy clarity
- [ ] Pixel-perfect polish

### Phase 4: Accessibility (WCAG 2.1 AA)
- [ ] Keyboard navigation (Tab order)
- [ ] Visible focus indicators
- [ ] Keyboard operability (Enter/Space)
- [ ] Semantic HTML structure
- [ ] Form label associations
- [ ] Image alt text
- [ ] Color contrast ratios (4.5:1)

### Phase 5: Robustness Testing
- [ ] Form validation with invalid inputs
- [ ] Content overflow scenarios
- [ ] Loading, empty, error states
- [ ] Edge case handling

### Phase 6: Code Health
- [ ] Component reuse (not duplication)
- [ ] Design tokens (no hardcoded values)
- [ ] Established patterns followed

### Phase 7: Content & Console
- [ ] Text grammar and clarity
- [ ] Browser console errors/warnings

## Review Output Format

### Executive Summary
[Positive opening and overall assessment - for coordinators and stakeholders]

**Quality Score**: [Excellent/Good/Needs Work/Critical Issues]
**Key Accomplishments**: [What works well - 2-3 bullet points]
**Critical Issues**: [Count of blockers and high-priority items]

### Detailed Findings

#### Blockers 🚫
**Problem**: [User-facing problem description]
**Impact**: [How this affects users]
**Technical Details**: [Specific file, component, line numbers, CSS/HTML issues]
**Evidence**: ![Screenshot](path/to/screenshot.png)

---

#### High-Priority ⚠️
**Problem**: [User-facing problem description]
**Impact**: [How this affects users]
**Technical Details**: [Specific file, component, line numbers, CSS/HTML issues]
**Evidence**: ![Screenshot](path/to/screenshot.png)

---

#### Medium-Priority / Suggestions 💡
**Problem**: [User-facing problem description]
**Technical Details**: [Specific implementation suggestion]

---

#### Nitpicks ✨
- Nit: [Minor aesthetic or consistency issue]
- Nit: [Another minor detail]

### Performance Metrics
[If performance tracing was run - Core Web Vitals, load times, interaction metrics]

### Design Principles Compliance

[If design_principles.md was found, validate against documented principles]
[If not found, use general design best practices and note in findings]

- Design philosophy alignment
- Design system foundation usage
- Layout and visual hierarchy
- Interaction design quality
- Established patterns and conventions

### Style Guide Compliance

[If style_guide.md was found, validate against documented specifications]
[If not found, use general design system standards and note in findings]

- Color palette adherence
- Typography consistency
- Component usage
- Spacing and layout standards

### Next Steps
[Recommended actions for addressing findings]

---

## Design Review Agent Section

(Design review agent will append detailed findings below after completing the 7-phase review process)
