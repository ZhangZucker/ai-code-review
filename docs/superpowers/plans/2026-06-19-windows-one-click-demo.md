# Windows One-Click Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Windows double-click demo that automatically prepares Java and Git, creates a two-commit sample repository, runs the real AI code-review SDK, pushes the report, and sends the WeChat notification.

**Architecture:** A tiny batch file launches one PowerShell orchestrator. The orchestrator reads an ignored local configuration, resolves or downloads portable tools, creates a deterministic sample Git repository, injects the SDK environment variables, captures the Java process output, and validates success from log markers. Python standard-library tests verify the repository package structure and the safety-critical script contracts without requiring Windows or real secrets.

**Tech Stack:** Windows Batch, Windows PowerShell 5.1, Python `unittest`, Git, Java 11, GitHub Releases API, Eclipse Adoptium API

---

### Task 1: Define the demo package contract with failing tests

**Files:**
- Create: `tests/test_windows_demo.py`
- Create later: `demo/一键演示.bat`
- Create later: `demo/run-demo.ps1`
- Create later: `demo/demo-config.example.ps1`
- Create later: `demo/assets/initial/src/main/java/demo/UserService.java`
- Create later: `demo/assets/changed/src/main/java/demo/UserService.java`

- [ ] **Step 1: Write tests for required files and launcher behavior**

Create `tests/test_windows_demo.py` with `unittest` cases that assert:

- all delivery files exist;
- the batch launcher uses `powershell.exe`, bypasses execution policy only for the child process, invokes `run-demo.ps1`, and pauses on return;
- the example configuration contains every required SDK setting plus official Java, Git, and SDK download settings;
- `run-demo.ps1` never embeds a token-like value, never prints secret values, supports `-SelfTest`, creates two commits, checks for a non-empty diff, sets every required environment variable, and checks the three success/error log markers;
- initial and changed Java files are different and the changed file contains the intended review issues.

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
python3 -m unittest tests/test_windows_demo.py -v
```

Expected: failures report missing `demo/` delivery files.

### Task 2: Implement the one-click Windows runner

**Files:**
- Create: `demo/一键演示.bat`
- Create: `demo/run-demo.ps1`
- Create: `demo/demo-config.example.ps1`
- Modify: `.gitignore`

- [ ] **Step 1: Add the launcher and safe configuration template**

The batch launcher must:

```bat
@echo off
chcp 65001 >nul
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-demo.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
echo.
pause
exit /b %EXIT_CODE%
```

The example configuration must return a hashtable with the required GitHub, ChatGLM, WeChat, project metadata, official download endpoints, and an optional local JAR path.

- [ ] **Step 2: Implement reusable PowerShell helpers**

Implement focused functions for:

- colored stage output and fatal errors;
- required configuration validation without printing values;
- retrying downloads;
- Java version detection and portable Temurin JRE extraction;
- Git detection and portable MinGit extraction using the official GitHub latest-release API;
- SDK JAR resolution from local path or configured URL;
- safe directory recreation;
- native command execution with exit-code checking.

`-SelfTest` must validate configuration shape and print `SELF_TEST_OK` without downloading tools or contacting external services.

- [ ] **Step 3: Implement the real demo flow**

The script must:

- recreate `demo/work/sample-project`;
- copy initial Java assets and create the first Git commit;
- replace them with changed assets and create the second commit;
- verify `git rev-list --count HEAD` equals `2`;
- save and display `git diff --stat HEAD^ HEAD`;
- set all SDK environment variables only for the current process;
- copy the JAR into the temporary repository and run it there;
- tee combined output to a timestamped log;
- fail if `openai-code-review error` is present;
- require `git commit and push done`, `weixin template message`, and `openai-code-review done`;
- display the log-repository URL and pause via the batch launcher.

- [ ] **Step 4: Ignore local secrets and runtime state**

Append:

```gitignore
/demo/demo-config.ps1
/demo/runtime/
/demo/work/
/demo/lib/*.jar
```

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```bash
python3 -m unittest tests/test_windows_demo.py -v
```

Expected: all tests pass.

### Task 3: Add deterministic demo code and operator documentation

**Files:**
- Create: `demo/assets/initial/src/main/java/demo/UserService.java`
- Create: `demo/assets/changed/src/main/java/demo/UserService.java`
- Create: `demo/README.md`
- Modify: `README.md`

- [ ] **Step 1: Add the initial and changed Java samples**

The initial version must validate input, avoid embedded credentials, close resources with try-with-resources, and use one-pass lookup. The changed version must intentionally introduce a hard-coded password, null dereference, leaked reader, invalid numeric parsing, and nested-loop lookup so the AI report has clear talking points.

- [ ] **Step 2: Add a short preparation guide**

Document:

- copy `demo-config.example.ps1` to `demo-config.ps1`;
- fill the GitHub log repository, scoped token, ChatGLM, and WeChat settings;
- optionally place the built JAR at `demo/lib/openai-code-review-sdk-1.0.jar`;
- double-click `一键演示.bat`;
- perform one rehearsal on the actual Windows presentation computer;
- never commit or send `demo-config.ps1` outside the intended demo package.

- [ ] **Step 3: Link the demo from the project README**

Add a concise “Windows 一键答辩演示” section linking to `demo/README.md`.

- [ ] **Step 4: Run full verification**

Run:

```bash
python3 -m unittest discover -s tests -v
git diff --check
git status --short
```

Expected: all tests pass, no whitespace errors, and only intended demo/documentation changes are present.
