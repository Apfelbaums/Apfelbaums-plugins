# LLM-Friendliness Review

Follow the steps in order. Don't skip any.

---

## Step 1: Run automated checks

```bash
${CLAUDE_PLUGIN_ROOT}/audit.sh
```

---

## Step 2: While audit.sh runs — check semantics

audit.sh performs mechanical checks (grep, wc). You perform checks that require understanding.

### 2.1 CLAUDE.md ↔ reality

1. Read CLAUDE.md
2. Run `ls src/`
3. Verify:
   - [ ] Do described folders exist?
   - [ ] Are there folders not mentioned in documentation?
   - [ ] Do "Quick Start" commands work?
   - [ ] Are "Key Decisions" still accurate?
   - [ ] Are entry points listed? (handlers, jobs, CLI, routes)

4. Entry points check:
   ```bash
   ls src/handlers/ src/worker/jobs/ src/server/ 2>/dev/null
   ```
   Compare with what's described in CLAUDE.md. Are all entry points documented?

### 2.2 Code clarity (sample check)

Read 2-3 key files. For each, answer:
- [ ] Can you understand what the file does in 30 seconds?
- [ ] Are types sufficient to understand the API?
- [ ] Are there "magic" values without explanation?
- [ ] Do comments help or are they outdated?

### 2.3 Stale comments

For files with comments, verify:
- [ ] Does the comment match the code next to it?
- [ ] Are TODO/FIXME still relevant?
- [ ] Does JSDoc describe the current signature?
- [ ] Any "// old implementation" without code removal?

Examples of stale comments:
```typescript
// Returns user by ID  ← but function returns a list
function getUsers() { ... }

// TODO: add validation  ← but validation already exists below

/** @param id - user ID */  ← but parameter is named orderId
function getOrder(orderId: string) { ... }
```

### 2.4 Tests as documentation

Open 1-2 tests. Verify:
- [ ] Does the test show HOW to use the function?
- [ ] Are expected values clear?
- [ ] Are edge cases covered?

### 2.5 Fixtures and sample data

If tests/fixtures/ or similar exists:
- [ ] Do fixtures show realistic data?
- [ ] Is the expected data type clear?
- [ ] Are there examples for main entities (user, item, etc)?

If no fixtures:
- [ ] Where in tests are input data examples?
- [ ] Can you understand data shapes without reading code?

### 2.6 Architectural logic

- [ ] Is it clear where to find specific logic?
- [ ] Is there duplication between modules?
- [ ] Do dependencies flow in one direction?

### 2.7 Logging quality

Open 2-3 files with logs. Verify:
- [ ] Do logs contain context? (`log.info({ userId, action }, 'message')`)
- [ ] Are errors logged with enough info for debugging?
- [ ] Any sensitive data in logs (tokens, passwords)?

### 2.8 LLM Guardrails

Check for LLM instructions in CLAUDE.md:
- [ ] How to make commits? (conventional commits?)
- [ ] How to create PRs? (what to include in description?)
- [ ] When and how to run tests?
- [ ] How to do migrations?
- [ ] How to deploy? (or at least what NOT to do)

### 2.9 Hidden magic (check files from audit.sh)

audit.sh flags potential issues. You verify semantics:

For each singleton from audit.sh:
- [ ] Is this a justified singleton (DB pool, logger)?
- [ ] Or is it hidden state that should be injected?
- [ ] Is it documented in CLAUDE.md?

For each process.env:
- [ ] Should it be moved to centralized config.ts?
- [ ] Or is this a specific case (CLI flag)?

For each module-level let:
- [ ] Is this cache/memoization?
- [ ] Or hidden state breaking predictability?

### 2.10 Error message quality

Find 3-5 places where errors are thrown (`throw new Error`, `reject`, `log.error`).

For each, verify:
- [ ] Is the message clear without context?
- [ ] Does it contain data for debugging (ids, values)?
- [ ] Can you find the code location from the message?

Bad:
```typescript
throw new Error('Invalid input')
throw new Error('Failed')
```

Good:
```typescript
throw new Error(`User ${userId} not found in workspace ${workspaceId}`)
throw new Error(`Failed to process item ${itemId}: ${originalError.message}`)
```

### 2.11 Naming consistency

Check that same concepts are named the same everywhere:

- [ ] `user` vs `usr` vs `account` vs `member` — same thing?
- [ ] `item` vs `entry` vs `record` — consistent?
- [ ] `create` vs `add` vs `insert` — is there a convention?
- [ ] `get` vs `fetch` vs `load` vs `retrieve` — same meaning?

Command to search:
```bash
grep -rh "function \|const .* = " src/ | grep -oE "[a-z]+User|[a-z]+Item|[a-z]+Entry" | sort | uniq -c | sort -rn
```

### 2.12 API intuitiveness

Pick 3 public functions. Try to guess what they do ONLY from the signature:

```typescript
// Can you guess what this does?
function process(data: unknown): Promise<Result>  // ❌ no
function processInboxItem(item: InboxItem): Promise<ProcessedItem>  // ✓ yes
```

For each function:
- [ ] Does the name say WHAT it does?
- [ ] Are parameters clear without reading code?
- [ ] Is the return type clear?
- [ ] Are side effects obvious from the signature?

### 2.13 Single responsibility

For each module in src/:

1. Describe in one sentence what the module does
2. If you need "and" — it's a red flag:
   - ❌ "Handles users AND sends emails"
   - ✓ "Manages inbox item lifecycle"

Verify:
- [ ] Does each file do one thing?
- [ ] Can the module be replaced without changing others?
- [ ] Does the module name match its contents?

### 2.14 Semantic code duplication

Look for NOT copy-paste, but similar logic in different places:

- [ ] Similar validations in different handlers?
- [ ] Same data transformations?
- [ ] Repeating error handling patterns?
- [ ] Similar SQL/DB queries?

If found:
```
DUPLICATION: src/handlers/a.ts:50 and src/handlers/b.ts:30
  — both validate userId the same way
  — extract to shared validator
```

### 2.15 Dependency direction

Verify dependencies flow in the correct direction:

```
HIGH-LEVEL (business logic)
    ↓ depends on
LOW-LEVEL (utilities, DB, external APIs)
```

Red flags:
- [ ] Does `src/db/` import from `src/handlers/`?
- [ ] Does `src/lib/` import from `src/services/`?
- [ ] Does a utility know about business entities?

Command to check:
```bash
grep -r "from.*handlers\|from.*services" src/lib/ src/db/ src/utils/
```

Correct:
```
handlers → services → db → lib
     ↘      ↓        ↓
        lib/utils (shared)
```

### 2.16 Example verification

Find code examples in documentation (CLAUDE.md, README, JSDoc).

For each example:
- [ ] Is the code syntactically correct?
- [ ] Do imports exist?
- [ ] Do functions/types still exist with this signature?
- [ ] Does the example reflect the current API?

Common problems:
```typescript
// Docs say:
import { processItem } from './services'  // ← function renamed
processItem(data)  // ← signature changed

// Actually now:
import { processInboxItem } from './services/inbox'
processInboxItem(item, { validate: true })
```

### 2.17 Dead code (semantic)

Look for code that will never execute (grep won't find this):

- [ ] Conditions that are always true/false?
- [ ] Code after return/throw?
- [ ] Switch branches impossible by types?
- [ ] Functions that are never called?
- [ ] Feature flags that are always off?

Examples:
```typescript
// Always true (status is definitely in enum)
if (status === 'pending' || status === 'done' || status === 'failed') { ... }

// Unreachable code
function process() {
  return result
  console.log('done')  // ← never executes
}

// Unused export
export function legacyHandler() { ... }  // ← never imported
```

### 2.18 Business logic clarity

Pick 2-3 key business functions. Try to understand WHAT they do without comments:

For each function:
- [ ] Is the business meaning clear from the code?
- [ ] Do variable names reflect the domain?
- [ ] Are algorithm steps obvious?
- [ ] Can you explain the logic to a colleague in 1 minute?

Red flags:
```typescript
// Unclear what's happening
const x = data.filter(d => d.s === 1).map(d => ({ ...d, f: d.f + 1 }))

// Clear
const activeItems = items.filter(item => item.status === ItemStatus.Active)
const withIncrementedPriority = activeItems.map(item => ({
  ...item,
  priority: item.priority + 1
}))
```

---

## Step 2.5: Launch parallel agents for deep review

While working on the main review, launch two agents:

### Agent 1: Semantic Magic Scan

```
Task(subagent_type="Explore", prompt="""
Read 3-5 key project files (handlers, services, jobs).

For each file answer:
1. Can I understand function dependencies ONLY from its signature?
2. Is there code that executes on import (side effects)?
3. Do functions read state that's not in parameters?

Output a list of issues in format:
- MAGIC: src/file.ts:123 — function X reads global Y
""")
```

### Agent 2: Trace Flow

```
Task(subagent_type="Explore", prompt="""
Pick one main handler or job from src/.

Try to understand what it needs to work:
1. What dependencies are needed?
2. Where does data come from?
3. Where does the result go?

If you had to read >5 files to understand the flow → it's a problem.

Output:
- File: src/handlers/X.ts
- Dependencies: N
- Files had to read: M
- Issues: [list]
""")
```

Add agent results to TodoWrite in step 3.

---

## Step 3: Create TodoWrite from results

Combine audit.sh results + your semantic checks.

```
TodoWrite:
# From audit.sh
- [ ] FIX: CLAUDE.md not found
- [ ] FIX: 5 files > 300 lines
- [ ] WARN: No README in src/ subdirs

# From semantic checks
- [ ] FIX: CLAUDE.md doesn't match src/ structure
- [ ] WARN: src/utils/helpers.ts unclear without context
- [ ] WARN: tests don't show how to use API
```

---

## Step 4: Fix issues by priority

### Priority 1: FAIL — fix immediately

---

#### FAIL: CLAUDE.md not found

**Why critical:** LLM doesn't know where to start, wastes time on exploration.

**How to fix:**
1. Create `CLAUDE.md` in project root
2. Add at minimum:
   - What this project is (1-2 sentences)
   - src/ folder structure
   - How to run (npm install, npm run dev)
   - Where main logic is
   - Key conventions (naming, patterns)

```markdown
# Project Name

One-line description.

## Structure
- src/handlers/ — incoming requests
- src/services/ — business logic
- src/db/ — database access

## Quick Start
npm install && npm run dev

## Key Decisions
- Why we chose X over Y
```

---

#### FAIL: Too many large files (> 300 lines)

**Why critical:** LLM loses context in long files.

**How to fix:**
1. Open file from audit.sh output
2. Find logical blocks:
   - Groups of related functions
   - Different responsibilities
3. For each block:
   - Create new file: `originalName.part.ts` or by meaning
   - Move functions
   - Add exports to index.ts if needed
4. Verify imports work

---

#### FAIL: Too many 'any' types (> 5)

**Why critical:** LLM can't understand data structures, makes mistakes.

**How to fix:**
1. Find: `grep -rn ": any" --include="*.ts" src/`
2. For each:
   - Determine real type from usage
   - Create interface/type if complex
   - Use `unknown` + type guard if type is truly unknown

```typescript
// Before
function process(data: any) { ... }

// After
interface InputData {
  id: string
  payload: Record<string, unknown>
}
function process(data: InputData) { ... }
```

---

#### FAIL: No exported types

**Why critical:** LLM can't understand module API without reading all code.

**How to fix:**
1. For each module in src/:
   - Define public API (what's used externally)
   - Create types.ts or add to index.ts
   - Export input/output interfaces

```typescript
// src/services/types.ts
export interface CreateUserInput {
  email: string
  name: string
}

export interface CreateUserResult {
  id: string
  createdAt: Date
}
```

---

#### FAIL: No test files

**Why critical:** LLM can't understand expected behavior.

**How to fix:**
1. Create `tests/` folder
2. For each critical module write at least 1 test
3. Test should show:
   - How to call the function
   - What input → what output
   - Edge cases

---

#### FAIL: Vague commit messages

**Why critical:** LLM can't understand change history.

**How to fix:**
1. Start using conventional commits:
   ```
   feat(auth): add password reset flow
   fix(api): handle timeout errors in fetch
   docs: update CLAUDE.md with new structure
   ```
2. Each commit answers "what and why"

---

### Priority 2: WARN — fix today

---

#### WARN: CLAUDE.md too short

**How to fix:**
1. Open CLAUDE.md
2. Add sections:
   - Architecture overview
   - Key files and their roles
   - Conventions (naming, error handling)
   - Common tasks and how to do them

---

#### WARN: No README in src/ subdirectories

**How to fix:**
1. For each folder in src/:
   ```bash
   echo "# ModuleName\n\nWhat this module does.\n\n## Key files\n- file.ts — description" > src/moduleName/README.md
   ```
2. Describe:
   - Module purpose
   - Key files
   - How to use

---

#### WARN: Changelog outdated

**How to fix:**
1. Open `docs/changelog.md`
2. Add section:
   ```markdown
   ## YYYY-MM-DD
   - feat: what was added
   - fix: what was fixed
   - refactor: what was reworked
   ```

---

#### WARN: No .env.example

**How to fix:**
1. Copy .env to .env.example
2. Replace values with placeholders:
   ```
   DATABASE_URL=postgresql://user:pass@localhost:5432/db
   API_KEY=your_api_key_here
   ```

---

#### WARN: Vague function names

**What to look for:**
- Bare `process()`, `handle()`, `run()`, `execute()`, `do()`, `go()`
- Generic: `processData()`, `handleItem()`, `getData()`, `getInfo()`, `getResult()`
- Arrow: `const getData = `, `const processItem = `

**How to fix:**
1. Find function from audit.sh output
2. Determine WHAT exactly it processes
3. Rename with context:

```typescript
// Before
function process(item) { ... }
const getData = () => { ... }
function handle(event) { ... }

// After
function processInboxItem(item: InboxItem) { ... }
const getChunkData = () => { ... }
function handleTelegramCallback(event: CallbackQuery) { ... }
```

**Rule:** Function name should answer "what does it do?" without reading code.

---

#### WARN: Few exported types

**How to fix:**
1. For each public module add type exports
2. Minimum: Input and Output for each public function

---

#### WARN: Mixed file naming

**How to fix:**
1. Choose one style: camelCase or kebab-case
2. Rename files for consistency
3. Update imports

---

#### WARN: No git hooks

**How to fix:**
```bash
npm install -D husky
npx husky init
echo "npm run lint && npm run typecheck" > .husky/pre-commit
echo "npm test" > .husky/pre-push
```

---

#### WARN: Modules without tests

**How to fix:**
1. For each module without tests create `tests/unit/moduleName.test.ts`
2. Write at least 1 test showing the main use case

---

#### WARN: Deep nesting (4+ levels)

**How to fix:**
1. Find lines with deep nesting
2. Use early returns:

```typescript
// Before
function process(data) {
  if (data) {
    if (data.items) {
      for (const item of data.items) {
        if (item.active) {
          // logic
        }
      }
    }
  }
}

// After
function process(data) {
  if (!data?.items) return

  for (const item of data.items) {
    if (!item.active) continue
    // logic
  }
}
```

---

#### WARN: Abbreviations in variable names

**What to look for:** `usr`, `msg`, `ctx`, `cb`, `fn`, `val`, `obj`

**How to fix:**
```typescript
// Before
const msg = getMessage()
const ctx = createContext()
const cb = (err, res) => { ... }

// After
const message = getMessage()
const context = createContext()
const callback = (error, result) => { ... }
```

---

#### WARN: TODO/FIXME comments

**How to fix:**
1. For each TODO/FIXME:
   - If relevant → create GitHub issue, replace with `// TODO(#123): description`
   - If outdated → delete
   - If quick to fix → fix now

---

#### WARN: No JSDoc on exported functions

**How to fix:**
Add JSDoc before each `export function`:

```typescript
/**
 * Processes inbox item and creates actions.
 * @param item - The inbox item to process
 * @returns Created actions or null if skipped
 */
export function processInboxItem(item: InboxItem): Action[] | null {
  // ...
}
```

---

#### WARN: Long lines (> 120 chars)

**How to fix:**
1. Break into multiple lines:

```typescript
// Before
const result = await someFunction(param1, param2, param3, param4, { option1: true, option2: false, option3: 'value' })

// After
const result = await someFunction(
  param1,
  param2,
  param3,
  param4,
  { option1: true, option2: false, option3: 'value' }
)
```

---

### Priority 3: Semantic issues (from step 2 and agents)

---

#### MAGIC: Unjustified singleton

**How to fix:**
1. If singleton is needed (DB, logger) → document in CLAUDE.md:
   ```markdown
   ## Global State
   - `db` — Drizzle instance (src/db/index.ts)
   ```
2. If not needed → refactor to factory:
   ```typescript
   // Before
   export const cache = new CacheService()

   // After
   export function createCacheService(): CacheService {
     return new CacheService()
   }
   ```

---

#### MAGIC: process.env outside config

**How to fix:**
1. Create/update `src/config.ts`:
   ```typescript
   import { z } from 'zod'

   const envSchema = z.object({
     DATABASE_URL: z.string(),
     API_KEY: z.string(),
   })

   export const config = envSchema.parse(process.env)
   ```
2. Replace `process.env.X` with `config.X`
3. Validation at startup → errors visible immediately

---

#### MAGIC: Hidden state (module-level let)

**How to fix:**
1. If it's cache → make explicit:
   ```typescript
   // Before (hidden)
   let cache: Map<string, Data>

   // After (explicit)
   export const dataCache = {
     store: new Map<string, Data>(),
     get(key: string) { ... },
     set(key: string, data: Data) { ... },
   }
   ```
2. If it's state → inject through parameters
3. Document in CLAUDE.md if unavoidable

---

#### MAGIC: Side effects on import

**How to fix:**
1. Find code that executes on import
2. Move to explicit initialization:
   ```typescript
   // Before (side effect)
   console.log('Module loaded')
   setupGlobalHandlers()

   // After (explicit)
   export function initModule() {
     console.log('Module loaded')
     setupGlobalHandlers()
   }
   ```
3. Call `initModule()` in entry point

---

#### SEMANTIC: CLAUDE.md doesn't match reality

**How to fix:**
1. Update folder structure in CLAUDE.md
2. Remove mentions of non-existent modules
3. Add new folders with descriptions
4. Verify "Quick Start" — commands should work

---

#### SEMANTIC: File unclear without context

**How to fix:**
1. Add comment at file start: what it does, when it's used
2. Rename file if name doesn't reflect contents
3. Split into parts if doing too much
4. Add types for public functions

---

#### SEMANTIC: Tests don't show usage

**How to fix:**
1. Rename tests: `it('returns user by id')` instead of `it('works')`
2. Use realistic data in fixtures
3. Add tests for main use cases
4. Comment `// Setup → Action → Assert` if flow is unclear

---

#### SEMANTIC: Unclear architecture

**How to fix:**
1. Add `docs/architecture.md` with dependency diagram
2. Or add "Architecture" section to CLAUDE.md
3. README.md in each src/ folder with module purpose

---

## Step 5: Re-run audit.sh

```bash
${CLAUDE_PLUGIN_ROOT}/audit.sh
```

**Success criteria:**
- 0 FAIL
- < 3 WARN

If not achieved — return to step 4.

---

## Step 6: Report to user

Format:
```
## LLM-Friendliness Review Complete

**Result:** X passed, Y warnings, 0 failed

**Fixed:**
- [x] description of what was done

**Remaining (minor):**
- [ ] what's not critical

**Recommendations:**
- what to improve in the future
```

---

## Quick commands (reference)

```bash
# Full audit
${CLAUDE_PLUGIN_ROOT}/audit.sh

# Individual checks
find src -name "*.ts" -exec wc -l {} + | awk '$1 > 300'     # large files
grep -rn ": any" --include="*.ts" src/                       # any types
grep -r "^export type\|^export interface" --include="*.ts" src/ | wc -l  # type exports
grep -rn "function process(\|function handle(" --include="*.ts" src/     # vague names
find src -mindepth 2 -maxdepth 2 -name "README.md"          # README in subfolders
```
