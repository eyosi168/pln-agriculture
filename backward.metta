;; =====================================================================
;; backward.metta — backward chaining (goal-driven)
;; =====================================================================
;;
;; prove: prove a ground statement against the belief store by trying
;; five strategies (the SAME algebra as forward chaining, applied in
;; the goal-directed direction):
;;   direct    — the store already contains the statement
;;   revision  — two independent entries for the statement fuse
;;   mp        — find rule Prem => Goal, prove Prem  (Modus Ponens)
;;   deduction — find Goal = (L A C), prove (L A M) and (L M C)
;;   abduction — find Goal = (L A B), prove (L A C) and (L B C)
;; Every strategy returns candidates tagged (proof VIA BELIEF); the
;; evidence stamp of the winning candidate is its proof path.
;; Recursion is depth-bounded; premises of successful matches are
;; proved recursively, which is what generates sub-goals.
;; =====================================================================

(= (prove $beliefs $goal $depth)
   (if (< $depth 1)
       ()
       (append (prove-direct $beliefs $goal)
               (append (prove-revision $beliefs $goal)
                       (append (prove-mp $beliefs $goal $depth)
                               (append (prove-ded $beliefs $goal $depth)
                                       (prove-abd $beliefs $goal $depth)))))))

;; --- direct lookup --------------------------------------------------

(= (prove-direct $beliefs $goal)
   (collapse
    (superpose
     ((let* (((belief $t $tv $e) (superpose $beliefs)))
            (if (== $t $goal)
                (proof direct (belief $t $tv $e))
                (empty)))))))

;; --- revision of two independent entries ----------------------------

(= (prove-revision $beliefs $goal)
   (collapse
    (superpose
     ((let* (((belief $t1 $tv1 $e1) (superpose $beliefs))
             ((belief $t2 $tv2 $e2) (superpose $beliefs)))
            (if (and (== $t1 $goal)
                     (and (== $t2 $goal)
                          (StampDisjoint $e1 $e2)))
                (proof revision
                       (belief $goal
                               (Truth_Revision $tv1 $tv2)
                               (StampConcat $e1 $e2)))
                (empty)))))))

;; --- Modus Ponens backwards -----------------------------------------
;; $goal also occurs inside the rule pattern: the stored rule's
;; consequent must unify with the goal, which also grounds its $x.

(= (prove-mp $beliefs $goal $depth)
   (collapse
    (superpose
     ((let* (((belief $t $tr $er) (superpose $beliefs)))
            (mp-back $beliefs $goal $depth $t $tr $er))))))

(= (mp-back $beliefs $goal $depth (Implication $prem $goal) $tr $er)
   (let $prems (prove $beliefs $prem (- $depth 1))
        (superpose
         ((let* (((proof $f (belief $p $tp $ep)) (superpose $prems)))
                (proof (mp $f)
                       (belief $goal
                               (Truth_ModusPonens $tp $tr)
                               (StampConcat $ep $er))))))))

;; --- Deduction backwards --------------------------------------------
;; Goal = (L A C): premises (L A M) and (L M C); all three patterns
;; share L, A, C so the goal's structure drives the search.

(= (prove-ded $beliefs $goal $depth)
   (collapse
    (superpose
     ((let* (((belief $t1 $v1 $e1) (superpose $beliefs))
             ((belief $t2 $v2 $e2) (superpose $beliefs)))
            (ded-back $beliefs $goal $depth $t1 $v1 $e1 $t2 $v2 $e2))))))

(= (ded-back $beliefs ($LinkType $A $C) $depth
             ($LinkType $A $M) $v1 $e1
             ($LinkType $M $C) $v2 $e2)
   (if (and (SyllogisticRuleGuard $LinkType) (!= $A $C))
       (let $p1 (prove $beliefs ($LinkType $A $M) (- $depth 1))
            (let $p2 (prove $beliefs ($LinkType $M $C) (- $depth 1))
                 (superpose
                  ((let* (((proof $f1 (belief $b1 $tv1 $st1)) (superpose $p1))
                          ((proof $f2 (belief $b2 $tv2 $st2)) (superpose $p2)))
                         (proof (deduction $f1 $f2)
                                (belief ($LinkType $A $C)
                                        (Truth_Deduction (STV $A) (STV $M) (STV $C) $tv1 $tv2)
                                        (StampConcat $st1 $st2))))))))
       (empty)))

;; --- Abduction backwards --------------------------------------------
;; Goal = (L A B): premises (L A C) and (L B C) share C.

(= (prove-abd $beliefs $goal $depth)
   (collapse
    (superpose
     ((let* (((belief $t1 $v1 $e1) (superpose $beliefs))
             ((belief $t2 $v2 $e2) (superpose $beliefs)))
            (abd-back $beliefs $goal $depth $t1 $v1 $e1 $t2 $v2 $e2))))))

(= (abd-back $beliefs ($LinkType $A $B) $depth
             ($LinkType $A $C) $v1 $e1
             ($LinkType $B $C) $v2 $e2)
   (if (and (SyllogisticRuleGuard $LinkType) (!= $A $B))
       (let $p1 (prove $beliefs ($LinkType $A $C) (- $depth 1))
            (let $p2 (prove $beliefs ($LinkType $B $C) (- $depth 1))
                 (superpose
                  ((let* (((proof $f1 (belief $b1 $tv1 $st1)) (superpose $p1))
                          ((proof $f2 (belief $b2 $tv2 $st2)) (superpose $p2)))
                         (proof (abduction $f1 $f2)
                                (belief ($LinkType $A $B)
                                        (Truth_Abduction (STV $A) (STV $B) (STV $C) $tv1 $tv2)
                                        (StampConcat $st1 $st2))))))))
       (empty)))

;; --- query interface -------------------------------------------------

; confidence of a proof candidate (pairs with c-of in stv.metta)
(= (c-of (proof $via (belief $t (stv $s $c) $e))) $c)

; all candidate proofs for a goal in a store, depth budget 4
(= (answer-in $beliefs $goal)
   (prove $beliefs $goal 4))

; the best candidate proof for a goal against the domain KB
(= (answer $goal)
   (best-of (prove (kb) $goal 4)))
