#!/usr/bin/env bash
#
# CC-Unleashed Memorizer Hooks — Shared Library
#
# Sourced by all memorizer hooks. Provides JSON I/O, Memorizer MCP client,
# project ID resolution, token estimation, and file description extraction.
#
# Dependencies: jq, curl (already required by existing cc-unleashed hooks)
#

# ── Constants ────────────────────────────────────────────────────────────────

MEMORIZER_URL="https://memorizer.rlgeex.com/mcp"
MEMORIZER_TIMEOUT=3
PRJ_ROOT="${HOME}/prj"
PROJECT_CACHE="${HOME}/.claude/memorizer-project-cache.json"

# ── Directory & Guards ───────────────────────────────────────────────────────

get_memorizer_dir() {
  local project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  echo "${project_dir}/.memorizer"
}

# Exit 0 silently if .memorizer/ doesn't exist. Call at top of every hook
# except session-start (which creates it).
ensure_memorizer_dir() {
  local dir
  dir=$(get_memorizer_dir)
  [[ -d "$dir" ]] || exit 0
}

# ── Path Utilities ───────────────────────────────────────────────────────────

get_relative_path() {
  local abs_path="$1"
  local project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  echo "${abs_path#${project_dir}/}"
}

is_memorizer_path() {
  local rel
  rel=$(get_relative_path "$1")
  [[ "$rel" == .memorizer/* ]]
}

is_env_file() {
  local base
  base=$(basename "$1")
  [[ "$base" == ".env" || "$base" == .env.* ]]
}

# ── JSON I/O ─────────────────────────────────────────────────────────────────

# Atomic JSON write: write to temp file, then rename
write_json() {
  local file="$1"
  local content="$2"
  local dir tmp
  dir=$(dirname "$file")
  [[ -d "$dir" ]] || mkdir -p "$dir"
  tmp=$(mktemp "${file}.XXXXXX.tmp") || { echo "$content" > "$file" 2>/dev/null; return; }
  echo "$content" > "$tmp" 2>/dev/null && mv "$tmp" "$file" 2>/dev/null || {
    echo "$content" > "$file" 2>/dev/null
    rm -f "$tmp" 2>/dev/null
  }
}

# Read a JSON file, return fallback if missing/invalid
read_json() {
  local file="$1"
  local fallback="${2:-{}}"
  if [[ -f "$file" ]]; then
    jq '.' "$file" 2>/dev/null || echo "$fallback"
  else
    echo "$fallback"
  fi
}

# ── Token Estimation ─────────────────────────────────────────────────────────

# Estimate tokens from a file path. Uses byte count / ratio.
# Usage: estimate_tokens /path/to/file
estimate_tokens() {
  local file="$1"
  local bytes ext type ratio
  [[ -f "$file" ]] || { echo "0"; return; }
  bytes=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
  ext="${file##*.}"
  ext=".$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    .ts|.js|.tsx|.jsx|.py|.rs|.go|.java|.c|.cpp|.cs|.rb|.php|.swift|.kt|.lua|.zig|.css|.scss|.json|.yaml|.yml|.toml|.sql|.sh|.bash|.tf)
      ratio=35 ;;  # code: bytes * 10 / 35 ≈ bytes / 3.5
    .md|.mdx|.txt|.rst)
      ratio=40 ;;  # prose: bytes / 4.0
    *)
      ratio=38 ;;  # mixed: bytes / 3.75 (approx 3.8)
  esac
  echo $(( (bytes * 10 + ratio - 1) / ratio ))
}

# Estimate tokens from a string length
estimate_tokens_from_length() {
  local length="$1"
  local ratio="${2:-38}"
  echo $(( (length * 10 + ratio - 1) / ratio ))
}

# ── Timestamps ───────────────────────────────────────────────────────────────

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

time_short() {
  date +"%H:%M"
}

# ── Memorizer MCP Client ────────────────────────────────────────────────────
# Reuses the SSE parsing pattern from memory-retrieval.sh

call_memorizer() {
  local tool_name="$1"
  local args_json="$2"
  local timeout="${3:-$MEMORIZER_TIMEOUT}"
  local request response

  request=$(jq -n \
    --arg tool "$tool_name" \
    --argjson args "$args_json" \
    '{jsonrpc:"2.0",method:"tools/call",id:1,params:{name:$tool,arguments:$args}}')

  response=$(curl -s --max-time "$timeout" -X POST "$MEMORIZER_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "$request" 2>/dev/null) || return 1

  # Parse SSE: find first data: line, extract content text
  local content
  content=$(echo "$response" | grep '^data:' | head -1 | sed 's/^data: //' | jq -r '.result.content[0].text // empty' 2>/dev/null)

  # Fallback: try direct JSON (non-SSE)
  if [[ -z "$content" ]]; then
    content=$(echo "$response" | jq -r '.result.content[0].text // empty' 2>/dev/null)
  fi

  [[ -n "$content" ]] && echo "$content" || return 1
}

# ── Project ID Resolution ───────────────────────────────────────────────────

get_project_id() {
  local cwd="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  [[ "$cwd" == "${PRJ_ROOT}/"* ]] || return 1

  local relative="${cwd#${PRJ_ROOT}/}"
  local org project cache_key project_id
  org=$(echo "$relative" | cut -d'/' -f1)
  project=$(echo "$relative" | cut -d'/' -f2)
  cache_key="${org}/${project}"

  [[ -n "$project" ]] || return 1

  # Check cache
  if [[ -f "$PROJECT_CACHE" ]]; then
    project_id=$(jq -r --arg k "$cache_key" '.[$k] // empty' "$PROJECT_CACHE" 2>/dev/null)
    [[ -n "$project_id" ]] && { echo "$project_id"; return 0; }
  fi

  return 1
}

# Like get_project_id but falls back to Memorizer API lookup
get_project_id_with_fallback() {
  local cached
  cached=$(get_project_id 2>/dev/null) && { echo "$cached"; return 0; }

  local cwd="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  [[ "$cwd" == "${PRJ_ROOT}/"* ]] || return 1

  local relative="${cwd#${PRJ_ROOT}/}"
  local org project cache_key
  org=$(echo "$relative" | cut -d'/' -f1)
  project=$(echo "$relative" | cut -d'/' -f2)
  cache_key="${org}/${project}"
  [[ -n "$project" ]] || return 1

  local result project_id
  result=$(call_memorizer "get_project_context" "$(jq -n --arg q "$project" '{query:$q}')" 2>/dev/null) || return 1
  project_id=$(echo "$result" | grep -o 'ID:[[:space:]]*[0-9a-f-]\{36\}' | head -1 | sed 's/ID:[[:space:]]*//')
  [[ -n "$project_id" ]] || return 1

  # Cache it
  mkdir -p "$(dirname "$PROJECT_CACHE")"
  if [[ -f "$PROJECT_CACHE" ]]; then
    jq --arg k "$cache_key" --arg v "$project_id" '.[$k] = $v' "$PROJECT_CACHE" \
      > "${PROJECT_CACHE}.tmp" 2>/dev/null && mv "${PROJECT_CACHE}.tmp" "$PROJECT_CACHE"
  else
    jq -n --arg k "$cache_key" --arg v "$project_id" '{($k): $v}' > "$PROJECT_CACHE"
  fi

  echo "$project_id"
}

# ── Sync Queue ───────────────────────────────────────────────────────────────

queue_memorizer_sync() {
  local entry_json="$1"
  local queue_file
  queue_file="$(get_memorizer_dir)/sync-queue.json"

  if [[ -f "$queue_file" ]]; then
    local updated
    updated=$(jq --argjson entry "$entry_json" '.entries += [$entry]' "$queue_file" 2>/dev/null) || return
    write_json "$queue_file" "$updated"
  else
    write_json "$queue_file" "$(jq -n --argjson entry "$entry_json" '{entries:[$entry]}')"
  fi
}

# ── File Description Extractor ───────────────────────────────────────────────
# Simplified from OpenWolf extractDescription() — Tier 1 (known files) + Tier 2
# (docstrings, headings, comments) for ~15 languages. Covers ~80% of real files.

extract_description() {
  local file="$1"
  local base ext head_content desc

  [[ -f "$file" ]] || return

  base=$(basename "$file")
  ext="${base##*.}"
  ext=".$(echo "$ext" | tr '[:upper:]' '[:lower:]')"  # lowercase with dot

  # ── Tier 1: Known filenames ──────────────────────────────
  case "$base" in
    package.json)          echo "Node.js package manifest"; return ;;
    tsconfig.json)         echo "TypeScript configuration"; return ;;
    .gitignore)            echo "Git ignore rules"; return ;;
    README.md|readme.md)   echo "Project documentation"; return ;;
    Dockerfile)            echo "Docker container definition"; return ;;
    docker-compose.yml|docker-compose.yaml) echo "Docker Compose services"; return ;;
    Cargo.toml)            echo "Rust package manifest"; return ;;
    go.mod)                echo "Go module definition"; return ;;
    Gemfile)               echo "Ruby dependencies"; return ;;
    requirements.txt)      echo "Python dependencies"; return ;;
    pyproject.toml)        echo "Python project configuration"; return ;;
    setup.py)              echo "Python package setup"; return ;;
    setup.cfg)             echo "Python package configuration"; return ;;
    Makefile)              echo "Build automation"; return ;;
    .eslintrc.json|.eslintrc.js) echo "ESLint configuration"; return ;;
    .prettierrc|.prettierrc.json) echo "Prettier configuration"; return ;;
    jest.config.ts|jest.config.js) echo "Jest test configuration"; return ;;
    vitest.config.ts|vitest.config.js) echo "Vitest test configuration"; return ;;
    tailwind.config.ts|tailwind.config.js) echo "Tailwind CSS configuration"; return ;;
    next.config.js|next.config.mjs|next.config.ts) echo "Next.js configuration"; return ;;
    vite.config.ts|vite.config.js) echo "Vite build configuration"; return ;;
    webpack.config.js)     echo "Webpack build configuration"; return ;;
    schema.sql)            echo "Database schema"; return ;;
    composer.json)         echo "PHP package manifest"; return ;;
    pubspec.yaml)          echo "Dart/Flutter package manifest"; return ;;
    CLAUDE.md)             echo "Claude Code project context"; return ;;
    OPS.md)                echo "Operational context"; return ;;
    CHANGELOG.md)          echo "Change log"; return ;;
    LICENSE|LICENSE.md)     echo "License file"; return ;;
  esac

  # Read first 40 lines for pattern matching
  head_content=$(head -40 "$file" 2>/dev/null) || return
  [[ -n "$head_content" ]] || return

  # ── Tier 2: Language-aware extraction ────────────────────

  case "$ext" in
    # Markdown: first heading
    .md|.mdx)
      desc=$(echo "$head_content" | grep -m1 '^##\? ' | sed 's/^#* //')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;

    # Python: module docstring first line
    .py)
      desc=$(echo "$head_content" | sed -n '/^"""/{ s/^"""//; s/"""$//; /./{ p; q; }; n; /./{ p; q; }; }')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      desc=$(echo "$head_content" | sed -n "/^'''/{ s/^'''//; s/'''$//; /./{ p; q; }; n; /./{ p; q; }; }")
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;

    # TypeScript/JavaScript: JSDoc first line or first export
    .ts|.js|.tsx|.jsx|.mjs|.cjs)
      # Next.js conventions
      case "$base" in
        page.tsx|page.js) echo "Next.js page component"; return ;;
        layout.tsx|layout.js) echo "Next.js layout"; return ;;
        route.ts|route.js) echo "Next.js API route"; return ;;
      esac
      # JSDoc: /** first meaningful line */
      desc=$(echo "$head_content" | sed -n '/\/\*\*/{ n; s/^[[:space:]]*\*[[:space:]]*//; /^@/d; /./{ p; q; }; }')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      # First export
      desc=$(echo "$head_content" | grep -m1 'export.*\(function\|class\|const\|interface\|type\)' | sed 's/export //')
      [[ -n "$desc" ]] && { echo "Exports: ${desc:0:140}"; return; }
      ;;

    # Go: package comment
    .go)
      desc=$(echo "$head_content" | grep -m1 '// Package' | sed 's|^// ||')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;

    # Rust: doc comment
    .rs)
      desc=$(echo "$head_content" | grep -m1 '^\s*///\|^\s*//!' | sed 's|^[[:space:]]*//[/!][[:space:]]*||')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;

    # C#: XML doc summary or class name
    .cs)
      desc=$(echo "$head_content" | grep -m1 '<summary>' | sed 's/.*<summary>//; s/<\/summary>.*//' | sed 's/^[[:space:]]*//')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      desc=$(echo "$head_content" | grep -m1 'class [A-Z]' | sed 's/.*class /Class: /; s/[:{].*//')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;

    # Java: class + annotation
    .java)
      desc=$(echo "$head_content" | grep -m1 '@\(RestController\|Controller\|Service\|Repository\|Entity\)' | sed 's/^.*@//')
      local cls
      cls=$(echo "$head_content" | grep -m1 'class [A-Z]' | sed 's/.*class //; s/[{[:space:]].*//')
      if [[ -n "$desc" && -n "$cls" ]]; then
        echo "${desc}: ${cls}"
        return
      elif [[ -n "$cls" ]]; then
        echo "Class: ${cls}"
        return
      fi
      ;;

    # Terraform: resource/module names
    .tf)
      desc=$(echo "$head_content" | grep -m3 '^resource\|^module\|^data' | sed 's/[[:space:]]*{.*//' | tr '\n' ', ' | sed 's/, $//')
      [[ -n "$desc" ]] && { echo "Terraform: ${desc:0:140}"; return; }
      ;;

    # YAML: detect type (CI, K8s, Docker Compose)
    .yaml|.yml)
      if echo "$head_content" | grep -q 'runs-on:'; then
        desc=$(echo "$head_content" | grep -m1 '^name:' | sed 's/^name:[[:space:]]*//')
        echo "CI: ${desc:-GitHub Actions workflow}"
        return
      fi
      if echo "$head_content" | grep -q 'apiVersion:' && echo "$head_content" | grep -q 'kind:'; then
        desc=$(echo "$head_content" | grep -m1 'kind:' | sed 's/kind:[[:space:]]*//')
        echo "K8s ${desc}"
        return
      fi
      if echo "$head_content" | grep -q 'services:'; then
        echo "Docker Compose services"
        return
      fi
      ;;

    # SQL: CREATE TABLE names
    .sql)
      desc=$(echo "$head_content" | grep -io 'CREATE TABLE[[:space:]]*\(IF NOT EXISTS[[:space:]]*\)\?["`]\?\w\+' | head -3 | sed 's/.*TABLE[[:space:]]*\(IF NOT EXISTS[[:space:]]*\)\?["`]\?//' | tr '\n' ', ' | sed 's/, $//')
      [[ -n "$desc" ]] && { echo "SQL tables: ${desc:0:140}"; return; }
      ;;

    # Lua: function names
    .lua)
      desc=$(echo "$head_content" | grep -m5 '^function\|^local function' | sed 's/function //; s/(.*//' | tr '\n' ', ' | sed 's/, $//')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;

    # HTML: title tag
    .html|.htm)
      desc=$(echo "$head_content" | grep -io '<title>[^<]*</title>' | sed 's/<[^>]*>//g')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;

    # TOML: description field
    .toml)
      desc=$(echo "$head_content" | grep -m1 '^description' | sed 's/description[[:space:]]*=[[:space:]]*"//; s/"[[:space:]]*$//')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;

    # CSS/SCSS: rule count
    .css|.scss|.less)
      local rules vars
      rules=$(echo "$head_content" | grep -c '^[.#@]')
      vars=$(echo "$head_content" | grep -c '\-\-.*:')
      [[ $rules -gt 0 || $vars -gt 0 ]] && { echo "Styles: ${rules} rules, ${vars} vars"; return; }
      ;;

    # Shell scripts: first comment after shebang
    .sh|.bash|.zsh)
      desc=$(echo "$head_content" | sed -n '2,10{ /^#[[:space:]]/{ s/^#[[:space:]]*//; /./{ p; q; }; }; }')
      [[ -n "$desc" ]] && { echo "${desc:0:150}"; return; }
      ;;
  esac

  # ── Fallback: first meaningful header comment ────────────
  # Use grep to find first single-line comment that isn't boilerplate
  desc=$(echo "$head_content" | head -15 | grep -m1 '^\s*\(//\|#\|--\) ' | sed 's/^[[:space:]]*[/#-]*[/#-]*[[:space:]]*//')
  # Filter out boilerplate
  if [[ -n "$desc" ]]; then
    local lower
    lower=$(echo "$desc" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
      copyright*|license*|generated*|eslint-*|nolint*|strict*|'!'*) desc="" ;;
    esac
  fi
  [[ -n "$desc" && ${#desc} -gt 5 ]] && echo "${desc:0:150}"
}
