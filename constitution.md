# SwarmForge Constitution

This file takes precedence over your role file where the two conflict.

Ported from github.com/unclebob/swarm-forge. The engineering rules are the
original. The handoff section is rewritten: there is one shared working tree
instead of a worktree per role, and no handoff scripts.

---

## Project Rules

Nothing here is preset. Work these out from the project itself.

- **Languages.** Read them off the project: its build files (`go.mod`, `bb.edn`,
  `deps.edn`, `pom.xml`, `package.json`, `pyproject.toml`, `Cargo.toml`, and so
  on) and the extensions of the files you touched. A project may have more than
  one. Where a rule below names a tool for "the language", it means the language
  of the files you touched.
- **Test command.** Work it out from the project. Prefer a command the project
  already defines — a `Makefile` target, a `package.json` script, a checked-in
  script — over one you compose yourself.
- **Verification command.** Same rule. This is the build, vet, lint, or type
  check the project already uses.
- **Record both commands in your handoff report**, exactly as you ran them. If
  the previous role's report already records them, use those and do not work them
  out again. The whole chain must run the same commands.
- If you cannot work out a command with confidence, **stop and ask the user**. Do
  not guess, and do not carry on without one. A wrong test command passes and
  hides broken work, which is worse than stopping.
- Do not change another role's file or ownership without explicit user direction.

---

## Engineering Rules

### Startup Tools

- On startup, procure the latest version of each required CRAP, mutation, and DRY tool directly from the listed `github.com/unclebob/...` repositories and get each one ready to run. Do this for every language you found in the project that has an entry in the table below.
- Resolve each listed repository at its latest available upstream version before installing or building it.
- Do not rely on stale cached, vendored, or preinstalled copies when a fresh GitHub install/build is possible in the current environment.
- Language tool table:
  - Go: install with `go install`; mutation `github.com/unclebob/mutate4go`, CRAP `github.com/unclebob/crap4go`, DRY `github.com/unclebob/dry4go`.
  - Clojure: install with Clojure CLI/deps.edn; mutation `github.com/unclebob/clj-mutate`, CRAP `github.com/unclebob/crap4clj`, DRY `github.com/unclebob/dry4clj`.
  - Java: install with Maven (`mvn`); mutation `github.com/unclebob/mutate4java`, CRAP `github.com/unclebob/crap4java`, DRY `github.com/unclebob/dry4java`.
- The table covers Go, Clojure, and Java only. A language with no entry has no CRAP, mutation, or DRY tool. Skip that tool for files in that language and say so in your report. Do not substitute another language's tool.
- When your change spans more than one language, run each language's tools over that language's files. Do not skip a language because another one passed.

### Language Defaults

- For Clojure projects, prefer Babashka where possible.
- For Clojure projects, prefer Speclj for unit and behavior tests.
- For Clojure or Babashka projects using Speclj, use `github.com/unclebob/speclj-structure-check` to validate test syntax. If a Speclj spec file changed, run the structure check before executing the relevant test command.
- For Java projects, avoid using Maven to run tests; build dedicated test runners and run those instead.

### Design And Testability

- Work in small, reviewable increments.
- Prefer the simplest design that supports the current behavior and leaves clear options for the next step.
- Keep tests close to the behavior being changed.
- Separate testable modules from environmentally unsuitable modules that open GUIs, depend on external devices, throw environment errors, emit system errors, or hang under automated tests. Maximize testable code and minimize the unsuitable boundary.
- Only testable modules should participate in tools that run tests, including unit tests, acceptance tests, coverage, mutation testing, CRAP analysis, DRY analysis that invokes tests, and property tests.
- Keep property tests separate from normal verification. Do not include property-test tags in normal unit coverage, Gherkin acceptance mutation, language mutation tools, CRAP, or coverage commands unless the role owns property-test verification or the user explicitly asks for property tests.

### Acceptance Pipeline

**This section does not apply to the 2-pack.** A 2-pack uses unit tests and
language-local verification only: no Gherkin, no IR, no acceptance tests, no
Gherkin mutation, no property tests.

- Use github.com/unclebob/Acceptance-Pipeline-Specification for Gherkin acceptance tests.
- The Acceptance Pipeline Specification supplies `gherkin-parser` and `gherkin-mutator`; install or build those commands from that repository instead of reimplementing them in the project.
- Prefer the Babashka APS tools. Use Go-based APS tools only if the Babashka APS tools do not work in the current project environment.
- Project-specific acceptance pipeline components are the acceptance entrypoint generator, acceptance runtime, project step handlers, runner adapter, and convenience scripts.
- Gherkin acceptance mutation means running `gherkin-mutator` to mutate Gherkin example values.
- Gherkin acceptance mutation runs must report periodic progress/status so agents can distinguish normal long-running work from a hang.

### Verification

- Before running language, build, or test commands, prefer project-local cache and configuration paths inside the project. Avoid default cache locations that write outside the project and may trigger sandbox or permission restrictions.
- Run acceptance generation and acceptance tests sequentially.
- Avoid running whole-suite language test commands concurrently with acceptance generation.
- Run the relevant local verification command before every handoff.
- Every role except the specifier must run unit tests and acceptance tests before handoff and fix any failures. In a 2-pack, unit tests only.
- The architect, hardener, and QA must run property tests before handoff when the project has them and fix any failures. A 2-pack has no property tests.

### Guardrails

- Do not edit mutation testing or Gherkin acceptance mutation manifests by hand; allow approved mutation tools to update those manifests as part of their normal runs.
- Do not commit unrelated local changes or generated artifacts unless required for the task.
- Before relying on an unfamiliar command, inspect local help or project documentation.

---

## Handoff Rules

You are one role in a chain. The role before you left a report; you leave one
for the role after you. There are no handoff scripts.

### Doing work

- Work the task you were given. Do not take work belonging to another role.
- Every role shares one working tree. Only touch files your role owns.
- Use `./tmp/` for temporary files, not `/tmp`.
- Include your role byline in every commit message, on its own last line, in this
  form: `By <role>.`

  ```text
  Implement handoff validation

  By coder.
  ```

### Handing off

1. Run the verification your role owns. Fix every failure before you go further.
2. Commit your work, with your byline. One commit per handoff. Leave no
   uncommitted changes behind — the next role must start from a clean tree.
3. Write a report to `docs/handoffs/<task>-<role>.md`, starting with the commit
   and the commands you ran. The commit is the one you just made — or, if you had
   nothing to commit, the commit you verified, which is the current `HEAD`.
   Either way the line names the commit the work now stands on:

   ```text
   commit: <10-character commit abbreviation>
   test:   <the exact test command you ran>
   verify: <the exact verification command you ran>
   ```

   These two commands are how the next role knows what to run. Copy them from the
   previous report when it has them. Omit a line only if your role runs no such
   command; the specifier runs neither.

   **Sending work back.** If what you found must be fixed by an *earlier* role —
   the work is wrong or missing, not merely improvable — add one more header
   line naming that role:

   ```text
   next:   coder
   ```

   The chain then resumes at that role and flows forward through you again. Say
   the same thing in your one-sentence message, because some hosts read the
   message and not the file. Name an **earlier** role in your own chain: never
   yourself, and never a later one — this is not a way to skip a role. Leave the
   line out of every ordinary handoff. Findings the next role can act on are not
   a reason to send work back — write them in the report and hand off normally.

   Then say, tersely: what state the work is in, what changed, and what the next
   role must check. No process narrative, no list of what you verified.
4. Tell the next role the report **path**, in one sentence. **Never paste the
   report body into a message.** Files carry detail; messages carry pointers.
   This is what keeps the other roles' context small.
5. Stop. Do not start the next role's work.

`docs/handoffs/` is handoff state, not project history, and it is ignored by git.
Write the report **after** the commit, never into it, and never stage or commit
that directory. If you find it in `git status`, something is wrong — say so.

Always hand off, even when nothing functional changed. Formatting-only and
generated-metadata churn still moves down the chain.

**Exception — the last role in the chain.** Instead of forwarding, it broadcasts
the report path to the earlier roles. Your role file says whether you send it.

Upstream swarm-forge gives each role its own worktree, so recipients of that
broadcast run a git merge. Here every role shares one working tree, so the commit
is already on your branch and there is nothing to merge. Receiving the broadcast
means: read the report, run your own verification once against the final commit,
and stop. Do not forward it. Do not start new work from it.

### Rules that keep the run cheap

- Do not report findings to the orchestrator. Report to the next role.
- Never declare a task done while tests fail.
- Keep every message under two sentences.

### When you are stuck

Stop and say so when you hit ambiguity, a contradiction, or a conflict between
the specification and the tests. Do not guess and do not work around it.

### How you are run

The mechanics differ by host and do not change any rule above.

- **Chain runner (`./swarm run`)**: you are one invocation of an agent CLI. Your
  task and the previous report path arrive in your prompt. Write your report and
  exit.
- **Claude Code agent team**: claim your task from the shared task list, send the
  pointer with `SendMessage`, then mark the task complete.
- **Native subagent (OpenCode, Antigravity, Codex)**: your caller passes the task
  and expects the report path back as your final answer.
