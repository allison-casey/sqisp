(import [.lexer [lexer]]
        [.models [SQFExpression
                  SQFList
                  SQFDict
                  SQFKeyword
                  SQFObject
                  SQFSequence
                  SQFString
                  SQFSymbol
                  SQFInteger
                  SQFFloat]]
        [rply [ParserGenerator]])

(setv pg (ParserGenerator (+ (lfor rule lexer.rules rule.name) ["$end"])))

(with-decorator (pg.production "main : list_contents")
  (defn main
    [state p]
    (get p 0)))

(with-decorator (pg.production "main : $end")
  (defn main-empty
    [state p]
    []))

(with-decorator (pg.production "term : QUOTE term")
  (defn term-quote
    [state p]
    (SQFExpression [(SQFSymbol "quote") (get p 1)])))

(with-decorator (pg.production "term : QUASIQUOTE term")
  (defn term-quasiquote
    [state p]
    (SQFExpression [(SQFSymbol "quasiquote") (get p 1)])))

(with-decorator (pg.production "term : UNQUOTE term")
  (defn term_unquote
    [state p]
    (SQFExpression [(SQFSymbol "unquote") (get p 1)])))

(with-decorator (pg.production "term : UNQUOTESPLICE term")
  (defn term_unquotesplice
    [state p]
    (SQFExpression [(SQFSymbol "unquote-splice") (get p 1)])))

(with-decorator (pg.production "paren : LPAREN list_contents RPAREN")
  (defn paren
    [state p]
    (SQFExpression (get p 1))))

(with-decorator (pg.production "paren : LPAREN RPAREN")
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

(with-decorator (pg.production "list : LBRACKET list_contents RBRACKET")
  (defn t-list
    [state p]
    (SQFList (get p 1))))

(with-decorator (pg.production "list : LBRACKET RBRACKET")
  (defn t-empty-list
    [state p]
    (SQFList [])))

(with-decorator (pg.production "dict : LCURLY list_contents RCURLY")
  (defn t-dict
    [state p]
    (SQFDict (get p 1))))

(with-decorator (pg.production "dict : LCURLY RCURLY")
  (defn t-empty-dict
    [state p]
    (SQFDict [])))

(with-decorator (pg.production "string : STRING")
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
  (if (and (obj.startswith ":") (not-in "." obj))))

(with-decorator (pg.production "identifier : IDENTIFIER")
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
