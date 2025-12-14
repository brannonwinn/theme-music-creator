# Generate Design Principles Document

Generate a comprehensive design principles document for any project by analyzing existing documentation and creating clear, actionable design guidelines.

## What This Command Does

This command helps you create a world-class design principles document by:
1. Finding or asking for your project's documentation directory
2. Reading existing design docs, PRDs, and project charters
3. Analyzing your project's goals and requirements
4. Generating a comprehensive design principles document with:
   - Core design philosophy and vision
   - 12+ strategic design principles with implementation guidance
   - Tactical guidelines (colors, typography, spacing, animations)
   - Implementation patterns
   - Design review criteria

## Usage

```bash
/design:generate_design_principles
```

The command will guide you through the process interactively.

---

## Agent Instructions

You are an expert design principles architect. Your goal is to create an EXCELLENT and CLEAR design principles document that will serve as the foundational pillar for all design decisions in the project.

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
    question: "Where should I place the design principles document? (We found these options, or you can specify a custom path)",
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
# Find design-related documents
find . -type f \( -name "*design*.md" -o -name "*style*.md" -o -name "*principles*.md" \) 2>/dev/null | grep -v node_modules

# Find project context documents
find . -type f \( -name "*prd*.md" -o -name "*charter*.md" -o -name "*README*.md" -o -name "*requirements*.md" \) 2>/dev/null | grep -v node_modules | head -10
```

**Step 2**: Read the most relevant documents found:

Priority order:
1. Existing design_principles.md (if any - to update/enhance)
2. style_guide.md (if exists)
3. PRD (Product Requirements Document)
4. Project charter
5. Main README.md
6. Any other design-related docs

Use parallel Read calls to fetch multiple documents efficiently.

**Step 3**: If a design principles template exists in `.claude/commands/design/`, read it:

```bash
# Check for template
ls ./.claude/commands/design/*template*.md 2>/dev/null
```

---

### Phase 3: Understand Project Type & Goals

**Step 1**: Analyze the gathered documentation to understand:
- **Project type**: Web app? Mobile app? Dashboard? API? Desktop tool?
- **Target users**: Developers? End consumers? Enterprise? Internal tool?
- **Design complexity**: Data-heavy? Visual-heavy? Form-heavy? Real-time?
- **Key features**: What makes this project unique?
- **Technology stack**: React? Vue? Native? Desktop?

**Step 2**: If critical information is missing, ask the user:

```typescript
AskUserQuestion({
  questions: [
    {
      question: "What type of project is this?",
      header: "Project Type",
      multiSelect: false,
      options: [
        { label: "Web Dashboard/Admin Tool", description: "Data-heavy, monitoring, analytics" },
        { label: "Consumer Web App", description: "Public-facing, marketing, e-commerce" },
        { label: "Mobile App", description: "iOS/Android native or React Native" },
        { label: "Developer Tool", description: "CLI, IDE extension, dev platform" },
        { label: "API/Backend", description: "Headless, API-first" }
      ]
    },
    {
      question: "Who are the primary users?",
      header: "Target Users",
      multiSelect: true,
      options: [
        { label: "Developers/Technical Users", description: "Power users, keyboard-driven" },
        { label: "End Consumers", description: "General public, non-technical" },
        { label: "Enterprise/Business Users", description: "B2B, data analysis, reporting" },
        { label: "Internal Team", description: "Internal tools, workflows" }
      ]
    },
    {
      question: "What are the key design challenges?",
      header: "Challenges",
      multiSelect: true,
      options: [
        { label: "Real-time data updates", description: "Live dashboards, monitoring" },
        { label: "Complex data visualization", description: "Charts, graphs, tables" },
        { label: "Multi-step workflows", description: "Forms, wizards, onboarding" },
        { label: "Performance at scale", description: "Large datasets, fast interactions" },
        { label: "Mobile responsiveness", description: "Cross-device support" }
      ]
    }
  ]
})
```

---

### Phase 4: Generate Design Principles Document

**Step 1**: Create a comprehensive design principles document that includes:

#### Required Sections:

**1. Document Overview**
- Version, status, last updated, purpose
- Target audience, scope, authority

**2. Core Design Philosophy**
- Vision statement (1-2 sentences capturing the essence)
- 5-7 design values (core beliefs that drive decisions)

**3. Strategic Design Principles (10-15 principles)**

Each principle MUST include:
- **Statement**: Clear, declarative principle
- **Rationale**: Why this matters for THIS project
- **Implementation Guidance**: Specific, actionable steps
- **Success Metrics**: Measurable targets (when applicable)
- **Anti-Patterns to Avoid**: Common mistakes marked with ❌

Example strategic principles to consider (adapt to project):
- Real-Time First (for monitoring/dashboard tools)
- Information Density with Hierarchy (for data-heavy apps)
- Performance as a Feature (always relevant)
- Accessibility is Non-Negotiable (always required)
- Mobile-First or Desktop-Optimized (choose based on project)
- Progressive Disclosure (for complex apps)
- Keyboard-Driven Efficiency (for developer tools)
- Trust Through Transparency (for data/analytics tools)

**4. Tactical Design Guidelines**

Must include:
- **Color System**: Primary, secondary, semantic colors with hex codes
- **Typography Hierarchy**: Font sizes, weights, line heights
- **Spacing System**: Base unit and scale
- **Animation Principles**: Timing, easing, when to use

**5. Implementation Patterns**
- Component architecture approach
- State management pattern
- Error handling strategy

**6. Design Review Criteria**
- Checklist for validating implementations against principles

**7. Appendix: Design References**
- Inspiration (S-tier products to emulate)
- Anti-references (what to avoid)

**8. Document Maintenance**
- Review cycle, change process, feedback mechanism

---

**Step 2**: Write the document to the selected path:

```typescript
Write({
  file_path: "<selected_path>/design_principles.md",
  content: "<generated_content>"
})
```

---

### Phase 5: Summary and Next Steps

**Step 1**: Provide a summary of what was created:

```markdown
✅ Design Principles Document Created

**Location**: <path>
**Sections**: <count> strategic principles, tactical guidelines, implementation patterns
**Key Highlights**:
- Principle 1: <brief>
- Principle 2: <brief>
- Principle 3: <brief>

**Next Steps**:
1. Review the document and customize any sections
2. Share with your team for feedback
3. Use as foundation for all design decisions
4. Reference in design reviews and PRs
```

**Step 2**: Offer to create related documents:

```markdown
Would you like me to also create:
- [ ] Style Guide (concrete implementation of these principles)
- [ ] Component Library Documentation
- [ ] Design System Tokens (colors, typography, spacing as code)
```

---

## Design Principles Quality Checklist

The generated document MUST be:

✅ **Actionable**: Every principle has specific implementation guidance
✅ **Comprehensive**: Covers strategic philosophy → tactical details
✅ **Project-Specific**: Tailored to this project's unique needs and goals
✅ **User-Focused**: Designed for the actual target users and use cases
✅ **Measurable**: Includes concrete success metrics where applicable
✅ **Authoritative**: Clear authority and non-negotiable requirements
✅ **Clear**: Written in plain language, no jargon without explanation
✅ **Visual**: Uses formatting (headings, lists, code blocks) effectively
✅ **Complete**: All required sections included
✅ **Maintainable**: Includes process for updating and evolving

---

## Example Output Structure

```markdown
# [Project Name] Design Principles

**Version**: 1.0
**Status**: Active
**Last Updated**: YYYY-MM-DD
**Purpose**: Foundational design philosophy for [project]

## Document Overview
[Who, what, why, authority]

## Core Design Philosophy

### Vision Statement
[1-2 sentence essence]

### Design Values
1. Value 1: Description
2. Value 2: Description
...

## Strategic Design Principles

### Principle 1: [Name]
**Statement**: [Clear principle]
**Rationale**: [Why this matters]
**Implementation Guidance**: [Specific actions]
**Success Metrics**: [Measurable targets]
**Anti-Patterns**:
- ❌ Don't do X
- ❌ Avoid Y

[Repeat for 10-15 principles]

## Tactical Design Guidelines

### Color System
[Palette with hex codes]

### Typography
[Type scale]

### Spacing
[Scale and usage]

### Animations
[Timing and principles]

## Implementation Patterns
[Architecture, state, errors]

## Design Review Criteria
[Checklist]

## Appendix: Design References
[Inspiration and anti-references]

## Document Maintenance
[Process for updates]
```

---

## Tips for Success

1. **Read broadly, write specifically**: Gather lots of context, but write principles specific to THIS project
2. **Use examples**: Real examples from the project make principles concrete
3. **Be opinionated**: Great design principles make choices, not suggestions
4. **Balance depth**: Strategic principles should be deep (1-2 pages each), tactical should be concise
5. **Think long-term**: These principles should guide decisions for 2-3 years minimum
6. **Make it scannable**: Developers should be able to find answers in <30 seconds

---

## Common Mistakes to Avoid

❌ **Generic principles**: "Make it user-friendly" - too vague
✅ **Specific principles**: "Information density with hierarchy - developers need comprehensive visibility without scrolling"

❌ **No rationale**: Just stating principles without explaining why
✅ **Clear rationale**: Explain why this principle matters for THIS project

❌ **No metrics**: Can't measure success
✅ **Concrete metrics**: "Page load <2s, WebSocket latency <500ms"

❌ **Copying another project**: Blindly copying Stripe's principles
✅ **Inspired adaptation**: Learn from Stripe, adapt for your unique needs

❌ **Too abstract**: All philosophy, no implementation guidance
✅ **Balanced**: Philosophy + concrete implementation guidance

---

**Remember**: These design principles become the foundation for all design decisions. Make them EXCELLENT and CLEAR!
