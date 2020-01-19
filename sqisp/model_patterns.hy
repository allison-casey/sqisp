(import [functools [reduce]]
        [funcparserlib.parser [some
                              skip
                              finished
                              Parser
                              NoParseError
                              State]]
        [operator [add]]
        [math [isinf]])

(setv FORM (some (constantly True)))

(defn whole
  [parsers]
  "
  Parse the parsers in the given list one after another, then
  expect the end of the input.
  "
  (if (zero? (len parsers))
      (return (>> finished (constantly []))))
  (if (= (len parsers) 1)
      (return (-> parsers (get 0) (+ finished) (>> (fn [x] (cut x 0 -1))))))

  (+ (reduce add parsers) (skip finished)))

(defn times
  [lo hi parser]
  "
  Parse `parser` several times (`lo` to `hi`) in a row. `hi` can be
  float('inf'). The result is a list no matter the number of instances.
  "
  (with-decorator Parser
    (defn f [tokens s]
      (setv result [])
      (for [_ (range lo)]
        (setv (, v s) (parser.run tokens s))
        (result.append v))
      (setv end s.max)
      (try
        (for [_ (if (isinf hi) (repeat 1) (range (- hi lo)))]
          (setv (, v s) (parser.run tokens s))
          (result.append v))
        (except [e NoParseError]
          (setv end (. e state max))))
      (, result (State s.pos end))))
  f)
