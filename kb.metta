;; =====================================================================
;; kb.metta — Domain Knowledge Base
;; Domain: Agriculture — Pest & Disease Diagnosis
;; =====================================================================
;;
;; PROBLEM. A field scout inspects farm plots and reports symptoms
;; (yellowing leaves, webbing, visible pests). The system must decide
;; which pest/disease is present and which treatment to apply, given
;; incomplete observations, conflicting scout reports, and expert rules.
;; Probabilistic reasoning fits because every symptom->diagnosis link
;; is a fallible statistical association, evidence arrives with
;; unequal reliability, and two scouts may contradict each other —
;; exactly what PLN's <s, c> truth values and Revision are built for.
;;
;; VOCABULARY / SEMANTICS
;;   (Inheritance X Y)        — "X is a member of / instances of Y"
;;   (Implication P Q)        — "statement P implies statement Q"
;;   (IntSet name)            — a concept/class node
;;   plot1, plot2             — monitored farm plots (instances)
;;
;; STRENGTH s   — subjective probability the statement is true
;; CONFIDENCE c — reliability of the evidence behind the statement
;; WEIGHT w     — evidence weight, w = c / (1 - c)  (commented per entry)
;;
;; EVIDENCE IDENTIFIERS (stamps)
;;   scout-obs-N  — direct field-scout observations (visual symptoms)
;;   scout-A/B    — two independent scouts reporting on plot1 aphids
;;   expert-kb-N  — curated agronomy reference statements
;;   rule-KN      — diagnostic/treatment rules from extension services
;;
;; ASSUMPTIONS
;;   1. All statements not given an explicit STV use the neutral prior
;;      <0.5, 0.9> (principle of indifference, see stv.metta).
;;   2. Evidence stamps are disjoint iff the observations behind two
;;      beliefs are independent; Revision only fuses disjoint stamps,
;;      so no observation is ever counted twice.
;;   3. Conditional rules use the Implication link, class-level
;;      associations use the Inheritance link (both syllogistic types
;;      are guarded in rules.metta).
;; =====================================================================

(= (kb)
   (
    ;; ---- Direct observations (field scouting) ----------------------
    ;; plot1: leaves yellowing — strong visual evidence, w = 4.0
    (belief (Inheritance plot1 (IntSet yellowing)) (stv 0.90 0.80) (scout-obs-1))
    ;; plot1: fine webbing on stems, w = 2.33
    (belief (Inheritance plot1 (IntSet webbing)) (stv 0.85 0.70) (scout-obs-2))
    ;; plot1: scout A counts almost no aphids -> statement
    ;; "plot1 has aphids" judged unlikely, w = 1.0 (conflicts with scout B)
    (belief (Inheritance plot1 (IntSet aphids)) (stv 0.30 0.50) (scout-A))
    ;; plot1: scout B counts a heavy aphid colony, w = 3.0 (conflicts with scout A)
    (belief (Inheritance plot1 (IntSet aphids)) (stv 0.90 0.75) (scout-B))
    ;; plot2: webbing observed, w = 1.5
    (belief (Inheritance plot2 (IntSet webbing)) (stv 0.80 0.60) (scout-obs-3))
    ;; plot2: mites seen under a hand lens, w = 1.22
    (belief (Inheritance plot2 (IntSet spider-mites)) (stv 0.75 0.55) (scout-obs-4))

    ;; ---- Class-level background knowledge (Inheritance) -------------
    ;; yellowing crops are often aphid-infested, w = 1.5
    (belief (Inheritance (IntSet yellowing) (IntSet aphids)) (stv 0.70 0.60) (expert-kb-1))
    ;; nitrogen-deficient crops show yellowing leaves, w = 4.0
    (belief (Inheritance (IntSet nitrogen-deficiency) (IntSet yellowing)) (stv 0.85 0.80) (expert-kb-2))
    ;; webbing indicates spider mites, w = 1.86
    (belief (Inheritance (IntSet webbing) (IntSet spider-mites)) (stv 0.75 0.65) (expert-kb-3))

    ;; ---- Conditional rules (Implication over statements) -----------
    ;; Diagnostic: yellowing implies nitrogen deficiency (weak), w = 1.5
    (belief (Implication (Inheritance $x (IntSet yellowing))
                         (Inheritance $x (IntSet nitrogen-deficiency)))
            (stv 0.60 0.60) (rule-K1))
    ;; Diagnostic: yellowing implies aphids (stronger), w = 2.33
    (belief (Implication (Inheritance $x (IntSet yellowing))
                         (Inheritance $x (IntSet aphids)))
            (stv 0.80 0.70) (rule-K2))
    ;; Treatment: aphids -> apply neem oil, w = 3.0
    (belief (Implication (Inheritance $x (IntSet aphids))
                         (Inheritance $x (IntSet treat-neem-oil)))
            (stv 0.90 0.75) (rule-K3))
    ;; Diagnostic: webbing implies spider mites, w = 1.86
    (belief (Implication (Inheritance $x (IntSet webbing))
                         (Inheritance $x (IntSet spider-mites)))
            (stv 0.75 0.65) (rule-K4))
    ;; Treatment: spider mites -> apply insecticidal soap, w = 2.33
    (belief (Implication (Inheritance $x (IntSet spider-mites))
                         (Inheritance $x (IntSet treat-insecticidal-soap)))
            (stv 0.85 0.70) (rule-K5))
   ))
