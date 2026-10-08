# Report — A Mini PLN Inference Engine for Crop Pest & Disease Diagnosis

## 1. Problem and why probabilistic reasoning fits

A field scout inspects farm plots and reports symptoms (yellowing
leaves, fine webbing, visible pests). The system must decide which
pest or disease is present and which treatment to apply. Three
properties of the domain make crisp logic a poor fit:

1. **Every symptom→diagnosis link is a fallible statistical
   association** ("yellowing crops are *often* aphid-infested", not
   "always"), so conclusions need a strength `s`, not a true/false bit.
2. **Evidence arrives with unequal reliability** — a trained scout's
   count and a quick visual pass are not worth the same, so evidence
   needs a confidence `c` and a weight `w = c/(1-c)`.
3. **Two scouts may contradict each other** (scout A reports almost no
   aphids on plot1, scout B a heavy colony), which needs a principled
   fusion rule rather than an arbitrary tie-break.

PLN's `<s, c>` truth values, evidence stamps, and the Revision rule
address exactly these three points, so the engine represents every
domain statement as `(belief TERM (stv s c) STAMP)`.

## 2. Design

**Modules** (each file is self-contained; `scenarios.metta` is the
entry point and imports all of them):

- `stv.metta` — STV arithmetic (weights `c/(1-c)`, truth product
  axioms), neutral prior `STV = <0.5, 0.9>` for statements with no
  explicit value, evidence stamps (`StampDisjoint`, `StampConcat` =
  sorted merge), and `best-of` candidate ranking.
- `rules.metta` — `Truth_Deduction`, `Truth_Induction`,
  `Truth_Abduction`, `Truth_Revision`, `Truth_ModusPonens` copied
  verbatim from the reference `lib_pln.metta` (line numbers cited in
  the file), plus conditional-probability consistency guards and an
  `apply-rule` dispatch that routes a belief pair to the matching rule
  (guarded to the syllogistic link types Inheritance/Implication).
- `kb.metta` — 14 interconnected beliefs (6 scout observations, 3
  class-level facts, 5 variable Implication rules), each with `<s,c>`,
  its weight, its evidence stamp, and prose semantics/assumptions.
- `forward.metta` — data-driven chaining: every ordered pair of
  store beliefs whose stamps are disjoint is offered to `apply-rule`;
  derived beliefs are merged alpha-deduplicated; the store is capped
  (lowest `c` dropped first — a crude attention budget in the spirit of
  lib_pln's `LimitSize`, see limitations).
- `backward.metta` — goal-driven chaining: `prove` runs five
  strategies against the goal term — direct lookup, revision of
  independent duplicates, modus ponens (rule consequent unifies with
  the goal, antecedent proved recursively), deduction (goal split as
  `L A C` over a middle term) and abduction (shared consequent) — each
  returning `(proof VIA BELIEF)` candidates up to depth 4; `answer`
  returns the highest-confidence proof.

Both directions share the same algebra: the only difference is
*which* pairs get combined (goal-directed unification vs. exhaustive
cross-product).

## 3. Results — the five scenarios

All numbers below are produced by `scenarios.metta` (rounded to 4
decimals for display).

| # | Scenario | Key output | Reading |
|---|---|---|---|
| 1 | Consistent support | MP `<0.90,0.80>`×`<0.80,0.70>` → `<0.722, 0.4032>`; Revision of scouts → `<0.75, 0.8>`; BEST neem-oil proof `<0.812, 0.4556>` (`mp direct`, `rule-K3 scout-B`) | Rule and observations agree; independent corroboration raises `c` to 0.8, the winning proof is the short direct chain |
| 2 | Incomplete evidence | soap BEST `<0.5802, 0.1165>` via `mp (deduction direct direct)`; only 2 candidates | No direct mite count exists for plot1; passing through the class fact webbing≤mites decays `c` to ≈0.12 — far below the plot1 neem recommendation |
| 3 | Multiple explanations | aphids: 30 candidates, BEST `<0.75, 0.8>` (Revision); nitrogen deficiency: 26 candidates, BEST `<0.78, 0.3655>` (Abduction) | Both hypotheses explain the yellowing; similar `s` (0.75 vs 0.78) but the engine *keeps both ranked* — `c` (0.8 vs 0.3655) separates them |
| 4 | Conflicting evidence | `w1 = 1.0`, `w2 = 3.0`, stamps disjoint `true` (A,B) / `false` (A,A); fused `<0.75, 0.8>`, stamp `(scout-A scout-B)`; engine BEST equals the fused belief | Revision weights the contradicting scouts by reliability instead of picking a winner; the stamp guard prevents re-fusing the same evidence |
| 5 | Multi-step change (forward) | steps `<0.9,0.8>`→`<0.722,0.4032>`→`<0.6554,0.1965>`; 3 forward rounds → store 60; forward BEST neem `<0.7832, 0.4602>`, aphids `<0.746, 0.8238>` | Long chains decay `c` multiplicatively, while the forward cross-product also *merges* independent evidence, which can push `c` above either input |

**Cross-check:** the same question ("should plot1 get neem oil?")
answered backward gives `<0.812, 0.4556>` and forward gives
`<0.7832, 0.4602>` — same recommendation, closely matched truth values;
the small gap comes from extra evidence the forward store fused while
chaining. An impossible goal returns `()` (no proof).

## 4. Uncertainty propagation

- **Conjunction (MP, Deduction, Induction, Abduction)** multiplies
  confidences, so `c` decays with chain length: `0.8 → 0.4032 → 0.1965`
  along yellowing → aphids → neem oil. Depth-4 backward search and
  3-round forward iteration were chosen so these decay ladders stay
  visible rather than vanishing into noise (`c < 0.01` candidates are
  still listed — they are honest consequences of the algebra).
- **Revision is the only confidence-raising operation**: independent
  weights add, `w = 1.0 + 3.0 → c = w2c(4) = 0.8`, with `s` moving
  toward the better-supported report. The stamp-disjointness guard
  guarantees the weight is never inflated by counting one observation
  twice (`StampDisjoint A A` = false is printed in scenario 4).
- **Priors**: statements without an explicit STV use `<0.5, 0.9>`,
  which keeps the conditional-probability consistency guards of the
  Deduction formula satisfiable for intermediate terms while leaving
  `s` at maximum ignorance (0.5).

## 5. Limitations

1. **Uniform priors** are a modelling convenience, not learned
   frequencies — the class-fact `s` values come from the KB author.
2. **Symmetric-rule spillover**: induction/abduction over the
   cross-product also derive reversed class-level beliefs (e.g.
   `(Inheritance (IntSet nitrogen-deficiency) (IntSet yellowing))`
   variants). They are filtered by goal-specific queries and by
   `best-of`, not by the engine itself.
3. **Revision only fuses disjoint stamps**; partially overlapping
   evidence is ignored rather than jointly discounted.
4. **Store cap (60/120)** drops lowest-`c` beliefs first — a crude
   ECAN-style attention/eviction budget. Replacing it with proper
   importance-driven attention (the ECAN material in the slides) is the
   designated future-work extension.
5. **Fixed budgets**: backward depth 4, forward 3 rounds; deeper
   domains would need iterative deepening or goal re-ranking.
6. **No learning**: STVs are input by the KB author; the engine does
   not update rule confidences from outcome statistics.

*Run `scenarios.metta` (see README) to reproduce every number in this
report.*
