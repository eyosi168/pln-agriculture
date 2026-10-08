;; =====================================================================
;; stv.metta — Simple Truth Values, evidence weights, evidence stamps
;; =====================================================================
;;
;; PLN attaches to every statement a Simple Truth Value (STV) <s, c>:
;;   s (strength)     — subjective probability estimate of the statement
;;   c (confidence)   — epistemic reliability of the evidence behind it
;;   w (evidence weight) — amount of supporting evidence, w = c / (1 - c)
;;                      (Truth_c2w below; inverse: c = w / (w + 1))
;;
;; Knowledge is stored as beliefs:
;;   (belief TERM (stv s c) STAMP)
;; where STAMP is the sorted list of evidence identifiers that support
;; this belief (e.g. (scout-obs-1 rule-K2)). Two beliefs may only be
;; combined by Revision if their stamps are disjoint (StampDisjoint),
;; so the same observation is never counted twice.
;;
;; Formulas transcribed from trueagi-io/PLN lib_pln.metta (MIT),
;; with the source line numbers cited per definition.
;; =====================================================================

;; --- numeric helpers (lib_pln.metta L10-18) -------------------------

; Division that returns (empty) instead of dividing by zero
(= (/safe $A $B)
   (if (> $B 0.0)
       (/ $A $B)
       (empty)))

; Keep $v inside [$min $max]
(= (clamp $v $min $max) (min $max (max $v $min)))

; 1 minus
(= (negate $arg) (- 1.0 $arg))

;; --- confidence <-> evidence weight (lib_pln.metta L70-76) ----------

; w = c / (1 - c)  — evidence weight behind a confidence
(: Truth_c2w (-> Number Number))
(= (Truth_c2w $c)
   (/safe $c (- 1 $c)))

; c = w / (w + 1)  — confidence from accumulated evidence weight
(: Truth_w2c (-> Number Number))
(= (Truth_w2c $w)
   (/safe $w (+ $w 1)))

;; --- prior STV ------------------------------------------------------
;; Every entity/term without a specific STV gets the neutral prior
;; <0.5, 0.9>: principle of indifference (no prior knowledge about how
;; likely the statement is; the prior itself is well-established
;; background knowledge). Used as the P(A), P(B), P(C) inputs of the
;; Deduction/Induction/Abduction formulas. This is the ONLY clause
;; defining STV, so it never overlaps with a more specific clause.
(= (STV $x) (stv 0.5 0.9))

;; --- evidence stamps (lib_pln.metta L335-348) -----------------------

; True iff the two evidence stamps share no identifier
(= (StampDisjoint $Ev1 $Ev2)
   (if (== $Ev1 ())
       True
       (let* (($x (car-atom $Ev1))
              ($rest (cdr-atom $Ev1)))
             (if (is-member $x $Ev2)
                 False
                 (StampDisjoint $rest $Ev2)))))

; Merge two evidence stamps into one sorted stamp
(= (StampConcat $stamp $addition)
   (if (== $addition ())
       $stamp
       (msort (append $stamp $addition))))

;; --- display helper -------------------------------------------------
;; Round to 4 decimals for readable scenario output (internal
;; computations keep full double precision).

(= (round4 $x) (/ (round-math (* 10000.0 $x)) 10000.0))
(= (r4 (stv $s $c)) (stv (round4 $s) (round4 $c)))
(= (r4b (belief $t (stv $s $c) $e))
   (belief $t (stv (round4 $s) (round4 $c)) $e))
(= (r4p (proof $via (belief $t (stv $s $c) $e)))
   (proof $via (belief $t (stv (round4 $s) (round4 $c)) $e)))

;; --- best-confidence selection --------------------------------------
;; Used by backward chaining to pick the most confident candidate.

(= (c-of (belief $t (stv $s $c) $e)) $c)

(= (best-of $lst)
   (if (== $lst ())
       ()
       (let $h (car-atom $lst)
            (let $t (cdr-atom $lst)
                 (if (== $t ())
                     $h
                     (let $r (best-of $t)
                          (if (> (c-of $h) (c-of $r)) $h $r)))))))

;; --- belief-store helpers (lib_pln.metta L24-34) --------------------

; Append $x to $L unless an alpha-equivalent element is present
; (is-alpha-member, so derived rules that differ only in generated
; variable names are still recognised as duplicates)
(= (PushUnique $L $x)
   (if (is-alpha-member $x $L)
       $L
       (append $L ($x))))

; Union of two lists (elements of $L2 appended if not already present)
(= (ConcatUnique $L1 $L2)
   (if (== $L2 ())
       $L1
       (let* (($head (car-atom $L2))
              ($tail (cdr-atom $L2)))
             (ConcatUnique (PushUnique $L1 $head) $tail))))
