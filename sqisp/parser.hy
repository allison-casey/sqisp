(import [.lexer [lexer]]
        [.models [SQFExpression
                  SQFList
                  SQFDict
                  SQFSet
                  SQFKeyword
                  SQFObject
                  SQFSequence
                  SQFString
                  SQFSymbol
                  SQFInteger
                  SQFFloat]]
        [functools [wraps]]
        [rply [ParserGenerator]])

(setv pg (ParserGenerator (+ (lfor rule lexer.rules rule.name) ["$end"])))

(defn set-boundaries [f]
  (with-decorator
    (wraps f)
    (defn wrapped [state p]
      (setv
        start (. (get p 0) source-pos)
        end (. (get p -1) source-pos)
        ret (f state p)
        ret.start-line start.lineno
        ret.start-column start.colno)
      (if (is-not start end)
          (setv
            ret.end-line end.lineno
            ret.end-column end.colno)
          (setv
            v (. (get p 0) value)
            ret.end-line (+ start.lineno (v.count "\n"))
            ret.end-column (if (in "\n" v)
                               (- (len v) (v.rindex "\n") 1)
                               (- (+ start.colno (len v)) 1))))
      ret))
  wrapped)

(defn set-quote-boundaries [f]
  (with-decorator (wraps f)
    (defn wrapped [state p]
      (setv
        start (. (get p 0) source-pos)
        ret (f state p)
        ret.start-line start.lineno
        ret.start-column start.colno
        ret.end-line (. (get p -1) end-line)
        ret.end-column (. (get p -1) end-column))
      ret))
  wrapped)


(with-decorator (pg.production "main : list_contents")
  (defn main
    [state p]
    (get p 0)))

(with-decorator (pg.production "main : $end")
  (defn main-empty
    [state p]
    []))

(with-decorator
  (pg.production "term : QUOTE term")
  set-quote-boundaries
  (defn term-quote
    [state p]
    (SQFExpression [(SQFSymbol "quote") (get p 1)])))

(with-decorator
  (pg.production "term : QUASIQUOTE term")
  set-quote-boundaries
  (defn term-quasiquote
    [state p]
    (SQFExpression [(SQFSymbol "quasiquote") (get p 1)])))

(with-decorator
  (pg.production "term : UNQUOTE term")
  set-quote-boundaries
  (defn term_unquote
    [state p]
    (SQFExpression [(SQFSymbol "unquote") (get p 1)])))

(with-decorator
  (pg.production "term : UNQUOTESPLICE term")
  set-quote-boundaries
  (defn term_unquotesplice
    [state p]
    (SQFExpression [(SQFSymbol "unquote-splice") (get p 1)])))

(with-decorator
  (pg.production "paren : LPAREN list_contents RPAREN")
  set-boundaries
  (defn paren
    [state p]
    (SQFExpression (get p 1))))

(with-decorator
  (pg.production "paren : LPAREN RPAREN")
  set-boundaries
  (defn empty-paren
    [state p]
    (SQFExpression [])))

(with-decorator (pg.production "list_contents : term list_contents")
  (defn list-contents
    [state p]
    (+ [(get p 0)] (get p 1))))

(with-decorator (pg.production "list_contents : term")
  (defn list-contents-single
    [state p]
    [(get p 0)]))

(with-decorator
  (pg.production "term : identifier")
  (pg.production "term : paren")
  (pg.production "term : list")
  (pg.production "term : dict")
  (pg.production "term : string")
  (defn term
    [state p]
    (get p 0)))

(with-decorator
  (pg.production "list : LBRACKET list_contents RBRACKET")
  set-boundaries
  (defn t-list
    [state p]
    (SQFList (get p 1))))

(with-decorator
  (pg.production "list : LBRACKET RBRACKET")
  set-boundaries
  (defn t-empty-list
    [state p]
    (SQFList [])))

(with-decorator
  (pg.production "dict : LCURLY list_contents RCURLY")
  set-boundaries
  (defn t-dict
    [state p]
    (SQFDict (get p 1))))

(with-decorator
  (pg.production "dict : LCURLY RCURLY")
  set-boundaries
  (defn t-empty-dict
    [state p]
    (SQFDict [])))

(with-decorator
  (pg.production "dict : HLCURLY list_contents RCURLY")
  set-boundaries
  (defn t-set
    [state p]
    (SQFSet (get p 1))))

(with-decorator
  (pg.production "dict : HLCURLY RCURLY")
  set-boundaries
  (defn t-empty-set
    [state p]
    (SQFSet [])))

(with-decorator
  (pg.production "string : STRING")
  set-boundaries
  (defn t-string
    [state p]
    (setv s (. (get p 0) value)
          is-format False)
    (setv s (s.strip "\""))

    ;; (if (and (s.startswith "f") (s.startswith "rf"))
    ;;     (setv is-format True
    ;;           s (s.replace "f" "" 1)))
    (try
      ;; (setv s (eval (-> s (.replace "\"" "\"\"\"" 1) (cut 0 -1) (+ "\"\"\""))))
      (except [e SyntaxError]
        (raise (LexException.from-lexer f"Can't convert {(. (get p 0) value)} to a SQFString" state (get p 0)))))

    (SQFString s)))

(defn symbol-like
  [obj]
  (try (return (SQFInteger obj))
       (except [e ValueError]))
  (try (return (SQFFloat obj))
       (except [e ValueError]))
  (if (and (obj.startswith ":") (not-in "." obj))
      (return (SQFKeyword obj))))

(with-decorator
  (pg.production "identifier : IDENTIFIER")
  set-boundaries
  (defn t-identifier
    [state p]
    (setv obj (. (get p 0) value )
          val (symbol-like obj))
    (if (not (is val None))
        (return val))
    (SQFSymbol (. (get p 0) value))))

(defclass ParserState
  [object]
  ""
  [])

(setv parser (pg.build))
