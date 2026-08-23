#!/bin/sh
# test-swarm.sh - does a `next:` line in a report send the chain back?
#
# Runs the real ./swarm over a throwaway git repo, with a stub agent CLI in
# place of a real one. Role `b` sends the work back to `a`, so the chain must
# visit a b a b c, not a b c. Two cases: a clean run, and a run that dies after
# the jump and is resumed, where the jump has to survive the resume skip.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@test
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@test

# A copy of the tool with a three-role pack and no real backends.
sf="$tmp/sf"
mkdir -p "$sf/roles"
cp "$DIR/swarm" "$DIR/constitution.md" "$sf/"
cat > "$sf/packs.conf" <<'CONF'
pack t a b c
backend a opencode
backend b opencode
backend c opencode
CONF
for r in a b c; do printf '> stub role %s\n\nYou are a stub.\n' "$r" > "$sf/roles/$r.md"; done

# The stub agent CLI. It reads its role and report path out of the prompt,
# commits, and writes the report the chain checks for. $CRASH makes role `a`
# die once, right after the jump, to leave a chain for `swarm resume`.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/opencode" <<'STUB'
#!/bin/sh
set -eu
p=$2   # opencode run "<prompt>"
role=$(printf '%s' "$p" | sed -n 's/^You are the \*\*\([^*]*\)\*\*.*/\1/p' | head -1)
rp=$(printf '%s' "$p" | sed -n 's/^Write your report to `\(.*\)`, then stop\.$/\1/p' | head -1)
[ -n "$role" ] && [ -n "$rp" ] || { echo "stub: could not read the prompt" >&2; exit 1; }
echo "$role" >> "$ORDER"
if [ -n "$CRASH" ] && [ "$role" = a ] && [ -f "$SENTBACK" ] && [ ! -f "$CRASHED" ]; then
  : > "$CRASHED"; echo "stub: dying on purpose" >&2; exit 1
fi
date +%s%N >> log.txt
git add -A >/dev/null
git commit -qm "work by $role"
echo "commit: $(git rev-parse --short=10 HEAD)" > "$rp"
# b sends the work back to a, once.
if [ "$role" = b ] && [ ! -f "$SENTBACK" ]; then : > "$SENTBACK"; echo 'next: a' >> "$rp"; fi
STUB
chmod +x "$tmp/bin/opencode"
PATH="$tmp/bin:$PATH"; export PATH

# project <name> -- a fresh repo and a fresh record of who ran; cds into it.
project() {
  ORDER="$tmp/$1.order"; SENTBACK="$tmp/$1.sentback"; CRASHED="$tmp/$1.crashed"
  export ORDER SENTBACK CRASHED
  : > "$ORDER"
  mkdir -p "$tmp/$1"
  cd "$tmp/$1"
  git init -q .
}

# ran <what> <expected order> -- compare who ran with who should have.
ran() {
  got=$(tr '\n' ' ' < "$ORDER")
  if [ "$got" != "$2" ]; then
    echo "FAIL: $1 - roles ran [$got], wanted [$2]"
    cat "$tmp/out"
    exit 1
  fi
  echo "PASS: $1 - [$got]"
}

CRASH=''; export CRASH
project clean
if ! "$sf/swarm" run t "backward edge" > "$tmp/out" 2>&1; then
  echo "FAIL: clean run - the chain did not finish"; cat "$tmp/out"; exit 1
fi
ran "a next: line sends the chain back" 'a b a b c '

CRASH=1; export CRASH
project crash
if "$sf/swarm" run t "backward edge" > "$tmp/out" 2>&1; then
  echo "FAIL: resumed run - the chain was supposed to die at a"; cat "$tmp/out"; exit 1
fi
# Every role that ran has a report naming a commit HEAD stands on, so resume
# skips them all. The jump must still be read off b's report.
if ! "$sf/swarm" resume t "backward edge" > "$tmp/out" 2>&1; then
  echo "FAIL: resumed run - the chain did not finish"; cat "$tmp/out"; exit 1
fi
ran "the jump survives a resume" 'a b a a b c '
