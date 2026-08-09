# Provenance and licensing

This work lives on the `agent-cli-port` branch of a **GitHub fork** of
[unclebob/swarm-forge](https://github.com/unclebob/swarm-forge). That is
deliberate, and the reason is below: upstream carries no license, and forking
within GitHub is the one public-hosting route that does not need one.

Upstream's own branches are left untouched in this fork, so they stay available
to diff against.

## Where this came from

This is a port of [unclebob/swarm-forge](https://github.com/unclebob/swarm-forge).
The mechanism is new — upstream runs on tmux and Babashka handoff scripts, this
runs on a POSIX shell script and each agent CLI's own subagent system. No
upstream code was copied.

The **prompt text is largely upstream's**. Measured against `origin/six-pack` and
`origin/main`, after normalising bullets and whitespace:

| File here | Upstream file | Lines identical |
| --- | --- | --- |
| `roles/coder.md` | `roles/coder.prompt` | 91% |
| `roles/specifier.md` | `roles/specifier.prompt` | 90% |
| `roles/cleaner.md` | `roles/cleaner.prompt` | 82% |
| `roles/architect.md` | `roles/architect.prompt` | 70% |
| `roles/hardener.md` | `roles/hardender.prompt` | 60% |
| `roles/QA.md` | `roles/QA.prompt` | 56% |
| `constitution.md` | `constitution/articles/engineering.prompt` | 68% |

The handoff rules in `constitution.md` are our own (3% overlap with upstream's
`handoffs.prompt`), because the handoff mechanism was replaced.

## The problem

**Upstream carries no license.** Checked on 2026-08-09:

- No `LICENSE` or `COPYING` file on any of its six branches — `main`,
  `two-pack`, `four-pack`, `six-pack`, `squad`, `adversaries`.
- No commit in its entire history ever added one.
- No licensing statement in its README.
- The GitHub API reports `"license": null`.

With no license, the default applies: copyright is reserved. Publishing this
repository under an open license would be relicensing someone else's text, and
the tables above show the text is substantially theirs.

This is a statement of what was found, not legal advice.

## What was decided

**Host it as a fork.** GitHub's terms allow forking a public repository within
GitHub, so a fork is publishable without upstream adding a license. Note what a
fork does *not* grant: the right to relicense. There is **no `LICENSE` file
here on purpose**, and none should be added. An earlier copy of this work sat
inside an MIT-licensed repository; that MIT grant never covered the ported
prompt text.

Because the repository is a fork of a public project, it is public and cannot be
made private.

**Still worth doing: ask upstream for a license.** It is a small ask for a public
project clearly meant to be used, and it is the only thing that would make this
work redistributable outside GitHub. If a license is added, record it here and
add the matching `LICENSE` file.
