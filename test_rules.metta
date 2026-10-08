; test_rules.metta — unit checks for stv.metta + rules.metta
; Expected values documented inline (slide walkthroughs + KB dispatch).
!(import! &self stv)
!(import! &self rules)

; --- weight conversions ---
!(println! ("c2w(0.5) =" (Truth_c2w 0.5)))          ; expect 1.0
!(println! ("w2c(4.0) =" (Truth_w2c 4.0)))          ; expect 0.8

; --- Revision: slide walkthrough ---
!(println! ("Revision(0.70,0.50)+(0.95,0.75) ="
            (Truth_Revision (stv 0.70 0.50) (stv 0.95 0.75))))  ; expect (stv 0.8875 0.8)

; --- Deduction: slide raven walkthrough ---
!(println! ("Deduction ravens->wings ="
            (Truth_Deduction (STV raven) (STV bird) (STV wing)
                             (stv 0.98 0.92) (stv 0.95 0.88)))) ; expect (stv 0.932 0.75373...)

; --- Induction: slide canary walkthrough ---
!(println! ("Induction yellow-sings ="
            (Truth_Induction (STV (IntSet yellow)) (STV (IntSet sing)) (STV canary)
                             (stv 0.95 0.85) (stv 0.90 0.80))))  ; expect (stv 0.86 0.37965...)

; --- Abduction: plot1 yellowing / nitrogen-deficiency category ---
!(println! ("Abduction plot1->nd ="
            (Truth_Abduction (STV plot1) (STV (IntSet nitrogen-deficiency))
                             (STV (IntSet yellowing))
                             (stv 0.90 0.80) (stv 0.85 0.80))))  ; expect (stv 0.78 0.36548...)

; --- Modus Ponens ---
!(println! ("MP obs+rule ="
            (Truth_ModusPonens (stv 0.90 0.80) (stv 0.80 0.70)))) ; expect (stv 0.722 0.4032)

; --- dispatch: Revision on conflicting scout evidence ---
!(println! ("apply-rule revision ="
            (apply-rule ((Inheritance plot1 (IntSet aphids)) (stv 0.30 0.50))
                        ((Inheritance plot1 (IntSet aphids)) (stv 0.90 0.75)))))
; expect ((Inheritance plot1 (IntSet aphids)) (stv 0.75 0.8))

; --- dispatch: Modus Ponens observation + variable rule ---
!(println! ("apply-rule MP ="
            (apply-rule ((Inheritance plot1 (IntSet yellowing)) (stv 0.90 0.80))
                        ((Implication (Inheritance $x (IntSet yellowing))
                                      (Inheritance $x (IntSet aphids)))
                         (stv 0.80 0.70)))))
; expect ((Inheritance plot1 (IntSet aphids)) (stv 0.722 0.4032))

; --- dispatch: Deduction over two conditional rules ---
!(println! ("apply-rule deduction ="
            (apply-rule ((Implication (Inheritance $x (IntSet yellowing))
                                      (Inheritance $x (IntSet aphids)))
                         (stv 0.80 0.70))
                        ((Implication (Inheritance $x (IntSet aphids))
                                      (Inheritance $x (IntSet treat-neem-oil)))
                         (stv 0.90 0.75)))))
; expect ((Implication (Inheritance $x (IntSet yellowing))
;                      (Inheritance $x (IntSet treat-neem-oil))) (stv 0.74 0.378))

; --- dispatch: Induction from shared instance plot1 ---
!(println! ("apply-rule induction ="
            (apply-rule ((Inheritance plot1 (IntSet yellowing)) (stv 0.90 0.80))
                        ((Inheritance plot1 (IntSet aphids)) (stv 0.75 0.80)))))
; expect ((Inheritance (IntSet yellowing) (IntSet aphids)) (stv 0.70 0.3243))

; --- dispatch: Abduction observation + cause category ---
!(println! ("apply-rule abduction ="
            (apply-rule ((Inheritance plot1 (IntSet yellowing)) (stv 0.90 0.80))
                        ((Inheritance (IntSet nitrogen-deficiency) (IntSet yellowing))
                         (stv 0.85 0.80)))))
; expect ((Inheritance plot1 (IntSet nitrogen-deficiency)) (stv 0.78 0.36548))

; --- dispatch: no rule applies (unrelated facts) ---
!(println! ("apply-rule none ="
            (apply-rule ((Inheritance plot1 (IntSet yellowing)) (stv 0.9 0.8))
                        ((Inheritance plot2 (IntSet webbing)) (stv 0.8 0.6)))))
; expect: unreduced term or nothing -> case-filter downstream yields ()

; --- same pair filtered through a case (the engine's usage pattern) ---
!(println! ("case-filtered none ="
            (case (apply-rule ((Inheritance plot1 (IntSet yellowing)) (stv 0.9 0.8))
                              ((Inheritance plot2 (IntSet webbing)) (stv 0.8 0.6)))
                  ((($t $tv) ($t $tv))))))
; expect: ()

; --- stamps ---
!(println! ("disjoint ="
            (StampDisjoint (scout-obs-1 rule-K2) (scout-A scout-B))))   ; True
!(println! ("not disjoint ="
            (StampDisjoint (scout-obs-1 rule-K2) (scout-obs-1))))       ; False
!(println! ("concat ="
            (StampConcat (scout-A) (scout-B))))                         ; (scout-A scout-B)
