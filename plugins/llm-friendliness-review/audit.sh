#!/bin/bash
# LLM-Friendliness Audit Script
# Checks how LLM-friendly your codebase is

# Don't use set -e, as some checks may "fail" - that's expected

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS=0
WARN=0
FAIL=0

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_check() {
    echo -e "  ${YELLOW}▶${NC} $1"
}

print_pass() {
    echo -e "    ${GREEN}✓${NC} $1"
    ((PASS++))
}

print_warn() {
    echo -e "    ${YELLOW}⚠${NC} $1"
    ((WARN++))
}

print_fail() {
    echo -e "    ${RED}✗${NC} $1"
    ((FAIL++))
}

print_info() {
    echo -e "    ${BLUE}ℹ${NC} $1"
}

# ═══════════════════════════════════════════════════════════════
# DOCUMENTATION — can LLM understand the project?
# ═══════════════════════════════════════════════════════════════

print_header "DOCUMENTATION"

# CLAUDE.md
print_check "Entry point (CLAUDE.md)"
if [ -f "CLAUDE.md" ]; then
    CLAUDE_LINES=$(wc -l < "CLAUDE.md" | tr -d ' ')
    if [ "$CLAUDE_LINES" -gt 50 ]; then
        print_pass "CLAUDE.md exists ($CLAUDE_LINES lines)"
    else
        print_warn "CLAUDE.md exists but short ($CLAUDE_LINES lines) — add more context"
    fi
else
    print_fail "CLAUDE.md not found — LLM won't know where to start"
fi

# Entry points documented in CLAUDE.md
print_check "Entry points documented"
if [ -f "CLAUDE.md" ]; then
    # Look for entry point mentions: handlers, jobs, routes, endpoints, CLI
    ENTRY_KEYWORDS=$(grep -ci "handler\|endpoint\|route\|job\|worker\|cli\|entry point\|api" CLAUDE.md 2>/dev/null || echo "0")
    if [ "$ENTRY_KEYWORDS" -gt 5 ]; then
        print_pass "Entry points documented ($ENTRY_KEYWORDS mentions)"
    elif [ "$ENTRY_KEYWORDS" -gt 0 ]; then
        print_warn "Few entry point mentions ($ENTRY_KEYWORDS) — add handlers/jobs/routes section"
    else
        print_fail "No entry points documented — LLM won't know where requests go"
    fi
else
    print_info "Skip (no CLAUDE.md)"
fi

# LLM Guardrails in CLAUDE.md (instructions for LLM on PR/tests/releases)
print_check "LLM guardrails (PR/test/release instructions)"
if [ -f "CLAUDE.md" ]; then
    # Look for instructions: PR, commit, test, release, deploy, review
    GUARDRAIL_KEYWORDS=$(grep -ci "pull request\|PR\|commit\|test\|release\|deploy\|review\|migration" CLAUDE.md 2>/dev/null || echo "0")
    if [ "$GUARDRAIL_KEYWORDS" -gt 10 ]; then
        print_pass "Good guardrails coverage ($GUARDRAIL_KEYWORDS instructions)"
    elif [ "$GUARDRAIL_KEYWORDS" -gt 3 ]; then
        print_info "$GUARDRAIL_KEYWORDS guardrail mentions — consider adding more LLM instructions"
    else
        print_warn "Few guardrails — add PR/test/release instructions for LLM"
    fi
else
    print_info "Skip (no CLAUDE.md)"
fi

# README
print_check "README.md"
if [ -f "README.md" ]; then
    print_pass "README.md exists"
else
    print_warn "README.md not found"
fi

# Architecture docs
print_check "Architecture documentation"
if [ -f "docs/architecture.md" ]; then
    print_pass "docs/architecture.md exists"
else
    print_warn "No architecture docs — LLM won't understand structure"
fi

# README in src/ subfolders
print_check "README in src/ subdirectories"
SRC_DIRS=$(find src -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
README_COUNT=$(find src -mindepth 2 -maxdepth 2 -name "README.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SRC_DIRS" -eq 0 ]; then
    print_info "No subdirectories in src/"
elif [ "$README_COUNT" -gt 0 ]; then
    print_pass "$README_COUNT README files in src/ subdirs"
else
    print_warn "No README.md in src/ subdirs — add context for each module"
    find src -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -5 | while read dir; do
        print_info "Missing: $dir/README.md"
    done
fi

# Changelog freshness
print_check "Changelog freshness"
CHANGELOG=$(find . -maxdepth 2 -name "*changelog*" -o -name "*CHANGELOG*" 2>/dev/null | head -1)
if [ -n "$CHANGELOG" ] && [ -f "$CHANGELOG" ]; then
    DAYS_OLD=$(( ($(date +%s) - $(stat -f %m "$CHANGELOG" 2>/dev/null || stat -c %Y "$CHANGELOG" 2>/dev/null)) / 86400 ))
    if [ "$DAYS_OLD" -lt 7 ]; then
        print_pass "Changelog updated $DAYS_OLD days ago"
    else
        print_warn "Changelog is $DAYS_OLD days old — LLM won't know recent changes"
    fi
else
    print_warn "No changelog found"
fi

# .env.example
print_check "Environment documentation (.env.example)"
if [ -f ".env.example" ] || [ -f ".env.sample" ]; then
    print_pass ".env.example exists"
else
    print_warn "No .env.example — LLM can't set up environment"
fi

# ═══════════════════════════════════════════════════════════════
# CODE CLARITY — can LLM understand functions without implementation?
# ═══════════════════════════════════════════════════════════════

print_header "CODE CLARITY"

# File sizes
print_check "File sizes (< 300 lines)"
LARGE_FILES=$(find src -name "*.ts" -exec wc -l {} + 2>/dev/null | awk '$1 > 300 && !/total/ {print $2 ": " $1 " lines"}' | head -5)
LARGE_COUNT=$(find src -name "*.ts" -exec wc -l {} + 2>/dev/null | awk '$1 > 300 && !/total/' | wc -l | tr -d ' ')
if [ "$LARGE_COUNT" -eq 0 ]; then
    print_pass "No files > 300 lines"
elif [ "$LARGE_COUNT" -lt 3 ]; then
    print_warn "$LARGE_COUNT files > 300 lines — hard for LLM to hold in context"
    echo "$LARGE_FILES" | while read line; do
        print_info "$line"
    done
else
    print_fail "$LARGE_COUNT files > 300 lines — split them"
    echo "$LARGE_FILES" | while read line; do
        print_info "$line"
    done
fi

# Function sizes (approximate)
print_check "Function sizes"
# Look for functions > 50 lines (rough heuristic)
LONG_FUNCS=$(grep -rn "^[[:space:]]*\(export \)\?\(async \)\?function\|^[[:space:]]*\(export \)\?const.*= \(async \)\?(" --include="*.ts" src/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$LONG_FUNCS" -lt 50 ]; then
    print_pass "Reasonable number of functions ($LONG_FUNCS)"
else
    print_info "$LONG_FUNCS functions found — check manually for long ones"
fi

# Vague function names
print_check "Function naming (no vague names)"

# Temp file for collecting results
VAGUE_FILE=$(mktemp)

# 1. Bare process/handle without context
grep -rn "function process(" --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"
grep -rn "function handle(" --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"
grep -rn "const process = " --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"
grep -rn "const handle = " --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"

# 2. process/handle/get/do + ONLY generic noun (strictly with ( after)
grep -rn "function processData(\|function processItem(\|function processInfo(\|function processResult(" --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"
grep -rn "function handleData(\|function handleItem(\|function handleInfo(\|function handleResult(" --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"
grep -rn "function getData(\|function getItem(\|function getInfo(\|function getResult(" --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"
grep -rn "function doWork(\|function doProcess(\|function doSomething(\|function doStuff(" --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"

# 3. Arrow functions with vague names
grep -rn "const processData = \|const handleData = \|const getData = \|const doWork = " --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"
grep -rn "const processItem = \|const handleItem = \|const getItem = \|const getInfo = " --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"

# 4. Really bad names
grep -rn "function run(\|function execute(\|function do(\|function go(" --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"
grep -rn "const run = \|const execute = \|const do = " --include="*.ts" src/ 2>/dev/null >> "$VAGUE_FILE"

# Count unique
VAGUE_COUNT=$(sort -u "$VAGUE_FILE" | grep -v "^$" | wc -l | tr -d ' ')

if [ "$VAGUE_COUNT" -eq 0 ]; then
    print_pass "No vague function names"
else
    print_warn "$VAGUE_COUNT vague function names — LLM can't understand intent"
    sort -u "$VAGUE_FILE" | grep -v "^$" | head -5 | while read line; do
        print_info "$line"
    done
fi

rm -f "$VAGUE_FILE"

# any types
print_check "TypeScript 'any' usage"
ANY_COUNT=$(grep -r ": any" --include="*.ts" src/ 2>/dev/null | grep -v "// any:" | wc -l | tr -d ' ')
if [ "$ANY_COUNT" -eq 0 ]; then
    print_pass "No 'any' types"
elif [ "$ANY_COUNT" -lt 5 ]; then
    print_warn "$ANY_COUNT 'any' types — LLM can't understand data shapes"
else
    print_fail "$ANY_COUNT 'any' types — too many, fix them"
fi

# Exported types
print_check "Exported types (can LLM understand module API?)"
EXPORT_TYPES=$(grep -r "^export type\|^export interface" --include="*.ts" src/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$EXPORT_TYPES" -gt 10 ]; then
    print_pass "$EXPORT_TYPES exported types — good API documentation"
elif [ "$EXPORT_TYPES" -gt 0 ]; then
    print_warn "$EXPORT_TYPES exported types — add more for clarity"
else
    print_fail "No exported types — LLM can't understand module APIs"
fi

# Deep nesting (4+ levels = 16+ spaces with 4-space indent)
print_check "Deep nesting (< 4 levels)"
DEEP_NESTING=$(grep -rn "^[[:space:]]\{16,\}" --include="*.ts" src/ 2>/dev/null | grep -v "^\s*//" | grep -v "^\s*\*" | wc -l | tr -d ' ')
if [ "$DEEP_NESTING" -eq 0 ]; then
    print_pass "No deep nesting"
elif [ "$DEEP_NESTING" -lt 20 ]; then
    print_warn "$DEEP_NESTING lines with deep nesting — hard to follow"
else
    print_fail "$DEEP_NESTING lines deeply nested — refactor with early returns"
fi

# Abbreviations in code (as variable/parameter names)
print_check "Abbreviations in variable names"
ABBREV_FILE=$(mktemp)
# Look for variables and parameters with short names, excluding shebang, imports, common patterns
grep -rn "const usr\|let usr\|var usr\| usr:" --include="*.ts" src/ 2>/dev/null | grep -v "user" >> "$ABBREV_FILE"
grep -rn "const msg\|let msg\|var msg\| msg:" --include="*.ts" src/ 2>/dev/null | grep -v "message" >> "$ABBREV_FILE"
grep -rn "const ctx\|let ctx\|var ctx\| ctx:" --include="*.ts" src/ 2>/dev/null | grep -v "context" >> "$ABBREV_FILE"
grep -rn "const cb\|let cb\|var cb\| cb:" --include="*.ts" src/ 2>/dev/null | grep -v "callback" >> "$ABBREV_FILE"
grep -rn "const fn\|let fn\|var fn\| fn:" --include="*.ts" src/ 2>/dev/null | grep -v "function\|filename" >> "$ABBREV_FILE"
grep -rn "const val\|let val\|var val\| val:" --include="*.ts" src/ 2>/dev/null | grep -v "value\|valid\|interval" >> "$ABBREV_FILE"
grep -rn "const obj\|let obj\|var obj\| obj:" --include="*.ts" src/ 2>/dev/null | grep -v "object" >> "$ABBREV_FILE"
ABBREV_COUNT=$(sort -u "$ABBREV_FILE" | wc -l | tr -d ' ')
if [ "$ABBREV_COUNT" -eq 0 ]; then
    print_pass "No cryptic abbreviations in variable names"
elif [ "$ABBREV_COUNT" -lt 10 ]; then
    print_info "$ABBREV_COUNT potential abbreviations (check manually)"
else
    print_warn "$ABBREV_COUNT abbreviations — use full names for clarity"
    sort -u "$ABBREV_FILE" | head -3 | while read line; do
        print_info "$line"
    done
fi
rm -f "$ABBREV_FILE"

# TODO/FIXME/HACK comments
print_check "TODO/FIXME/HACK comments"
TODO_COUNT=$(grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" src/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$TODO_COUNT" -eq 0 ]; then
    print_pass "No TODO/FIXME comments"
elif [ "$TODO_COUNT" -lt 10 ]; then
    print_info "$TODO_COUNT TODO/FIXME comments — consider resolving"
else
    print_warn "$TODO_COUNT TODO/FIXME comments — too many unresolved issues"
    grep -rn "TODO\|FIXME\|HACK" --include="*.ts" src/ 2>/dev/null | head -3 | while read line; do
        print_info "$line"
    done
fi

# JSDoc on public functions
print_check "JSDoc on exported functions"
# Count export function without preceding /** */
EXPORT_FUNCS=$(grep -c "^export function\|^export async function" src/**/*.ts 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
DOCUMENTED_FUNCS=$(grep -B1 "^export function\|^export async function" src/**/*.ts 2>/dev/null | grep -c "\*/")
if [ -z "$EXPORT_FUNCS" ] || [ "$EXPORT_FUNCS" -eq 0 ]; then
    print_info "No exported functions found"
elif [ "$DOCUMENTED_FUNCS" -gt $((EXPORT_FUNCS / 2)) ]; then
    print_pass "$DOCUMENTED_FUNCS/$EXPORT_FUNCS exported functions have JSDoc"
elif [ "$DOCUMENTED_FUNCS" -gt 0 ]; then
    print_warn "Only $DOCUMENTED_FUNCS/$EXPORT_FUNCS exported functions have JSDoc"
else
    print_warn "No JSDoc on exported functions — LLM has to read implementation"
fi

# Long lines
print_check "Line length (< 120 chars)"
LONG_LINES=$(find src -name "*.ts" -exec awk 'length > 120 {count++} END {print count+0}' {} + 2>/dev/null | awk '{sum += $1} END {print sum}')
if [ -z "$LONG_LINES" ] || [ "$LONG_LINES" -eq 0 ]; then
    print_pass "No lines > 120 characters"
elif [ "$LONG_LINES" -lt 50 ]; then
    print_info "$LONG_LINES lines > 120 chars — consider breaking up"
else
    print_warn "$LONG_LINES long lines — hard to read in context window"
fi

# Magic numbers (numbers without explanation)
print_check "Magic numbers"
# Look for numbers in conditions/arguments (not in constant declarations, not dates, not ports)
MAGIC_FILE=$(mktemp)
grep -rn "[\[( ,]\([2-9][0-9]\{2,\}\|[1-9][0-9]\{3,\}\)[^0-9a-zA-Z_]" --include="*.ts" src/ 2>/dev/null \
  | grep -v "const \|let \|var \|:\s*[0-9]\|//\|/\*\|\.test\.\|\.spec\." \
  | grep -v "config\|Config\|constant\|Constant\|pricing\|Pricing" \
  | grep -v "202[0-9]\|201[0-9]" \
  | grep -v "1000\|2000\|3000\|8080\|5432\|5000\|3001\|4000" \
  | grep -v "\.[0-9]\{2\}" \
  >> "$MAGIC_FILE"
MAGIC_COUNT=$(cat "$MAGIC_FILE" | wc -l | tr -d ' ')
if [ "$MAGIC_COUNT" -eq 0 ]; then
    print_pass "No magic numbers"
elif [ "$MAGIC_COUNT" -lt 15 ]; then
    print_info "$MAGIC_COUNT potential magic numbers — consider named constants"
else
    print_warn "$MAGIC_COUNT magic numbers — LLM won't understand their meaning"
    cat "$MAGIC_FILE" | head -3 | while read line; do
        print_info "$line"
    done
fi
rm -f "$MAGIC_FILE"

# Unhandled promises (potential hidden errors)
print_check "Potential unhandled promises"
# Look for async function calls without await (pattern: functionName( without await before)
# This is a heuristic — may give false positives
FLOATING_FILE=$(mktemp)
# Function call that returns Promise, without await and without .then/.catch
grep -rn "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*([^)]*)[[:space:]]*$" --include="*.ts" src/ 2>/dev/null \
  | grep -v "\.test\.\|\.spec\.\|function\|=>\|const\|let\|return\|await\|\.then\|\.catch" \
  >> "$FLOATING_FILE"
# Also look for void operators (often used to ignore promises)
VOID_COUNT=$(grep -rn "void [a-zA-Z]" --include="*.ts" src/ 2>/dev/null | grep -v "\.test\.\|\.spec\." | wc -l | tr -d ' ')
FLOATING_COUNT=$(cat "$FLOATING_FILE" | wc -l | tr -d ' ')
if [ "$FLOATING_COUNT" -eq 0 ] && [ "$VOID_COUNT" -lt 5 ]; then
    print_pass "No obvious unhandled promises"
elif [ "$VOID_COUNT" -gt 10 ]; then
    print_info "$VOID_COUNT 'void' operators — intentionally ignored promises"
else
    print_info "Check for unhandled promises via TypeScript strict mode"
fi
rm -f "$FLOATING_FILE"

# Type assertions (unsafe type casts)
print_check "Type assertions (as, !)"
# as Type — type cast
AS_COUNT=$(grep -rn " as [A-Z]" --include="*.ts" src/ 2>/dev/null | grep -v "\.test\.\|\.spec\.\|\.d\.ts" | wc -l | tr -d ' ')
# ! — non-null assertion
BANG_COUNT=$(grep -rn "[a-zA-Z0-9_)\]]\![.\[;,)]" --include="*.ts" src/ 2>/dev/null | grep -v "\.test\.\|\.spec\.\|!=\|!==" | wc -l | tr -d ' ')
TOTAL_ASSERTIONS=$((AS_COUNT + BANG_COUNT))
if [ "$TOTAL_ASSERTIONS" -eq 0 ]; then
    print_pass "No type assertions"
elif [ "$TOTAL_ASSERTIONS" -lt 20 ]; then
    print_info "$TOTAL_ASSERTIONS type assertions ($AS_COUNT 'as', $BANG_COUNT '!') — review for safety"
else
    print_warn "$TOTAL_ASSERTIONS type assertions — hidden type unsafety"
    print_info "  'as' casts: $AS_COUNT, non-null '!': $BANG_COUNT"
fi

# Dead code (commented code)
print_check "Commented-out code"
# Look for commented code blocks: // const, // function, // export, // import
COMMENTED_CODE=$(grep -rn "^[[:space:]]*//[[:space:]]*\(const\|let\|function\|export\|import\|class\|interface\|type\) " --include="*.ts" src/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$COMMENTED_CODE" -eq 0 ]; then
    print_pass "No commented-out code"
elif [ "$COMMENTED_CODE" -lt 10 ]; then
    print_info "$COMMENTED_CODE commented code blocks — consider removing"
else
    print_warn "$COMMENTED_CODE commented code blocks — dead code confuses LLM"
    grep -rn "^[[:space:]]*//[[:space:]]*\(const\|let\|function\|export\) " --include="*.ts" src/ 2>/dev/null | head -3 | while read line; do
        print_info "$line"
    done
fi

# Consistent logging style
print_check "Consistent logging style"
CONSOLE_LOGS=$(grep -rn "console\.log\|console\.error\|console\.warn" --include="*.ts" src/ 2>/dev/null | grep -v "\.test\.\|\.spec\." | wc -l | tr -d ' ')
LOGGER_CALLS=$(grep -rn "logger\.\|log\.\(info\|warn\|error\|debug\)" --include="*.ts" src/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$CONSOLE_LOGS" -eq 0 ]; then
    print_pass "No console.log in src/ — using proper logger"
elif [ "$CONSOLE_LOGS" -lt 5 ] && [ "$LOGGER_CALLS" -gt 10 ]; then
    print_info "$CONSOLE_LOGS console.log vs $LOGGER_CALLS logger calls — mostly consistent"
elif [ "$CONSOLE_LOGS" -gt "$LOGGER_CALLS" ]; then
    print_warn "More console.log ($CONSOLE_LOGS) than logger ($LOGGER_CALLS) — inconsistent logging"
else
    print_warn "$CONSOLE_LOGS console.log calls — consider using structured logger"
fi

# ═══════════════════════════════════════════════════════════════
# HIDDEN MAGIC — implicit dependencies and state
# ═══════════════════════════════════════════════════════════════

print_header "HIDDEN MAGIC"

# Singletons
print_check "Singletons (export const X = new Y)"
SINGLETON_FILE=$(mktemp)
grep -rn "export const .* = new " --include="*.ts" src/ 2>/dev/null >> "$SINGLETON_FILE"
SINGLETON_COUNT=$(cat "$SINGLETON_FILE" | wc -l | tr -d ' ')
if [ "$SINGLETON_COUNT" -eq 0 ]; then
    print_pass "No obvious singletons"
elif [ "$SINGLETON_COUNT" -lt 5 ]; then
    print_info "$SINGLETON_COUNT potential singletons — verify they're documented"
    cat "$SINGLETON_FILE" | head -3 | while read line; do
        print_info "$line"
    done
else
    print_warn "$SINGLETON_COUNT singletons — LLM can't understand hidden state"
    cat "$SINGLETON_FILE" | head -5 | while read line; do
        print_info "$line"
    done
fi
rm -f "$SINGLETON_FILE"

# Direct process.env usage (outside config files)
print_check "Direct process.env usage"
ENV_FILE=$(mktemp)
# Exclude: config files, comments (// and * after :linenum:)
grep -rn "process\.env\." --include="*.ts" src/ 2>/dev/null \
  | grep -vi "config\|env\.ts\|environment" \
  | grep -v ":[0-9]*:[[:space:]]*//" \
  | grep -v ":[0-9]*:[[:space:]]*\*" \
  | grep -v ":[0-9]*:.*/\*.*process\.env" \
  >> "$ENV_FILE"
ENV_COUNT=$(cat "$ENV_FILE" | wc -l | tr -d ' ')
if [ "$ENV_COUNT" -eq 0 ]; then
    print_pass "No direct process.env outside config"
elif [ "$ENV_COUNT" -lt 5 ]; then
    print_info "$ENV_COUNT direct env accesses — consider centralizing in config"
    cat "$ENV_FILE" | head -3 | while read line; do
        print_info "$line"
    done
else
    print_warn "$ENV_COUNT direct process.env — centralize in config.ts"
    cat "$ENV_FILE" | head -5 | while read line; do
        print_info "$line"
    done
fi
rm -f "$ENV_FILE"

# Global state modification
print_check "Global state (global/globalThis)"
GLOBAL_COUNT=$(grep -rn "global\.\|globalThis\." --include="*.ts" src/ 2>/dev/null | grep -v "\.d\.ts" | wc -l | tr -d ' ')
if [ "$GLOBAL_COUNT" -eq 0 ]; then
    print_pass "No global state modification"
else
    print_warn "$GLOBAL_COUNT global state usages — hidden dependency"
    grep -rn "global\.\|globalThis\." --include="*.ts" src/ 2>/dev/null | grep -v "\.d\.ts" | head -3 | while read line; do
        print_info "$line"
    done
fi

# Module-level mutable state (let at top level)
# Legitimate patterns: lazy init (_defaultDb), lifecycle (stopping), rate limiting, memoization
print_check "Module-level mutable state"
MUTABLE_FILE=$(mktemp)
grep -rn "^let \|^export let " --include="*.ts" src/ 2>/dev/null >> "$MUTABLE_FILE"
MUTABLE_COUNT=$(cat "$MUTABLE_FILE" | wc -l | tr -d ' ')
if [ "$MUTABLE_COUNT" -eq 0 ]; then
    print_pass "No module-level mutable state"
elif [ "$MUTABLE_COUNT" -lt 20 ]; then
    # Up to 20 — usually legitimate patterns (lazy init, graceful shutdown, rate limiting)
    print_info "$MUTABLE_COUNT module-level let — verify via semantic check"
else
    print_warn "$MUTABLE_COUNT module-level let — review for hidden state"
    cat "$MUTABLE_FILE" | head -5 | while read line; do
        print_info "$line"
    done
fi
rm -f "$MUTABLE_FILE"

# ═══════════════════════════════════════════════════════════════
# ARCHITECTURE — predictable structure?
# ═══════════════════════════════════════════════════════════════

print_header "ARCHITECTURE"

# Circular dependencies
print_check "Circular dependencies"
if command -v npx &> /dev/null; then
    CIRCULAR=$(npx madge --circular src/ 2>/dev/null)
    if echo "$CIRCULAR" | grep -q "No circular"; then
        print_pass "No circular dependencies"
    elif [ -z "$CIRCULAR" ]; then
        print_info "madge returned empty — check manually"
    else
        print_fail "Circular dependencies found — confuses LLM"
        echo "$CIRCULAR" | head -5 | while read line; do
            print_info "$line"
        done
    fi
else
    print_info "npx not found — skip circular deps check"
fi

# File naming consistency
print_check "File naming consistency"
# Check if there's a mix of camelCase and kebab-case
CAMEL_FILES=$(find src -name "*.ts" | grep -E "[a-z][A-Z]" | wc -l | tr -d ' ')
KEBAB_FILES=$(find src -name "*.ts" | grep -E "-" | wc -l | tr -d ' ')
if [ "$CAMEL_FILES" -gt 0 ] && [ "$KEBAB_FILES" -gt 0 ]; then
    print_warn "Mixed naming: $CAMEL_FILES camelCase, $KEBAB_FILES kebab-case files"
else
    print_pass "Consistent file naming"
fi

# Directory nesting depth
print_check "Directory depth"
MAX_DEPTH=$(find src -type f -name "*.ts" | awk -F'/' '{print NF}' | sort -n | tail -1)
if [ "$MAX_DEPTH" -lt 6 ]; then
    print_pass "Reasonable directory depth (max $MAX_DEPTH levels)"
else
    print_warn "Deep nesting ($MAX_DEPTH levels) — hard to navigate"
fi

# ═══════════════════════════════════════════════════════════════
# TESTS AS DOCUMENTATION
# ═══════════════════════════════════════════════════════════════

print_header "TESTS AS DOCUMENTATION"

# Fixtures / sample payloads
print_check "Fixtures and sample data"
FIXTURE_COUNT=0
# Look for: tests/fixtures/, fixtures/, __fixtures__, *.fixture.ts, sample*.json
if [ -d "tests/fixtures" ] || [ -d "fixtures" ] || [ -d "__fixtures__" ]; then
    FIXTURE_COUNT=$((FIXTURE_COUNT + 1))
fi
FIXTURE_FILES=$(find . -name "*.fixture.*" -o -name "*fixture*.ts" -o -name "*fixture*.json" -o -name "sample*.json" -o -name "*sample*.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
FIXTURE_COUNT=$((FIXTURE_COUNT + FIXTURE_FILES))
if [ "$FIXTURE_COUNT" -gt 5 ]; then
    print_pass "Good fixture coverage ($FIXTURE_COUNT fixtures/samples)"
elif [ "$FIXTURE_COUNT" -gt 0 ]; then
    print_warn "$FIXTURE_COUNT fixtures — add more sample data for LLM understanding"
else
    print_warn "No fixtures found — LLM can't see example data shapes"
fi

# Do tests exist at all
print_check "Tests exist"
TEST_COUNT=$(find . -name "*.test.ts" -o -name "*.spec.ts" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TEST_COUNT" -gt 20 ]; then
    print_pass "$TEST_COUNT test files — good coverage for understanding behavior"
elif [ "$TEST_COUNT" -gt 0 ]; then
    print_warn "$TEST_COUNT test files — add more to document behavior"
else
    print_fail "No test files — LLM can't learn expected behavior"
fi

# Tests for main modules
print_check "Tests for main modules"
SRC_MODULES=$(find src -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
MISSING_TESTS=""
for module in $SRC_MODULES; do
    if ! find tests -name "*${module}*" -type f 2>/dev/null | grep -q .; then
        MISSING_TESTS="$MISSING_TESTS $module"
    fi
done
if [ -z "$MISSING_TESTS" ]; then
    print_pass "All main modules have tests"
else
    print_warn "Modules without obvious tests:$MISSING_TESTS"
fi

# ═══════════════════════════════════════════════════════════════
# GIT HYGIENE
# ═══════════════════════════════════════════════════════════════

print_header "GIT HYGIENE"

# Git hooks
print_check "Git hooks configured"
if [ -d ".husky" ] || [ -f ".git/hooks/pre-commit" ]; then
    print_pass "Git hooks configured"
else
    print_warn "No git hooks — quality issues may slip through"
fi

# Recent commits quality
print_check "Recent commit messages"
BAD_COMMITS=$(git log --oneline -20 2>/dev/null | grep -E "^[a-f0-9]+ (fix|update|wip|test|changes|minor|stuff)$" | wc -l | tr -d ' ')
if [ "$BAD_COMMITS" -eq 0 ]; then
    print_pass "Commit messages are descriptive"
elif [ "$BAD_COMMITS" -lt 3 ]; then
    print_warn "$BAD_COMMITS vague commits in last 20 — LLM can't understand history"
else
    print_fail "$BAD_COMMITS vague commits — write meaningful messages"
fi

# Conventional commits
print_check "Conventional commits format"
CONVENTIONAL=$(git log --oneline -20 2>/dev/null | grep -E "^[a-f0-9]+ (feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?:" | wc -l | tr -d ' ')
if [ "$CONVENTIONAL" -gt 15 ]; then
    print_pass "Using conventional commits ($CONVENTIONAL/20)"
elif [ "$CONVENTIONAL" -gt 5 ]; then
    print_warn "Partial conventional commits ($CONVENTIONAL/20)"
else
    print_info "Not using conventional commits — consider adopting"
fi

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

print_header "SUMMARY"

TOTAL=$((PASS + WARN + FAIL))
echo ""
echo -e "  ${GREEN}Passed:${NC}   $PASS"
echo -e "  ${YELLOW}Warnings:${NC} $WARN"
echo -e "  ${RED}Failed:${NC}   $FAIL"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -lt 3 ]; then
    echo -e "  ${GREEN}✓ Codebase is LLM-friendly!${NC}"
elif [ "$FAIL" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠ Codebase needs minor improvements for LLM${NC}"
else
    echo -e "  ${RED}✗ LLM will struggle with this codebase — fix FAILs first${NC}"
fi

echo ""
echo -e "  ${BLUE}Tip:${NC} Run /llm-friendliness-review for step-by-step fixes"
echo ""
