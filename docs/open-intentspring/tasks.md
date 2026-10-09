# IntentSpring Demo - Build Tracker

**Spec:** [`intentspring-demo-spec.md`](intentspring-demo-spec.md)
**Process:** `OPEN-SOURCE-PLAYBOOK.md` steps 4-12
**Boilerplate:** open-base (scaffolded with `new-open-app.sh intentspring "IntentSpring" "..."`)

| # | Phase | Status |
|---|---|---|
| 1 | Branding and config: `.env(.example)` (timeout 45s), layout fallback name, violet/ochre accent CSS, landing page | `[x]` |
| 2 | Models: `Intention`, `GuidedScript` migrations, validations, constants, associations, `word_range`/`count_words` | `[x]` |
| 3 | Routes and controllers: `IntentionsController` CRUD as the dashboard, `GuidedScriptsController` (rate limit, crisis + error rescues, index redirect); base `DashboardController` removed | `[x]` |
| 4 | Views and Stimulus: dashboard, form, intention page, result page (disclaimer, Download .md, raw toggle), parse-error partial, `generating`, `form_submit`, `download_markdown` | `[x]` |
| 5 | AI integration: `intentspring_script_v1` prompt, parser, word-count rule, `BannedPhraseCheck` | `[x]` |
| 6 | Seeds: template, "Mornings, again" example with a completed script, `demo_placeholder_v1` removed from seed and DB | `[x]` |
| 7 | Guardrails and evals: `config/ai_guards.yml` (questiontap crisis terms, required keys), `evals/cases/intentspring_script_v1.yml` (9 cases), placeholder case removed | `[x]` |
| 8 | Specs: models, `BannedPhraseCheck`, requests (crisis through the real gatekeeper), seeds; `bundle exec rspec` green; `bin/rails evals:guardrails` PASS | `[x]` |
| 9 | README rewrite, UI journey manifest (port 3127, crisis_field), local commit | `[x]` |

## Quick reference

```
intentions_path                          GET  /intentions   (also /dashboard)
new_intention_path                       GET  /intentions/new
intention_path(i)                        GET  /intentions/:id
edit_intention_path(i)                   GET  /intentions/:id/edit
intention_guided_scripts_path(i)         POST /intentions/:id/scripts
intention_guided_script_path(i, s)       GET  /intentions/:id/scripts/:id
```

```
Template:   intentspring_script_v1   (gemini-2.5-flash, 8192 max tokens, temperature 0.7)
Variables:  sentence, length_minutes, tone   (nothing else about the person)
JSON:       title, length_minutes, segments[3-40]{text, pause_seconds 0-60},
            making_prompt{form, constraint, invitation}
Code rules: spoken words = 130 x minutes +/- 25%; BannedPhraseCheck (therapy, healing, diagnosis,
            progress/streak language, music cues; words from the person's own sentence allowed)
Crisis:     crisis_terms -> AiGatekeeper CrisisError -> 988 message, no AI call, no script row
```

## Deviations from the plan

- No `self_description` field: only the sentence, length and tone go to the model, so a stored but unused field would mislead (spec §3).
- 9 eval cases, not 8: the playbook's 3 golden, 2 edge, 2 adversarial, 1 benign, plus an `expect: crisis` case, since the shared `evals/guardrails.yml` has no crisis attack and a crisis-aware app should prove its routing offline.
- `AI_GLOBAL_TIMEOUT_SECONDS=45` in `.env.example`: the base 15 seconds is likely too short for a ten-minute script.

## Not done here (needs the owner)

- Live runs: `bin/rails evals:run` and `./ui-journey-fleet.sh --yes open-intentspring` (real Gemini calls), and `./ui-journey-fleet.sh --free open-intentspring` (boots the server).
- Pre-publish security check prompt (`open-base/docs/prompts/pre-publish-security-check.md`).
- `Open/README.md` app count and `git open repos.md` remote line (shared files, updated by the coordinator).
- GitHub repo creation and push.
