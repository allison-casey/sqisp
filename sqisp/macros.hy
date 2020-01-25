(import hy
        importlib
        importlib.resources
        [sqisp.lexer [lexer]]
        [sqisp.parser [parser ParserState]]
        [hy.models [*]]
        [sqisp.models [*]]
        [hy.core.language [first rest interleave]]
        [itertools [repeat]]
        )

(defn replace-defmacro [tree]
  (if-not (= (get tree 0) "defmacro")
          (raise (SyntaxError f"Expected 'defmacro' but saw {(get tree 0)}")))

  (setv (get tree 0)
        (hy.models.replace-hy-obj (HySymbol "def-sqisp-macro") (get tree 0)))
  tree)

(defn hy->sqf [symbol]
  (cond
    [(isinstance symbol HyFloat) (SQFFloat symbol)]
    [(isinstance symbol HyInteger) (SQFInteger symbol)]
    [(isinstance symbol HyString) (SQFString symbol)]
    [(isinstance symbol HySymbol) (SQFSymbol symbol)]
    [(isinstance symbol HyList) (SQFList (lfor sym symbol (hy->sqf sym)))]
    [(isinstance symbol HyExpression) (SQFExpression (lfor sym symbol (hy->sqf sym)))]
    [(isinstance symbol list) (lfor sym symbol (hy->sqf sym))]
    [True symbol]))

(defn sqf->hy [symbol]
  (cond
    [(isinstance symbol SQFFloat) (HyFloat symbol)]
    [(isinstance symbol SQFInteger) (HyInteger symbol)]
    [(isinstance symbol SQFString) (HyString symbol)]
    [(isinstance symbol SQFSymbol) (HySymbol symbol)]
    [(isinstance symbol SQFList) (HyList (lfor sym symbol (sqf->hy sym)))]
    [(isinstance symbol SQFExpression) (HyExpression (lfor sym symbol (sqf->hy sym)))]
    [(isinstance symbol list) (lfor sym symbol (sqf->hy sym))]
    [True symbol]))

(setv __sqisp_macros__ {})

(defmacro def-sqisp-macro
  [macro-name lambda-list &rest body]
  (setv (get __sqisp_macros__ macro-name)
        (eval
          `(fn ~lambda-list
             ~@body))))

(defn sqisp-macroexpand
  [tree &optional [once False]]
  (while True
    (if (or (not (isinstance tree SQFExpression)) (= tree []))
        (break))

    (setv -fn (get tree 0))
    (if (or (in -fn (, "quote" "quasiquote"))
            (not (isinstance -fn SQFSymbol)))
        (break))

    (setv m (.get __sqisp_macros__ -fn None))
    (if m
        (setv tree (hy->sqf (m #* (cut tree 1))))
        (break))

    (if once (break)))
  tree)

(defn compile-macro-file
  [text]
  (as-> text $
        (lexer.lex $)
        (parser.parse $ :state (ParserState))
        (sqf->hy $)
        (map replace-defmacro $)
        (for [func $]
          (eval func))))

(setv CORE-MACROS {"sqisp.bootstrap" ["macros.sqpm"]})

(defn load_macros []
  (for [(, builtin-mod-name files) (.items CORE-MACROS)]
    (setv builtin-mod (importlib.import-module builtin-mod-name))
    (for [file files]
      (compile-macro-file (importlib.resources.read-text builtin-mod file))))
  )
