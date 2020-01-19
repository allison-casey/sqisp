(import [rply [LexerGenerator]])

(setv lg (LexerGenerator)
      end-quote r"(?![\s\)\]}])"
      identifier r"[^()\[\]{}\'\"\s;]+")

(lg.add "LPAREN" r"\(")
(lg.add "RPAREN" r"\)")
(lg.add "LBRACKET" r"\[")
(lg.add "RBRACKET" r"\]")
(lg.add "QUOTE" (.format r"\'{}" end_quote))
(lg.add "QUASIQUOTE" (.format r"\`{}" end_quote))
(lg.add "UNQUOTESPLICE" (.format r"\~@{}" end_quote))
(lg.add "UNQUOTE" (.format r"\~{}" end_quote))

(setv partial-string r"(?x)
    (?:u|r|ur|ru|b|br|rb|f|fr|rf)? # prefix
    \"  # start string
    (?:
      | [^\"\\]             # non-quote or backslash
       | \\(.|\n)           # or escaped single character or newline
       | \\x[0-9a-fA-F]{2}  # or escaped raw character
       | \\u[0-9a-fA-F]{4}  # or unicode escape
       | \\U[0-9a-fA-F]{8}  # or long unicode escape
    )* # one or more times
")

(lg.add "STRING" (.format r"{}\"" partial-string))
(lg.add "IDENTIFIER" identifier)

(lg.ignore r";.*(?=\r|\n|$)")
(lg.ignore r"\s+")

(setv lexer (lg.build))
