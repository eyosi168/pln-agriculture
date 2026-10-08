;; =====================================================================
;; scenarios.metta — the five evaluation scenarios + chaining demos
;; =====================================================================
;;
;; Runs over the SAME knowledge base (kb.metta) in both directions:
;;   * explicit rule applications (Truth_* formulas) expose the exact
;;     <s, c> arithmetic of Deduction / Induction / Abduction / Revision,
;;   * BACKWARD chaining (answer/answer-in) asks goal-directed domain
;;     questions and returns ranked proof candidates,
;;   * FORWARD chaining (forward) derives new beliefs round by round
;;     and query-best answers from the resulting store.
;;
;; Run:   sh run.sh ../pln-agriculture/scenarios.metta
;; Expected outputs for every section are documented in README.md.
;; =====================================================================

!(import! &self stv)
!(import! &self rules)
!(import! &self kb)
!(import! &self forward)
!(import! &self backward)

;; =====================================================================
;; SCENARIO 1 — Consistent supporting evidence (rule + corroboration)
;; Question: "Should plot1 be treated with neem oil?"
;; =====================================================================

!(println! "=== SCENARIO 1: consistent supporting evidence ===")
;; explicit Modus Ponens: yellowing observed <0.90,0.80> together with
;; rule-K2 (yellowing => aphids) <0.80,0.70>
!(println! ("S1.1 MP yellowing->aphids <s,c>:" (r4 (Truth_ModusPonens (stv 0.90 0.80) (stv 0.80 0.70)))))
;; two independent scouts corroborate aphids: Revision of their reports
!(println! ("S1.2 Revision scout-A + scout-B:" (r4 (Truth_Revision (stv 0.30 0.50) (stv 0.90 0.75)))))
;; BACKWARD chaining: goal-directed question over the KB
!(let $cands (answer-in (kb) (Inheritance plot1 (IntSet treat-neem-oil)))
      (progn (println! ("S1.3 backward candidates:" (length $cands)))
             (println! ("S1.4 BEST proof:" (r4p (best-of $cands))))))
;; explanation: support is independent and consistent, so confidence
;; RISES through Revision (0.50/0.75 -> 0.80) and the winning proof
;; is the direct MP scout-B x rule-K3, c = 0.4556
!(println! "S1 explained: observation + rule agree; Revision of two")
!(println! "independent scouts raises c to 0.8; BEST proof = mp direct")

;; =====================================================================
;; SCENARIO 2 — Incomplete evidence (no direct observation)
;; Question: "Should plot1 get insecticidal soap?"
;; =====================================================================

!(println! "=== SCENARIO 2: incomplete evidence ===")
;; plot1 has webbing but NO direct mite count; conclusion must pass
;; through the class fact webbing <= spider-mites (expert-kb-3)
!(let $cands (answer-in (kb) (Inheritance plot1 (IntSet treat-insecticidal-soap)))
      (progn (println! ("S2.1 backward candidates:" (length $cands)))
             (println! ("S2.2 BEST proof:" (r4p (best-of $cands))))))
;; explicit two-step decay: deduction then treatment rule
!(println! ("S2.3 deduction webbing->mites:" (r4 (Truth_Deduction (STV plot1) (STV (IntSet webbing)) (STV (IntSet spider-mites)) (stv 0.85 0.70) (stv 0.75 0.65)))))
!(println! "S2 explained: no direct mite evidence for plot1; the chain")
!(println! "webbing -> mites -> soap decays c to ~0.12, far below the")
!(println! "confidence of the plot1 neem-oil recommendation (0.4556)")

;; =====================================================================
;; SCENARIO 3 — Multiple (competing) explanations
;; Question: "What explains plot1's yellowing leaves?"
;; =====================================================================

!(println! "=== SCENARIO 3: multiple explanations ===")
;; hypothesis A: aphids — independent scout corroboration (Revision)
!(let $cands (answer-in (kb) (Inheritance plot1 (IntSet aphids)))
      (progn (show-items $cands "S3.1 aphids candidate:")
             (println! ("S3.2 aphids BEST:" (r4p (best-of $cands))))))
;; hypothesis B: nitrogen deficiency — only inferable by abduction
;; from the yellowing observation and the class fact nd <= yellowing
!(let $cands (answer-in (kb) (Inheritance plot1 (IntSet nitrogen-deficiency)))
      (progn (show-items $cands "S3.3 nd candidate:")
             (println! ("S3.4 nd BEST:" (r4p (best-of $cands))))))
;; explicit abduction step behind hypothesis B
!(println! ("S3.5 abduction yellowing <- nd/yellowing:" (r4 (Truth_Abduction (STV plot1) (STV (IntSet nitrogen-deficiency)) (STV (IntSet yellowing)) (stv 0.90 0.80) (stv 0.85 0.80)))))
!(println! "S3 explained: both hypotheses fit the symptom, but their")
!(println! "confidence differs — aphids c=0.8 vs nd c=0.3655; the")
!(println! "engine keeps BOTH ranked candidates instead of one answer")

;; =====================================================================
;; SCENARIO 4 — Conflicting evidence (Revision walkthrough)
;; Question: "Who is right about aphids on plot1?"
;; =====================================================================

!(println! "=== SCENARIO 4: conflicting evidence ===")
;; Scout A: almost no aphids <0.30,0.50> (w = 1.0)
;; Scout B: heavy colony   <0.90,0.75> (w = 3.0)
!(println! ("S4.1 weight w1 = c/(1-c), c=0.50:" (round4 (Truth_c2w 0.50))))
!(println! ("S4.2 weight w2 = c/(1-c), c=0.75:" (round4 (Truth_c2w 0.75))))
!(println! ("S4.3 stamps disjoint (A,B):" (StampDisjoint (scout-A) (scout-B))))
!(println! ("S4.4 stamps disjoint (A,A):" (StampDisjoint (scout-A) (scout-A))))
!(println! ("S4.5 fused <s,c>:" (r4 (Truth_Revision (stv 0.30 0.50) (stv 0.90 0.75)))))
!(println! ("S4.6 fused stamp:" (StampConcat (scout-A) (scout-B))))
;; the engine picks the fused belief as best explanation
!(let $cands (answer-in (kb) (Inheritance plot1 (IntSet aphids)))
      (println! ("S4.7 engine BEST:" (r4p (best-of $cands)))))
!(println! "S4 explained: reports conflict but are independent, so")
!(println! "Revision weights them by reliability (1.0 vs 3.0) and")
!(println! "yields <0.75, 0.8>; A alone would have been <0.30,0.50>")

;; =====================================================================
;; SCENARIO 5 — Multi-step confidence change + FORWARD chaining
;; Question: "What does forward chaining conclude for plot1?"
;; =====================================================================

!(println! "=== SCENARIO 5: multi-step confidence change (FORWARD) ===")
;; explicit two-hop decay along yellowing -> aphids -> neem oil
!(println! ("S5.1 step1 yellowing obs x rule-K2:" (r4 (Truth_ModusPonens (stv 0.90 0.80) (stv 0.80 0.70)))))
!(println! ("S5.2 step2 x rule-K3 (neem oil):" (r4 (Truth_ModusPonens (stv 0.722 0.4032) (stv 0.90 0.75)))))
;; FORWARD chaining over the whole KB: 3 rounds, store capped at 60
!(let $fwd (forward (kb) 1 3 60)
      (progn (println! ("S5.3 store size after 3 rounds:" (length $fwd)))
             ;; the same question, answered from the derived store:
             (println! ("S5.4 forward BEST aphids:" (r4b (query-best $fwd (Inheritance plot1 (IntSet aphids))))))
             (println! ("S5.5 forward BEST neem-oil:" (r4b (query-best $fwd (Inheritance plot1 (IntSet treat-neem-oil))))))
             (println! ("S5.6 forward BEST nd:" (r4b (query-best $fwd (Inheritance plot1 (IntSet nitrogen-deficiency))))))))
!(println! "S5 explained: each additional hop multiplies confidence")
!(println! "down (0.8 -> 0.4032 -> 0.1965 for the long chain), yet")
!(println! "the forward store also MERGES independent evidence:")
!(println! "revived aphids reached c=0.8238 > either input, and the")
!(println! "forward BEST neem-oil <0.7832,0.4602> matches backward's")
!(println! "<0.812,0.4556> recommendation (small difference: the store")
!(println! "additionally fused scout-B with rule-derived aphids)")

;; =====================================================================
;; CROSS-CHECK — same question, both chaining directions
;; =====================================================================

!(println! "=== CROSS-CHECK: plot1 neem oil, both directions ===")
!(println! ("backward answer:" (r4p (answer (Inheritance plot1 (IntSet treat-neem-oil))))))
!(let $fwd (forward (kb) 1 3 60)
      (println! ("forward query-best:" (r4b (query-best $fwd (Inheritance plot1 (IntSet treat-neem-oil)))))))
!(println! "Both directions run over kb.metta and recommend neem oil")
!(println! "for plot1 with closely matched <s,c> - the engine is")
!(println! "direction-independent; the small gap (0.812/0.4556 vs")
!(println! "0.7832/0.4602) comes from extra evidence the forward store")
!(println! "fused while chaining.")

;; =====================================================================
;; KNOWN LIMITATIONS (printed with the run, see also README/report)
;; =====================================================================

!(println! "=== LIMITATIONS ===")
!(println! "1. neutral prior <0.5,0.9> for statements without explicit STV")
!(println! "2. symmetric rules (induction/abduction) also derive reversed")
!(println! "   class-level beliefs - filtered by goal-specific queries,")
!(println! "   not by the engine")
!(println! "3. Revision only fuses disjoint stamps; overlapping evidence")
!(println! "   is ignored rather than jointly discounted")
!(println! "4. store cap (60/120) drops lowest-c beliefs: crude ECAN-style")
!(println! "   attention budgeting, a future-work hook")
