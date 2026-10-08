;; =====================================================================
;; rules.metta — the PLN inference rules (all compute <s, c>)
;; =====================================================================
;;
;; Required by the assignment: Deduction, Induction, Abduction,
;; Revision. Modus Ponens is additionally required to ground
;; conditional rules in concrete observations (it is part of the PLN
;; calculus, cf. PLN book 5.7.1).
;;
;; All truth-value formulas are transcribed verbatim from
;; trueagi-io/PLN lib_pln.metta (MIT) — source lines cited below —
;; which implements the PLN book formulas:
;;   Deduction  — PLN book 1.4, "Truth-value Formulas", p.15
;;   Induction  — PLN book Appendix A, p.307
;;   Abduction  — PLN book Appendix A, p.307
;;   Modus Ponens — PLN book 5.7.1, p.111
;;   Revision   — PLN book 5.10.2, "A Heuristic Revision Rule...", p.116
;;
;; apply-rule dispatches over belief pairs (adapted from lib_pln's
;; |- rules, L210-259). It receives two (term stv) tuples and returns
;; a (conclusion-term stv) tuple, or nothing if no rule applies.
;; =====================================================================

;; --- consistency guards (lib_pln.metta L42-54) ----------------------
;; PLN book 5.2.2.2: before deducting, the conditional probabilities
;; involved must be coherent: max(0,(sA+sB-1)/sA) <= sAB <= min(1,sB/sA).

(: smallest-intersection-probability (-> Number Number Number))
(= (smallest-intersection-probability $As $Bs)
   (clamp (/ (- (+ $As $Bs) 1) $As) 0 1))

(: largest-intersection-probability (-> Number Number Number))
(= (largest-intersection-probability $As $Bs)
   (clamp (/ $Bs $As) 0 1))

(: conditional-probability-consistency (-> Number Number Number Bool))
(= (conditional-probability-consistency $As $Bs $ABs)
   (and (< 0 $As)
        (and (<= (smallest-intersection-probability $As $Bs) $ABs)
             (<= $ABs (largest-intersection-probability $As $Bs)))))

;; --- Rule A: Deduction (lib_pln.metta L84-99) -----------------------
;; Premises:  A -> B  <PQs,PQc>   and   B -> C  <QRs,QRc>
;; Conclusion: A -> C
;; s uses the law of total probability over the intermediate premise B;
;; c = s(PQ)*s(QR)*c(PQ)*c(QR)  — confidence degrades across hops.

(= (Truth_Deduction (stv $Ps $Pc)
                    (stv $Qs $Qc)
                    (stv $Rs $Rc)
                    (stv $PQs $PQc)
                    (stv $QRs $QRc))
   (if (and (conditional-probability-consistency $Ps $Qs $PQs)
            (conditional-probability-consistency $Qs $Rs $QRs))
       (stv (if (< 0.9999 $Qs)
                $Rs
                (+ (* $PQs $QRs)
                   (/safe (* (- 1 $PQs) (- $Rs (* $Qs $QRs))) (- 1 $Qs))))
            (* (* $PQs $QRs) (* $PQc $QRc)))
       (stv 1 0)))

;; --- Rule B: Induction (lib_pln.metta L102-110) ---------------------
;; Premises:  C -> A  <sBA,cBA>   and   C -> B  <sBC,cBC>
;; Conclusion: A -> B   (generalisation from shared instances)
;; s applies Bayes inversion through the shared instance C;
;; c = w2c(s(BC)*c(BC)*c(BA)).

(= (Truth_Induction (stv $sA $cA)
                    (stv $sB $cB)
                    (stv $sC $cC)
                    (stv $sBA $cBA)
                    (stv $sBC $cBC))
   (stv (+ (/safe (* (* $sBA $sBC) $sB) $sA)
           (* (- 1 (/safe (* $sBA $sB) $sA))
              (/safe (- $sC (* $sB $sBC)) (- 1 $sB))))
        (Truth_w2c (* (* $sBC $cBC) $cBA))))

;; --- Rule C: Abduction (lib_pln.metta L112-121) ---------------------
;; Premises:  A -> C  <sAB,cAB>   and   B -> C  <sCB,cCB>
;; Conclusion: A -> B   (diagnostic: from a shared effect to a cause)
;; s = P(C|A)*P(C|B)*P(C)/P(B) + P(C)*(1-P(C|A))*(1-P(C|B))/(1-P(B));
;; c = w2c(s(AB)*c(AB)*c(CB)).

(= (Truth_Abduction (stv $sA $cA)
                    (stv $sB $cB)
                    (stv $sC $cC)
                    (stv $sAB $cAB)
                    (stv $sCB $cCB))
   (stv (+ (/safe (* (* $sAB $sCB) $sC) $sB)
           (/safe (* $sC (* (- 1 $sAB) (- 1 $sCB))) (- 1 $sB)))
        (Truth_w2c (* (* $sAB $cAB) $cCB))))

;; --- Rule D: Revision (lib_pln.metta L136-143) ----------------------
;; Merges two independent STVs for the SAME statement:
;; w = w1 + w2,  s = (w1*s1 + w2*s2)/w,  c = max(w2c(w), c1, c2).
;; Guarantees monotonic confidence growth for disjoint evidence.

(= (Truth_Revision (stv $f1 $c1) (stv $f2 $c2))
   (let* (($w1 (Truth_c2w $c1))
          ($w2 (Truth_c2w $c2))
          ($w (+ $w1 $w2))
          ($f (/safe (+ (* $w1 $f1) (* $w2 $f2)) $w))
          ($c (Truth_w2c $w)))
         (stv (min 1.0 $f)
              (min 1.0 (max (max $c $c1) $c2)))))

;; --- Modus Ponens (lib_pln.metta L124-126) --------------------------
;; Premises:  A  <Ps,Pc>   and   A -> B  <PQs,PQc>
;; Conclusion: B
;; s = sA*sAB + 0.02*(1-sA);  c = sA*sAB*cA*cAB.

(= (Truth_ModusPonens (stv $Ps $Pc) (stv $PQs $PQc))
   (stv (+ (* $Ps $PQs) (* 0.02 (- 1 $Ps)))
        (* (* $Ps $PQs) (* $Pc $PQc))))

;; --- rule dispatch over belief pairs (adapted from lib_pln |-) ------
;; Arguments are (term stv) tuples; result is (conclusion stv).
;; Only the link types used by this domain may take part in
;; syllogisms (lib_pln.metta L232-233).

(= (SyllogisticRuleGuard Inheritance) True)
(= (SyllogisticRuleGuard Implication) True)

; Revision: same statement, independent evidence (stamps checked
; upstream by the chaining engine, cf. StampDisjoint in stv.metta)
(= (apply-rule ($T $T1) ($T $T2))
   ($T (Truth_Revision $T1 $T2)))

; Modus Ponens: ground instance + conditional rule
(= (apply-rule ($A $T1) ((Implication $A $B) $T2))
   ($B (Truth_ModusPonens $T1 $T2)))

; Deduction: A->B, B->C  =>  A->C   (distinct A and C)
(= (apply-rule (($LinkType $A $B) $T1)
               (($LinkType $B $C) $T2))
   (if (and (SyllogisticRuleGuard $LinkType) (!= $A $C))
       (($LinkType $A $C)
        (Truth_Deduction (STV $A) (STV $B) (STV $C) $T1 $T2))
       (empty)))

; Induction: C->A, C->B  =>  A->B   (distinct A and B)
(= (apply-rule (($LinkType $C $A) $T1)
               (($LinkType $C $B) $T2))
   (if (and (SyllogisticRuleGuard $LinkType) (!= $A $B))
       (($LinkType $A $B)
        (Truth_Induction (STV $A) (STV $B) (STV $C) $T1 $T2))
       (empty)))

; Abduction: A->C, B->C  =>  A->B   (distinct A and B)
(= (apply-rule (($LinkType $A $C) $T1)
               (($LinkType $B $C) $T2))
   (if (and (SyllogisticRuleGuard $LinkType) (!= $A $B))
       (($LinkType $A $B)
        (Truth_Abduction (STV $A) (STV $B) (STV $C) $T1 $T2))
       (empty)))
