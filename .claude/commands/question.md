---
allowed-tools: Bash(git ls-files:*), Read, SlashCommand
description: Answer questions about the project by intelligently loading relevant context
---

# Question

Answer the user's question by first determining which context to load, then analyzing the relevant documentation. This prompt is designed to provide accurate, context-aware answers without making any code changes.

## Instructions

**IMPORTANT: This is a question-answering task only - DO NOT write, edit, or create any files**

## Step 1: Analyze Question & Load Context

First, analyze the user's question to determine the best context to load:

**Backend Questions** → Run `/prime-backend`
- Keywords: workflow, node, router, agent, celery, fastapi, api, service, worker, event, async, redis, business logic
- Examples: "How do workflows work?", "What's the event-driven architecture?", "How do I add a new node?"

**Frontend Questions** → Run `/prime-frontend`
- Keywords: react, component, next.js, nextjs, frontend, ui, tailwind, shadcn, typescript, page, route, client, server component
- Examples: "How does type generation work?", "What's the component structure?", "How do I make API calls?"

**Database Questions** → Run `/prime-database`
- Keywords: database, migration, rls, supabase, table, schema, postgres, sql, model, alembic, row level security, policy
- Examples: "How do RLS policies work?", "How do I create a migration?", "What's the data model?"

**Business/Product Questions** → Run `/prime-business`
- Keywords: product, feature, requirement, user story, business, roadmap, objective, metric, guest, host, plan, pricing
- Examples: "What features are planned?", "What's the business model?", "Who are the users?"

**General/Overview Questions** → Run `/prime`
- Keywords: setup, install, getting started, overview, architecture, tech stack, project structure
- Examples: "How do I set up the project?", "What's the tech stack?", "How is the project organized?"

**Execute the appropriate prime command based on your analysis.**

## Step 2: Answer the Question

After loading context:
- Provide a direct, comprehensive answer
- Reference specific documentation or files
- Include relevant code patterns or examples if applicable
- Explain architectural decisions when relevant
- If the question spans multiple domains, acknowledge that and provide cross-domain context

## Important Notes

- Focus on understanding and explaining existing code and project structure
- If the question requires code changes, explain what would need to be done conceptually without implementing
- Always cite which CLAUDE.md files or documentation you're referencing
- If unclear which context to load, default to `/prime` for general overview

## Question

$ARGUMENTS