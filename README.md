# PLN Mini Inference Engine — Agriculture: Pest & Disease Diagnosis

A standalone mini implementation of PLN (Probabilistic Logic Networks)
inference in MeTTa, applied to diagnosing crop pests/diseases from field
scout observations. Every relationship carries a PLN truth value `<s, c>`
(strength, confidence); the engine performs **forward chaining**,
**backward chaining**, and the four PLN rule families (Deduction,
Induction, Abduction, Revision) over one shared domain knowledge base.

## What is in this repository

| File | Role |
|---|---|
| `stv.metta` | STV arithmetic: neutral prior, `w = c/(1-c)` weight helpers, evidence stamps (`StampDisjoint`/`StampConcat`), revision-support helpers, display rounding, `best-of` |
| `rules.metta` | The five PLN truth formulas — `Truth_Deduction`, `Truth_Induction`, `Truth_Abduction`, `Truth_Revision`, `Truth_ModusPonens` — verbatim from `lib_pln.metta` (line references in file), plus consistency guards and the `apply-rule` dispatch |
| `kb.metta` | Domain knowledge base: 14 semantic beliefs (6 observations, 3 class facts, 5 conditional rules), each with its `<s, c>`, evidence weight `w`, evidence stamp, and prose semantics/assumptions |
| `forward.metta` | Forward chaining: ordered-pair rule application with stamp-disjointness guard, round iteration, store cap (lowest-`c` dropped first), `query-best` over the derived store |
| `backward.metta` | Backward chaining: depth-bounded goal search over five strategies (direct / revision / modus-ponens / deduction / abduction), each returning `(proof VIA BELIEF)` candidates ranked by `best-of` |
| `scenarios.metta` | The five required evaluation scenarios + forward/backward cross-check + known-limitations run-through (this is the entry point for the assignment) |
| `test_rules.metta` | Unit checks of the four rule formulas against the slide walkthrough numbers |
| `test_engine.metta` | End-to-end engine smoke test (forward rounds + backward queries) |
| `report.md` | 1–2 page design/results report |

## How to run

The engine runs on MORK (the MeTTa interpreter in the PeTTa repository).
Clone PeTTa anywhere, put this directory next to it, then:

```bash
cd <PeTTa-directory>
sh run.sh ../pln-agriculture/scenarios.metta > /tmp/out 2>/tmp/err
bash ../pln-agriculture/show.sh /tmp/out        # strips ANSI colors + MORK trace noise
```

`show.sh` prints only the meaningful lines (the raw file contains the
Prolog translation traces of every statement). The full scenarios run
takes ~2 seconds. Individual sections can be filtered, e.g.:

```bash
bash ../pln-agriculture/show.sh /tmp/out | grep -E 'SCENARIO|S[1-5]\.[0-9]|explained'
```

To run a single module test:

```bash
sh run.sh ../pln-agriculture/test_rules.metta   # formula unit checks
sh run.sh ../pln-agriculture/test_engine.metta  # forward + backward smoke test
```

> Interpreter notes (encountered while building this): top-level
> statements need `!(...)`; `println!` takes **one** argument — use the
> list form `(println! ("label" value))`; functions that iterate must
> pre-bind list arguments with `let` before `superpose`.

## The knowledge base (summary)

All entries live in `kb.metta` with full prose documentation. `w` is the
evidence weight `w = c/(1-c)` commented on every relationship.

**Direct observations (field scouting)**

| Statement | `<s, c>` | `w` | stamp |
|---|---|---|---|
| plot1 has yellowing leaves | `<0.90, 0.80>` | 4.0 | `scout-obs-1` |
| plot1 has fine webbing | `<0.85, 0.70>` | 2.33 | `scout-obs-2` |
| plot1 has aphids — scout A (almost none) | `<0.30, 0.50>` | 1.0 | `scout-A` |
| plot1 has aphids — scout B (heavy colony) | `<0.90, 0.75>` | 3.0 | `scout-B` |
| plot2 has webbing | `<0.80, 0.60>` | 1.5 | `scout-obs-3` |
| plot2 has spider mites | `<0.75, 0.55>` | 1.22 | `scout-obs-4` |

**Class-level background facts (Inheritance)**

| Statement | `<s, c>` | `w` | stamp |
|---|---|---|---|
| yellowing crops are often aphid-infested | `<0.70, 0.60>` | 1.5 | `expert-kb-1` |
| nitrogen-deficient crops show yellowing | `<0.85, 0.80>` | 4.0 | `expert-kb-2` |
| webbing indicates spider mites | `<0.75, 0.65>` | 1.86 | `expert-kb-3` |

**Conditional rules (Implication, variable `x`)**

| Rule | `<s, c>` | `w` | stamp |
|---|---|---|---|
| yellowing ⇒ nitrogen deficiency (weak) | `<0.60, 0.60>` | 1.5 | `rule-K1` |
| yellowing ⇒ aphids (stronger) | `<0.80, 0.70>` | 2.33 | `rule-K2` |
| aphids ⇒ treat with neem oil | `<0.90, 0.75>` | 3.0 | `rule-K3` |
| webbing ⇒ spider mites | `<0.75, 0.65>` | 1.86 | `rule-K4` |
| spider mites ⇒ treat with insecticidal soap | `<0.85, 0.70>` | 2.33 | `rule-K5` |

Statements without an explicit STV fall back to the neutral prior
`<0.5, 0.9>` (principle of indifference) — this keeps the consistency
guards in the Deduction formula satisfiable for term priors.

## Example queries and expected outputs

### Rule arithmetic (any MeTTa prompt over `stv.metta` + `rules.metta`)

```lisp
(Truth_ModusPonens (stv 0.90 0.80) (stv 0.80 0.70))
; ==> (stv 0.722 0.4032)          ; yellowing obs x rule-K2

(Truth_Revision (stv 0.70 0.50) (stv 0.95 0.75))
; ==> (stv 0.8875 0.8)            ; slide walkthrough check

(Truth_Deduction (STV raven) (STV bird) (STV wing) (stv 0.98 0.92) (stv 0.95 0.88))
; ==> (stv 0.932 0.75373...)      ; slide walkthrough check
```

### Backward chaining (goal-directed)

```lisp
(answer (Inheritance plot1 (IntSet treat-neem-oil)))
; ==> (proof (mp direct)
;            (belief (Inheritance plot1 (IntSet treat-neem-oil))
;                    (stv 0.812 0.4556) (rule-K3 scout-B)))

(answer (Inheritance plot1 (IntSet aphids)))
; ==> best candidate: (stv 0.75 0.8) with stamp (scout-A scout-B)
;     (Revision of the two conflicting scouts)

(answer (Similarity a b))
; ==> ()        ; no proof exists in the KB
```

### Forward chaining (data-driven)

```lisp
(forward (kb) 1 3 60)                       ; 3 rounds, cap 60 beliefs
(query-best $store (Inheritance plot1 (IntSet treat-neem-oil)))
; ==> (belief (Inheritance plot1 (IntSet treat-neem-oil))
;             (stv 0.7832 0.4602) (rule-K2 rule-K3 scout-B scout-obs-1))
```

### Full scenario run — key expected lines

`sh run.sh ../pln-agriculture/scenarios.metta` then `show.sh`, the
output contains (among the ranked candidate lists):

```
("S1.1 MP yellowing->aphids <s,c>:" (stv 0.722 0.4032))
("S1.2 Revision scout-A + scout-B:" (stv 0.75 0.8))
("S1.3 backward candidates:" 22)
("S1.4 BEST proof:" (proof (mp direct) ... (stv 0.812 0.4556) (rule-K3 scout-B)))
("S2.1 backward candidates:" 2)
("S2.2 BEST proof:" (proof (mp (deduction direct direct)) ... (stv 0.5802 0.1165) ...))
("S3.2 aphids BEST:" (proof revision ... (stv 0.75 0.8) (scout-A scout-B)))
("S3.4 nd BEST:" (proof (abduction direct direct) ... (stv 0.78 0.3655) (expert-kb-2 scout-obs-1)))
("S4.1 weight w1 = c/(1-c), c=0.50:" 1.0)
("S4.2 weight w2 = c/(1-c), c=0.75:" 3.0)
("S4.5 fused <s,c>:" (stv 0.75 0.8))
("S4.7 engine BEST:" (proof revision ... (stv 0.75 0.8) (scout-A scout-B)))
("S5.1 step1 yellowing obs x rule-K2:" (stv 0.722 0.4032))
("S5.2 step2 x rule-K3 (neem oil):" (stv 0.6554 0.1965))
("S5.3 store size after 3 rounds:" 60)
("S5.5 forward BEST neem-oil:" (belief ... (stv 0.7832 0.4602) ...))
("backward answer:" (proof (mp direct) ... (stv 0.812 0.4556) (rule-K3 scout-B)))
("forward query-best:" (belief ... (stv 0.7832 0.4602) ...))
```

Both chaining directions recommend neem oil for plot1 with closely
matched truth values; see `report.md` for the interpretation of each
scenario, the uncertainty-propagation discussion, and the limitations.
