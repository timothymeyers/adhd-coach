# Contributing

Thanks for taking a look. This started as a personal set of prompts and is shared in case
it's useful to others — contributions that make it work for more brains than mine are
genuinely welcome.

## Before you start

Please read the disclaimer in the [README](./README.md). I'm not a clinician, this isn't a
medical tool, and contributions need to keep it that way.

## Most useful contributions

- **"This intervention didn't land for me."** Easily the most valuable report. The skills
  are tuned to one person's ADHD; hearing where they miss is how they get better.
- **Interventions for patterns the seven don't cover.** If you have a repeatable move that
  works, open an issue describing the pattern before writing the skill.
- **Client compatibility fixes.** If install or invocation breaks on a client I haven't
  tested, please say which client and version.
- **Clearer wording.** These are prompts — ambiguity degrades output.

## Ground rules for skill content

1. **No clinical claims.** Skills produce a coaching read, never a diagnosis. Use "this
   looks more like…", never "you have…". Don't reference specific medications or dosing.
2. **Keep the safety stanza.** Every `SKILL.md` carries the not-medical-advice note and
   crisis resources. Leaf skills are directly invocable, so they can't rely on the router
   for that. Don't remove or bury it.
3. **Escalate rather than coach when signals warrant it.** If a skill could plausibly meet
   someone in acute distress, it must point them to professional support first.
4. **Stay portable.** No client-specific tool calls, no absolute paths, no assumptions
   about a particular vendor's features. Where a client capability helps, make it optional.
5. **Respect stated constraints.** Anything suggesting money, food, alcohol, exercise, or
   public commitment needs a line telling the model to honour the user's limits.
6. **Keep it short.** Long prompts produce long responses, and long responses are their own
   form of resistance for the person reading them.
7. **Keep the tone.** Direct, warm, no hype. No "you've got this!", no gamification
   marketing, no infantilizing.

## Structure

```
skills/<skill-name>/SKILL.md
```

Frontmatter needs `name` (matching the directory, `adhd-` prefixed) and `description`
(what it does, plus a `WHEN:` list of trigger phrases that helps clients route to it).

If you add a skill, update the routing table and triage flow in `skills/adhd-coach/SKILL.md`
and the table in the README.

## Before opening a PR

```bash
./scripts/validate.sh
```

This checks frontmatter, naming, manifest sync, and that no personal paths or
client-specific tool calls crept in. CI runs the same script.

Please also actually try your change in a real client before submitting — prompt edits can
read fine and behave badly.

## Reporting a safety problem

If you find output that could harm someone, open an issue marked **[safety]**, or email the
address on my GitHub profile if you'd rather not do it publicly. I'll prioritize it.
