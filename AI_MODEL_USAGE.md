# AI Model Usage

Not all tasks require the strongest reasoning model.

Choose the appropriate model based on the complexity of the task. Keep premium model usage low while still benefiting from stronger reasoning when it matters.

---

## Preferred Cursor Pro Workflow

| Model | Role |
|-------|------|
| **Composer** | Repository-wide understanding and multi-file changes |
| **Grok 4.5** | Implement features and iterate quickly (best credit-to-quality ratio) |
| **GPT-5.6 Sol** | Architecture, debugging difficult issues, final code review before merging |

---

## Composer

Use Composer when changes affect many files.

Examples:

- Exploring or mapping the codebase
- Creating an entire feature across modules
- Updating multiple modules
- Renaming systems
- Repository-wide edits
- Generating boilerplate across the project

Do not use Composer for architecture decisions.

---

## Grok 4.5

Default coding model.

Use for:

- Implementing new features
- Writing ModuleScripts
- Creating UI
- Controllers
- Services
- Bug fixes
- Refactoring
- Adding items, plants, pets, shops, quests, NPCs

This should be the primary implementation model.

---

## GPT-5.6 Sol (Use Sparingly)

Use GPT-5.6 Sol only for high-value tasks.

Examples:

- Designing a new architecture
- Large system planning
- Debugging difficult issues
- Reviewing critical code before merge
- Security analysis
- Performance bottlenecks
- DataStore design
- Multiplayer synchronization
- Complex algorithms
- Major refactoring decisions

Avoid using GPT-5.6 Sol for simple coding tasks.

---

## Workflow

Every feature should follow this pipeline:

1. **Composer** (optional) — map repo, identify affected files

↓

2. **GPT-5.6 Sol** — design architecture, break into tasks

↓

3. **Grok 4.5** — implement each task

↓

4. **Composer** — apply repository-wide changes if needed

↓

5. **GPT-5.6 Sol** — review, optimize, find bugs, check security before merge

---

## Example

New Inventory System

Step 1  
Composer:  
Scan project and list files to touch.

Step 2  
GPT-5.6 Sol:  
Design the architecture.

Step 3  
Grok 4.5:  
Implement InventoryService.

Step 4  
Grok 4.5:  
Implement InventoryController.

Step 5  
Grok 4.5:  
Implement UI.

Step 6  
Composer:  
Update imports across the project.

Step 7  
GPT-5.6 Sol:  
Review the entire implementation before merge.

---

Cursor loads this automatically via `.cursor/rules/ai-model-usage.mdc`.
