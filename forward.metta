;; =====================================================================
;; forward.metta — forward chaining (data-driven)
;; =====================================================================
;;
;; forward-step: take every ordered pair of beliefs whose evidence
;; stamps are disjoint, apply the rule dispatch (rules.metta), and
;; collect the resulting new beliefs. Disjointness guarantees that the
;; same observation never supports both sides of a combination.
;;
;; forward: iterate forward-step, print each round, merge new beliefs
;; into the store (alpha-deduplicated), and stop when a round produces
;; nothing new or the round budget is reached.
;; =====================================================================

(= (forward-step $beliefs)
   (collapse
    (superpose
     ((let* (((belief $t1 $tv1 $e1) (superpose $beliefs))
             ((belief $t2 $tv2 $e2) (superpose $beliefs)))
            (if (StampDisjoint $e1 $e2)
                (let $stamp (StampConcat $e1 $e2)
                     (case (apply-rule ($t1 $tv1) ($t2 $tv2))
                           ((($tc $tvc) (belief $tc $tvc $stamp)))))
                (empty)))))))

(= (show-new $new)
   (if (== $new ())
       (println! ("   (no new beliefs - fixpoint reached)"))
       (collapse (superpose ((let $b (superpose $new)
                                    (println! ("   derived" $b))))))))

;; Store cap: after merging, keep at most $max beliefs, dropping the
;; lowest-confidence ones first (priority trimming in the spirit of
;; lib_pln's LimitSize — a crude attention mechanism, cf. the ECAN
;; discussion in the slides; the neutral prior keeps the KB safe).

(= (worst-of $lst)
   (let $h (car-atom $lst)
        (let $t (cdr-atom $lst)
             (if (== $t ())
                 $h
                 (let $r (worst-of $t)
                      (if (< (c-of $h) (c-of $r)) $h $r))))))

(= (cap-store $beliefs $max)
   (if (<= (length $beliefs) $max)
       $beliefs
       (cap-store (exclude-item (worst-of $beliefs) $beliefs) $max)))

(= (forward $beliefs $round $max $cap)
   (if (> $round $max)
       $beliefs
       (let $new (forward-step $beliefs)
            (progn (println! ("=== forward chaining round" $round "==="))
                   (show-new $new)
                   (let $merged (cap-store (ConcatUnique $beliefs $new) $cap)
                        (if (== (length $merged) (length $beliefs))
                            $merged
                            (forward $merged (+ $round 1) $max $cap)))))))

; Print every item of a list with a label (collapse keeps the
; surrounding statement deterministic)
(= (show-items $xs $label)
   (if (== $xs ())
       (println! ("   no candidates"))
       (collapse (superpose ((let $b (superpose $xs)
                                    (println! ($label $b))))))))

; Best-confidence belief for a ground statement in a belief store
(= (query-best $beliefs $goal)
   (best-of (collapse (superpose ((let* (((belief $t $tv $e) (superpose $beliefs)))
                                         (if (== $t $goal)
                                             (belief $t $tv $e)
                                             (empty))))))))
