# SwarmForge for agent CLIs

A port of [unclebob/swarm-forge](https://github.com/unclebob/swarm-forge) from
tmux + Babashka handoff scripts to whatever your agent CLI already has.

No daemon, no worktrees, no tmux. The role text is written once and generated
into each CLI's own format.

> This lives on a branch of a **fork** of upstream, and carries no `LICENSE`
> file on purpose: the role prompts are 56–91% upstream's text, and upstream
> licenses nothing. Read [NOTICE.md](NOTICE.md) before copying this anywhere.

## Two variants, same swarm

In both, **the session you are already in is the orchestrator.** There is no
separate lead agent to install.

| | Team variant | Subagent variant |
| --- | --- | --- |
| Command | `/swarm 6 <task>` | `/swarm 6 <task>` (`/swarm-subagents` on Claude Code) |
| Roles run as | teammates, own context each | subagents of your session |
| Coordination | shared task list; roles message each other | your session invokes roles one at a time |
| Reports pass through you | no | yes — one line each |
| Runs on | Claude Code only | Claude Code, OpenCode, Antigravity, Codex, Copilot |

The team variant is better when it works: the roles hand off directly, so
nothing lands in your context at all. The subagent variant works everywhere but
every role's answer passes through you, which is why the command forces roles to
answer with a path and one sentence.

## Install

```sh
cd /path/to/your/project
/path/to/swarmforge/swarm install claude      # or opencode | agy | codex | copilot
```

That writes the six role subagents and the command(s) into the right places:

| CLI | Roles | Commands |
| --- | --- | --- |
| Claude Code | `.claude/agents/*.md` | `.claude/commands/swarm.md` (team) + `swarm-subagents.md` |
| OpenCode | `.opencode/agents/*.md` (`mode: subagent`) | `.opencode/commands/swarm.md` |
| Antigravity | `.agents/agents/*.md` (`subagent: true`) | `.agents/commands/swarm.md` |
| Codex | `.codex/agents/*.toml` | `.codex/prompts/swarm.md` |
| Copilot | `.github/agents/*.agent.md` | `.github/skills/swarm/SKILL.md` |

There is nothing to configure. The roles read the project's languages, test
command, and verification command off the project itself, and each role records
the two commands in its handoff report so the whole chain runs the same ones.

Then:

1. On Claude Code, merge `claude-settings.json` into `.claude/settings.json` and
   replace `/path/to/swarmforge` with your own path. It carries the agent-teams
   flag, which the team variant needs, and the two hooks that check a role
   actually committed before it finishes.
2. Run `/swarm 6 add a login flow`.

Generated files are disposable. Edit `roles/`, `commands/`, and
`constitution.md`, then re-run install.

## Project rules, and multi-language projects

The old version of this port had a **Project Rules** block in `constitution.md`
where you hand-wrote the language, the test command, and the verification
command. That is gone. A role already knows which files it touched, so it has
better information than a config line, and a config line goes stale.

Instead the constitution tells each role to read the project: the build files
for languages, and a command the project already defines — a `Makefile` target,
a `package.json` script, a checked-in script — for tests and verification.

**Roles record what they ran.** The handoff report starts with three lines:

```text
commit: a1b2c3d4e5
test:   go test ./...
verify: go vet ./... && go build ./...
```

The next role copies those and does not work them out again. That is what keeps
the chain consistent — role 1 deciding `make test` means role 6 runs `make test`
too, rather than each role guessing separately and getting different results.

**A role that cannot work out a command stops and asks you.** It is told not to
guess. A wrong test command passes and hides broken work, which is worse than
stopping.

**More than one language is handled by the same rule.** A role picks its CRAP,
DRY, and mutation tool by the language of the files it touched. The
constitution's tool table covers Go, Clojure, and Java only — those are the
languages Uncle Bob's tools exist for. For any other language the role skips
that tool and says so in its report, rather than reaching for a tool meant for a
different language. A change spanning two languages runs both toolchains.

**Java tests do not run through Maven.** The constitution says to build a
dedicated test runner in the project and run tests through that. It does not say
to skip Java tests. Maven may still build.

## The packs

| Pack | Roles | Use for |
| --- | --- | --- |
| `2` | coder, cleaner | Quick backend work. No spec step. |
| `4` | specifier, coder, cleaner, architect | Normal features with Gherkin specs. |
| `6` | specifier, coder, cleaner, architect, hardener, QA | Full pipeline with mutation testing and end-to-end QA. |

Edit `packs.conf` to change a chain.

### The packs are not subsets of each other

In upstream swarm-forge each branch has its own role prompts, and they diverge.
This port keeps that, two ways.

**Small differences are conditional sections inside a role file:**

- 4-pack specifier writes no end-to-end QA suite, runs five phases not six, and
  waits on the architect rather than QA.
- 4-pack cleaner fills the refactorer slot and also owns property testing.
- 4-pack architect absorbs the hardener's mutation and DRY work.

**Big differences are separate files**, `roles/<role>.<pack>.md`, which override
the default for that pack:

| File | Why it exists |
| --- | --- |
| `roles/coder.2.md` | The 2-pack coder owns no acceptance pipeline at all — no Gherkin, no IR, no CRAP, no DRY, no mutation. Unit tests only. |
| `roles/cleaner.2.md` | The 2-pack cleaner absorbs the architect *and* hardener: architecture rules plus mutation hardening. It does not own property tests. |

`swarm install` generates those as extra subagents named `coder-2pack` and
`cleaner-2pack`; both commands tell the orchestrator to use them for a 2-pack.
`swarm run 2` picks them up automatically.

### How each pack ends

| Pack | Ending |
| --- | --- |
| 2 | **A loop.** The cleaner hands back to the coder, which forwards to the cleaner again. It stops when the cleaner reports nothing left to fix. |
| 4 | **A merge-only broadcast.** The architect sends the report path to the coder and cleaner, and to the specifier only when there is a functional commit. If nothing functional changed, it broadcasts nothing at all. |
| 6 | **A merge-only broadcast.** QA sends the report path to all five other roles. |

Only the 2-pack loops. In the 4-pack and 6-pack the last role broadcasts
backwards, but recipients merge, verify, and stop — they do not forward it and
do not start new work from it. Upstream calls this the terminal broadcast, and
it is the one place the "always hand off" rule does not apply.

## A model per role

`packs.conf` sets the model each role uses:

```conf
model specifier opus
model coder     opus
model cleaner   sonnet
model architect opus
model hardener  sonnet
model QA        sonnet
```

Comment a line out and that role uses the CLI's default. The value is passed
through untouched, so use whatever string the backend expects — `opus`,
`gpt-5-codex`, `anthropic/claude-sonnet-5`.

The setting reaches the roles two ways. `swarm install` writes it into the
generated subagent file (`model:` in YAML, `model =` in Codex TOML), which is
what the team and subagent variants read. `swarm run` passes it as a command-line
flag instead. Re-run install after changing it.

Spend on the roles that reason — specifier, coder, architect. Save on the ones
that mostly run tools — cleaner, hardener, QA.

`swarm show 6` prints the chain with its backend and model.

### A different model for the same role in a different pack

Prefix the role with the pack. The prefixed line wins:

```conf
model coder     opus       # every pack
model 2.coder   sonnet     # the 2-pack only
```

`swarm run` and `swarm show` always honour this, because both are told the pack.

Installed subagents honour it only for a role that already has its own file per
pack — today that is `coder-2pack` and `cleaner-2pack`. Everywhere else install
writes one file per role: `coder.md` becomes a single `coder` agent used by both
the 4-pack and the 6-pack, and one file holds one `model:` value. There is
nowhere to put a second. Install prints a note naming any pack-scoped line it
could not honour.

The fix would be generating `coder-4pack` and `coder-6pack` as separate files —
8 role files become about 14 near-duplicates to vary one line of frontmatter.
Not done.

One caveat for the Claude Code **team** variant: a teammate's model is fixed when
it spawns, and `/model` in the lead does not change it. The value in the agent
file is the one that applies.

### Copilot

A Copilot custom agent cannot delegate to another custom agent, so the
orchestrator is **not** an agent. Same rule as every other CLI: the session you
start is the orchestrator, and it invokes the role agents as subagents.

Copilot has **no custom slash commands**, and is not getting them. The request
([copilot-cli#618][618]) is closed as completed, but read the resolution: GitHub's
answer was *"convert these into skills. We do not plan on supporting prompt files
given that they have been superseded by skills."* [#1113][1113] was closed as a
duplicate of it. So a closed issue here means "won't do, use skills", not
"shipped".

The orchestrator therefore installs as a skill at
`.github/skills/swarm/SKILL.md`, with `disable-model-invocation: true` so Copilot
never triggers it on its own — you invoke it by name, like a command. Two ways in:

```sh
swarm start copilot 6 "add a login flow"
copilot -p 'use the swarm skill: 6-pack, add a login flow'
```

The skill carries no `$1`/`$ARGUMENTS` placeholders — nothing expands them there
— so it asks for the pack and task in plain text. Copilot's `.agent.md`
frontmatter has no documented `model` field either, so per-role models reach
Copilot only through `swarm run`.

[618]: https://github.com/github/copilot-cli/issues/618
[1113]: https://github.com/github/copilot-cli/issues/1113

## Fallback: the shell chain

Any CLI can run the chain without a subagent system at all:

```sh
./swarm run 6 "add a login flow"      # one CLI call per role, in order
./swarm resume 6 "add a login flow"   # the same, skipping roles already done
./swarm show 6                        # print the chain, backends, and models
```

### How a role knows its pack

Several role files carry a section that applies only when another role is
absent — the specifier's "When the chain has no QA role", the architect's "When
the team has no hardener". A role cannot act on those unless it knows which
pack it is in, so `swarm run` states both the pack and the chain in every
prompt:

```text
You are the **architect** in the **4-pack**. The whole chain is:
specifier -> coder -> cleaner -> architect.
```

The chain is spelled out rather than just the pack number, so a pack you add
yourself to `packs.conf` works the same way without any role file mentioning it
by name. The two orchestrator variants pass the same fact as a pack adjustment
in the spawn prompt.

### The interactive role

Most roles run headless — one CLI call, no way to ask you anything. The
specifier cannot work that way. Its job is to settle ambiguity with you and get
your approval before the coder starts, so `packs.conf` marks it:

```
interactive specifier
```

`swarm run` then drops the headless flag for that role and hands it the
terminal. You talk to it, exit when the spec is right, and the chain carries on
headless from the coder. The banner tells you which mode a role got:

```text
=== 16:08:59 specifier [claude opus interactive] ===
=== 16:08:59 coder [claude opus] ===
```

The chain is a foreground loop running one role at a time, so the role simply
owns the terminal until you leave it. No tmux, no watchdog — there is only ever
one live role to look at.

Two fallbacks, both of which say so and then run the role headless:

- **The backend has no verified interactive form.** Only `claude` and `codex`
  are listed. The other three run headless.
- **There is no terminal** — CI, or `swarm run` called from inside another
  agent. `[ -t 0 ]` catches this; without the check an interactive CLI hangs.

In either case the role answers its own questions instead of asking you, so read
the `specifier` report before letting the chain go on.

`interactive <role>` matches by role name only, not by pack. `interactive coder`
would catch every pack's coder, not only the 2-pack one that asks
(`roles/coder.2.md`).

### When a run stops

`swarm run` checks two things after every role, because nothing else does:

- **The tree must be clean.** The constitution tells a role to leave no
  uncommitted changes. If it does anyway, the run stops. Otherwise the next role
  commits this role's work under its own byline.
- **The report must name a real commit.** It needs a `commit: <abbrev>` line that
  resolves. A missing or unusable report stops the run rather than handing the
  next role a path to nothing.

Either way the run stops with the exact command to continue:

```text
swarm: role 'hardener' left uncommitted changes. Commit or discard them,
       then: swarm resume 6 "add a login flow"
```

`swarm resume` walks the same chain and skips any role that already left a
report naming a commit **HEAD still stands on**. This is what stops a failure at
role 5 from costing you roles 1 through 4 again.

Two reports do not count as finished. A half-written one, with no commit line.
And one whose commit is no longer in the branch: if you recover from a bad run
with `git reset --hard`, the abandoned commits still resolve, but the work is
gone, so those roles run again rather than the chain building on a hole.

### The same check in the other two variants

The check is one subcommand, so all three variants run the same code:

```sh
swarm check <role> [report-path]
```

Without a report path it finds the role's own report and requires it to name the
**current `HEAD`**. That is what lets a hook check a role knowing only its name.
When a role finishes, `HEAD` is its commit. A role that never committed leaves
`HEAD` on the previous role's commit with no report of its own naming it. A role
that had nothing to commit still passes, because its report names the commit it
verified, which is `HEAD` unchanged.

**Claude Code enforces it with a hook.** Both entries are in
`claude-settings.json`; change `/path/to/swarmforge` to your own path:

| Variant | Hook | What exit 2 does |
| --- | --- | --- |
| Subagent | `SubagentStop` | the role cannot finish; it is pushed back to fix its own commit |
| Team | `TeammateIdle` | the teammate cannot go idle |

`swarm check-hook` reads the role name from the hook's JSON. It fires for **every**
subagent, not only ours, so anything that is not a swarm role exits 0 straight
away and gets out of the way.

**The other four CLIs get an instruction, not a gate.** `swarm-subagents.md` tells
the orchestrator to run `swarm check <role>` after each role and not to move on
until it passes. That is a prompt rule a model can skip. It is the same code and
a weaker guarantee — worth knowing which of the three you are relying on.

**If an orchestrator restarts**, `swarm next <pack> "<task>"` prints the first
role with no finished report, or `done`. It is the subagent-variant equivalent of
`swarm resume`.

## Running several swarms at once

**One swarm per working tree.** Every check is relative to the current directory:
`git status --porcelain` for the clean-tree rule, `HEAD` for the report rule. Two
swarms sharing a tree see each other's in-flight files as their own uncommitted
work, and both die at the first role.

Give each one a git worktree and they are fully independent — separate branch,
separate `docs/handoffs/`, separate log, separate resume:

```sh
d=$(/path/to/swarmforge/swarm worktree "add a login flow") && cd "$d"
/path/to/swarmforge/swarm run 6 "add a login flow"
```

`swarm worktree` is `git worktree add -b <slug> ../<slug>`, with the branch and
directory named from the task. It prints the path and nothing else, so it composes
into a `cd`. When you are done:

```sh
git checkout main && git merge add-a-login-flow
git worktree remove ../add-a-login-flow
```

Commit `.claude/` and every new worktree picks up the role agents and the hooks,
so `swarm install` only runs once.

`swarm run` is one process, so several of them fan out from a plain shell loop:

```sh
for t in "add login" "fix billing" "update docs"; do
  ( d=$(swarm worktree "$t") && cd "$d" && swarm run 6 "$t" ) &
done
wait
```

Each gets its own process, worktree, branch, reports and lock. They cannot see
each other. The real ceiling is your CLI's rate limit and your wallet: four
6-packs is twenty-four agent invocations at once.

**In the team and subagent variants the orchestrator handles this.** A subagent
starts in the main conversation's working directory, so the orchestrator asks,
before it spawns anything, whether to run here or in a worktree of its own, and
`cd`s there first. It also refuses to start when another swarm already holds this
tree.

**One session, one worktree, many related tasks.** An orchestrator takes a list
of tasks and runs one full chain per task, one at a time, all in the tree it
chose at the start. Each task gets its own task name, so reports never collide,
and each stays independently resumable. Commits stack on one branch in order,
which is what you want when task 2 builds on task 1.

It cannot run two chains at once — its subagents follow its single working
directory, and two swarms cannot share a tree. So a session is for one line of
related work. **Unrelated work belongs in a separate session**, which gets its
own worktree; both command files tell the orchestrator to refuse it and say so.
For genuinely parallel features, start one session per feature — Claude Code's
background agents view is built for watching several at once. The shell loop
above is the other way to get there.

The team variant gets a bonus here: the teammates stay up between tasks, so a
related follow-up costs one new set of tasks rather than a new team.

**Never set `isolation: worktree` on a role agent.** That gives each *role* its
own worktree branched from the default branch, so no role would ever see the
previous role's commit and the chain would silently produce nothing. Roles share
one tree. Whole swarms get separate ones.

**If you forget**, all three variants say so rather than letting you find out at
role 1:

```text
swarm: another swarm already owns this working tree (holder 4021, task feature-one).
       Two swarms cannot share a tree. Give this one its own:
         d=$(swarm worktree "feature two") && cd "$d" && swarm run 6 "feature two"
       If that swarm is gone, release the tree with: swarm unlock
```

The lock is `docs/handoffs/.running`. How it is released depends on who holds it:

- **`swarm run`** writes its own pid and removes the lock when it exits. A lock
  whose process is gone does not block, so a crashed run frees the tree by
  itself.
- **An orchestrator session** has no pid a shell can watch, so it claims the
  tree with `swarm lock "<task>"` and releases it with `swarm unlock`. Its lock
  holds until released. A session that dies without releasing leaves a stale
  lock; `swarm lock` names the holder and tells you to clear it with
  `swarm unlock`.

Both orchestrator command files carry the claim and the release as steps. Before
this existed, only `swarm run` ever wrote the lock, so two `/swarm` sessions in
one tree never saw each other — the check read a file nothing had written.

### Which parallelism this is

Upstream gives each **role** a worktree so six roles of one feature could run at
once — but they cannot, because each needs the previous one's commit, which is
why upstream still runs them in a chain. Here each **feature** gets a worktree,
and features genuinely are independent. Same native git feature, pointed at the
axis that actually has parallelism in it.

### The run log, and where the real audit trail is

Each run appends its banner to `docs/handoffs/<task>.log` — role, backend, model,
time, and how it ended. It is there so a **failed** role leaves a trace, because
a role that fails never commits.

For everything else, use git. Every role commits with a `By <role>.` byline:

```sh
git log --format='%h  %ad  %s' --date=short
```

That already has the order, the times, the role, and the actual diff. Upstream
needs its own timestamp headers because a daemon moves files between queues out
of order. Here the chain is linear, so a second audit trail would only duplicate
git.

`swarm start <cli> <pack> "<task>"` is the other entry point: one session
orchestrates and the roles run as its subagents, for hosts that cannot expand a
command file. `swarm run` is the opposite — no orchestrator at all, just the
chain.

The orchestrator has to ask the user where to run before it spawns anyone, so
`swarm start` hands it the terminal under the same rule as an interactive role:
`claude` and `codex` get it, the other three run headless and say so.

This shells out once per role, threading the previous report path into the next
prompt. Set `backend <role> <cli>` in `packs.conf` to put different roles on
different CLIs — this is the only variant that keeps SwarmForge's mixed-backend
feature.

## What maps to what

| SwarmForge | Here |
| --- | --- |
| `swarmforge.conf` | `packs.conf` |
| `roles/<role>.prompt` | `roles/<role>.md`, generated per CLI |
| `constitution.prompt` + articles | `constitution.md`, prepended into each generated role |
| `swarm_handoff.sh`, `ready_for_next.sh`, `done_with_current.sh`, `handoffd.bb` | The CLI's task list or subagent return value |
| `git_handoff` with commit abbrev | `docs/handoffs/<task>-<role>.md` + a one-line pointer |
| `swarm_handoff.sh` validation gate | the two checks `swarm run` makes after each role |
| `inbox/`, `outbox/`, priorities, batch mode | nothing — a one-shot role is never busy, so there is no queue to order |
| `dequeued_at` / `completed_at` audit headers | `git log`, plus `docs/handoffs/<task>.log` for failures |
| `ready_for_next.sh` after a crash | `swarm resume <pack> "<task>"` |
| Per-role git worktrees | One shared working tree |
| tmux windows, terminal adapters, watchdog | The CLI's own agent view |
| `./swarm` launcher | `/swarm <pack>` |

## Design notes

**Reports are files, messages are pointers.** A role's answer lands in the
recipient's context in full. A 3000-token review sent as text costs 3000 tokens;
sent as a path it costs about 20. This is SwarmForge's `git_handoff` idea, kept,
and it is what makes the subagent variant affordable.

**The orchestrator stays ignorant.** It is told not to read reports, not to
summarize them, and not to do any role's work. It tracks progress only.

**One role at a time.** All roles share one working tree, so the subagent
variant runs the chain strictly in order. Two roles in parallel would overwrite
each other.

**One commit per handoff, and reports stay out of it.** A role verifies, commits
its work with a `By <role>.` byline, then writes `docs/handoffs/<task>-<role>.md`
recording the commit abbreviation it just made. The report is written *after* the
commit and never into it — `docs/handoffs/.gitignore` holds a single `*`, created
on first run, so a role's `git add` can never sweep reports into project history.
This mirrors upstream, where handoff state lives in `.swarmforge/` and the
`git_handoff` message carries a 10-character commit abbreviation.

**There is no merge step.** Upstream gives each role its own worktree, so the
end-of-chain broadcast is a real `git merge`. Here one shared tree means the
commit is already on the branch; receiving the broadcast means read the report,
verify once, and stop.

## Known gaps

- **Nothing forces a role to detect the right test command.** The constitution
  tells it to prefer a command the project already defines, to record what it
  ran, and to stop and ask rather than guess. That is a rule in a prompt, not a
  check. Read the `test:` line in the first report of a run.
- **A pack-scoped model does not reach every installed subagent.** See the
  section above. `swarm run` is unaffected.
- **No per-role isolation, and no fan-in. On purpose.** Every pack here is a
  straight line — each role needs the previous role's commit — so there is
  nothing within one swarm to run at the same time. Upstream's batch receive mode
  and its per-role worktrees serve fan-in and concurrency these chains do not
  have; getting them back means getting the daemon, the queue and the merges back
  too. Parallelism between whole swarms is a different thing and it works — see
  "Running several swarms at once".
- **`TeammateIdle`'s payload field is unverified.** `swarm check-hook` reads the
  role from `agent_type`. The hooks reference documents `agent_type` as a common
  input field for **subagents**, so `SubagentStop` is sound. Whether a
  `TeammateIdle` payload carries the same field is a guess. If the team-variant
  hook never fires, that is the first thing to check — and note the hook exits 0
  when it finds no role name, so a wrong guess makes it silently do nothing
  rather than block anything.
- **The other four CLIs have no equivalent hook.** There `swarm check` is an
  instruction to the orchestrator, not a gate. See "The same check in the other
  two variants".
- **A failed role is not resumable mid-role, only mid-chain.** `swarm resume`
  restarts the failed role from the top. Upstream's inbox keeps a task in
  `in_process` across a crash; here a role either finished or it did not.
- **Codex prompts are not project-scoped.** Codex reads `~/.codex/prompts/`.
  Copy `.codex/prompts/` there after install.
- **Copilot CLI has no custom slash commands, by decision.** The orchestrator is
  a skill instead; invoke it by name or use `swarm start copilot`.
- **The Antigravity command directory is unverified.** Role subagents land in
  the documented `.agents/agents/`, but `.agents/commands/` is a guess. Check
  `agy inspect` and move it if wrong.
- **The Codex agent TOML schema is partly inferred.** `name`, `description`,
  `model`, and `developer_instructions` are used; verify against your Codex
  version.
- **Model flag names are verified for `claude`, `codex`, `opencode`, and
  `copilot`.** The `agy` flag in `run_cli()` is a guess; it matters only for
  `swarm run`, not for install.
- **Only `claude` and `codex` have an interactive form in `run_cli()`.** Whether
  `opencode`, `copilot`, or `agy` accept an initial prompt in their interactive
  mode was not checked, so they are not listed and an interactive role falls
  back to headless on them. See "The interactive role".
- **The pack adjustment is a prompt line, not a check.** `swarm run` tells each
  role its pack and the whole chain, but nothing verifies the role acted on it.
  If a 4-pack specifier writes a QA suite anyway, only reading the report
  catches it. Same class as the test-command gap above.
- **Claude Code agent teams are experimental** and need
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. `/resume` does not restore in-process
  teammates.
- **`hardender` is spelled `hardener` here.** The original typo is not carried
  over.

## Optional, add only when it bites

A hook that exits 2 when tests fail. `swarm check` proves a role committed and
left a usable report. It does not prove the tests passed — it cannot, without
knowing how to run them. `TaskCompleted` also blocks on exit 2 and would suit the
team variant, where roles complete tasks from a shared list. Add it the first
time you see a role declare unfinished work done, not before.
