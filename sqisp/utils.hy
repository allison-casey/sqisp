(import re unicodedata)

(setv keyword-regex r"[0-9a-zA-Z_]+"
      mangle-delim "X")

(defn pairwise [iterable]
  (setv (, a b) (tee iterable))
  (next b None)
  (zip a b))

(defn is-sqf-keyword [s]
  (bool (re.fullmatch keyword-regex s)))

(defn mangle [s]
  (defn unicode->hex [uchar]
    (if (and (= (len uchar) 1) (< (ord uchar) 128))
        (return (format (ord uchar) "x")))
    (-> uchar
        (.encode "unicode-escape")
        (.lstrip "\\U")
        (.lstrip "\\u")
        (.lstrip "\\x")
        (.lstrip "0")))

  (assert s)
  (setv s (str s)
        s (s.replace "-" "_")
        s2 (s.lstrip "_")
        leading-underscores (* "_" (- (len s) (len s2)))
        s s2)

  (if (s.endswith "?")
      (setv s f"is_{(cut s 0 -1)}"))
  (if (not (is-sqf-keyword (+ leading-underscores s)))
      (setv s (+ "al_" (.join "" (gfor c s (if (is-sqf-keyword c)
                                               c
                                               (.format
                                                 "{0}{1}{0}"
                                                 mangle-delim
                                                 (or (-> c
                                                         (unicodedata.name "")
                                                         .lower
                                                         (.replace "-" "L")
                                                         (.replace " " "_"))
                                                     f"U{(unicode->hex c)}"))))))))
  (assert is-sqf-keyword x)
  (+ leading-underscores s))
