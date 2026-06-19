# AI Code Review Project Flowchart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a clear, editable project flowchart for new developers and save its Mermaid source, PNG preview, and Feishu Whiteboard-compatible OpenAPI JSON in the repository.

**Architecture:** Use one left-to-right Mermaid flowchart with three stage groups: trigger/preparation, SDK execution, and result delivery. Keep the normal path visually dominant and route failures from critical steps to one shared error exit matching `AbstractOpenAiCodeReviewService.exec()`.

**Tech Stack:** Mermaid, Lark Whiteboard CLI, PNG rendering, OpenAPI whiteboard JSON

---

### Task 1: Create the editable flowchart source

**Files:**
- Create: `diagrams/2026-06-19T230346/diagram.mmd`

- [ ] **Step 1: Check the renderer toolchain**

Run:

```bash
lark-cli --version
npx -y @larksuite/whiteboard-cli@^0.2.11 -v
```

Expected: both commands print a version and exit successfully.

- [ ] **Step 2: Write the Mermaid source**

Create `diagram.mmd` with a `flowchart LR` diagram containing:

- `push / PR / 本地运行`
- CI checkout, build, and environment injection
- `OpenAiCodeReview.main()` dependency assembly
- `AbstractOpenAiCodeReviewService.exec()` orchestration
- Git diff acquisition
- ChatGLM review generation
- report repository commit and push
- WeChat template notification
- success and shared error exits

Use subgraphs and class definitions to distinguish the three stages and external systems. Keep visible Chinese action labels within eight characters and place implementation names in edge labels or compact secondary text.

- [ ] **Step 3: Inspect the source**

Run:

```bash
sed -n '1,260p' diagrams/2026-06-19T230346/diagram.mmd
```

Expected: pure Mermaid syntax, no Markdown fence, placeholder, or unfinished label.

### Task 2: Render and visually review the preview

**Files:**
- Create: `diagrams/2026-06-19T230346/diagram.png`
- Modify if needed: `diagrams/2026-06-19T230346/diagram.mmd`

- [ ] **Step 1: Render PNG**

Run:

```bash
npx -y @larksuite/whiteboard-cli@^0.2.11 \
  -i diagrams/2026-06-19T230346/diagram.mmd \
  -o diagrams/2026-06-19T230346/diagram.png
```

Expected: exit code 0 and a non-empty PNG file.

- [ ] **Step 2: Review the image**

Open `diagram.png` and verify:

- the main path reads left to right;
- stage boundaries are obvious;
- labels do not overflow;
- connectors do not obscure nodes;
- the error path is visually secondary.

- [ ] **Step 3: Re-render after corrections**

If a visual issue exists, update `diagram.mmd` and rerun the render command. Stop after at most two correction rounds.

### Task 3: Generate the Feishu Whiteboard-compatible file

**Files:**
- Create: `diagrams/2026-06-19T230346/diagram.json`

- [ ] **Step 1: Convert Mermaid to OpenAPI JSON**

Run:

```bash
npx -y @larksuite/whiteboard-cli@^0.2.11 \
  -i diagrams/2026-06-19T230346/diagram.mmd \
  --to openapi \
  --format json \
  -o diagrams/2026-06-19T230346/diagram.json
```

Expected: exit code 0 and valid non-empty JSON.

- [ ] **Step 2: Validate all deliverables**

Run:

```bash
test -s diagrams/2026-06-19T230346/diagram.mmd
test -s diagrams/2026-06-19T230346/diagram.png
test -s diagrams/2026-06-19T230346/diagram.json
python3 -m json.tool diagrams/2026-06-19T230346/diagram.json
```

Expected: every command exits with code 0.

- [ ] **Step 3: Check repository changes**

Run:

```bash
git status --short
```

Expected: the implementation plan and the three diagram artifacts are present, with no unrelated tracked-file modifications.
