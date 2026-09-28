#!/usr/bin/env bash
# Validates the adhd-coach plugin for portability, safety, and manifest consistency.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

FAIL=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

SKILLS=(adhd-coach adhd-dopamine-menu adhd-task-unstick adhd-task-reframe
        adhd-reward-system adhd-motivation-diagnose adhd-routine-refresh
        adhd-manufactured-urgency)

echo "Structure"
for f in plugin.json .claude-plugin/plugin.json .claude-plugin/marketplace.json \
         README.md LICENSE CONTRIBUTING.md profile.example.md; do
  [[ -f "$f" ]] && pass "$f" || fail "missing $f"
done

echo "Skills"
for s in "${SKILLS[@]}"; do
  [[ -f "skills/$s/SKILL.md" ]] && pass "skills/$s/SKILL.md" || fail "missing skills/$s/SKILL.md"
done

found=$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[[ "$found" -eq "${#SKILLS[@]}" ]] \
  && pass "exactly ${#SKILLS[@]} skills" \
  || fail "expected ${#SKILLS[@]} skill dirs, found $found"

echo "JSON validity"
for f in plugin.json .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null \
    && pass "$f parses" || fail "$f is not valid JSON"
done

echo "Agent Plugins 1.0 schema"
python3 - <<'PY'
import json, sys
ALLOWED = {"$schema","name","version","description","author","homepage",
           "repository","license","keywords","extensions"}
SCHEMA = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
m = json.load(open("plugin.json"))
ok = True
if m.get("$schema") != SCHEMA:
    print(f"  \033[31m/\033[0m root plugin.json $schema must be {SCHEMA}"); ok = False
else:
    print("  \033[32m+\033[0m declares Agent Plugins 1.0 $schema")
extra = set(m) - ALLOWED
if extra:
    print(f"  \033[31m/\033[0m unsupported key(s) in root plugin.json: {sorted(extra)}"); ok = False
else:
    print("  \033[32m+\033[0m no unsupported top-level keys")
sys.exit(0 if ok else 1)
PY
[[ $? -eq 0 ]] || FAIL=1

echo "Manifest sync"
python3 - <<'PY'
import json, sys
root = json.load(open("plugin.json"))
claude = json.load(open(".claude-plugin/plugin.json"))
mkt = json.load(open(".claude-plugin/marketplace.json"))
ok = True
for field in ("name","version","description","license","homepage","repository"):
    if root.get(field) != claude.get(field):
        print(f"  \033[31m/\033[0m '{field}' differs between manifests"); ok = False
if ok:
    print("  \033[32m+\033[0m manifests agree on shared metadata")
entries = [p.get("name") for p in mkt.get("plugins", [])]
if root["name"] in entries:
    print("  \033[32m+\033[0m marketplace entry name matches manifest name")
else:
    print(f"  \033[31m/\033[0m marketplace entry {entries} must include '{root['name']}'"); ok = False
sys.exit(0 if ok else 1)
PY
[[ $? -eq 0 ]] || FAIL=1

echo "Skill frontmatter"
python3 - <<'PY'
import re, sys, pathlib
ok = True
for p in sorted(pathlib.Path("skills").glob("*/SKILL.md")):
    text = p.read_text()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        print(f"  \033[31m/\033[0m {p}: missing frontmatter"); ok = False; continue
    fm = m.group(1)
    name = re.search(r'^name:\s*"?([^"\n]+)"?', fm, re.M)
    desc = re.search(r'^description:\s*"?(.+?)"?\s*$', fm, re.M)
    if not name:
        print(f"  \033[31m/\033[0m {p}: no name"); ok = False; continue
    if name.group(1) != p.parent.name:
        print(f"  \033[31m/\033[0m {p}: name '{name.group(1)}' != dir '{p.parent.name}'"); ok = False
    if not name.group(1).startswith("adhd-"):
        print(f"  \033[31m/\033[0m {p}: name must use the adhd- prefix"); ok = False
    if not desc:
        print(f"  \033[31m/\033[0m {p}: no description"); ok = False
    elif "WHEN:" not in desc.group(1):
        print(f"  \033[31m/\033[0m {p}: description needs a WHEN: trigger list"); ok = False
if ok:
    print("  \033[32m+\033[0m frontmatter valid")
sys.exit(0 if ok else 1)
PY
[[ $? -eq 0 ]] || FAIL=1

echo "Safety stanza in every skill"
for s in "${SKILLS[@]}"; do
  f="skills/$s/SKILL.md"
  if grep -qi "not medical advice" "$f" && grep -q "findahelpline.com" "$f"; then
    pass "$s"
  else
    fail "$s missing the safety stanza or crisis resources"
  fi
done

echo "Portability"
declare -a BAD=(
  "m_ask_user:client-specific tool call"
  "m_get_skill:client-specific tool call"
  "m_remember:client-specific tool call"
  "work-vault-3:personal vault path"
  "Clawpilot:client-specific reference"
  "/Users/:absolute local path"
)
for entry in "${BAD[@]}"; do
  pat="${entry%%:*}"; why="${entry#*:}"
  hits=$(grep -rIl --exclude-dir=.git --exclude-dir=node_modules \
          --exclude=validate.sh --exclude=validate.yml -- "$pat" . 2>/dev/null || true)
  [[ -z "$hits" ]] && pass "no '$pat' ($why)" \
                   || fail "found '$pat' ($why) in: $(echo "$hits" | tr '\n' ' ')"
done

hits=$(grep -rIlw "Tim" skills/ 2>/dev/null || true)
[[ -z "$hits" ]] && pass "no leftover personal names in skills" \
                 || fail "personal name left in: $hits"

echo "Cross-references"
python3 - <<'PY'
import re, sys, pathlib
router = pathlib.Path("skills/adhd-coach/SKILL.md").read_text()
present = {p.name for p in pathlib.Path("skills").iterdir() if p.is_dir()}
refs = set(re.findall(r"`/(adhd-[a-z-]+)`", router))
missing = {r for r in refs if r not in present}
if missing:
    print(f"  \033[31m/\033[0m router references non-existent skills: {sorted(missing)}")
    sys.exit(1)
leaves = present - {"adhd-coach"}
unref = {l for l in leaves if f"/{l}" not in router}
if unref:
    print(f"  \033[31m/\033[0m router never routes to: {sorted(unref)}")
    sys.exit(1)
print(f"  \033[32m+\033[0m router references all {len(leaves)} interventions, none dangling")
PY
[[ $? -eq 0 ]] || FAIL=1

echo
if [[ $FAIL -eq 0 ]]; then
  printf '\033[32mAll checks passed.\033[0m\n'
else
  printf '\033[31mValidation failed.\033[0m\n'
fi
exit $FAIL
