(import copy
        importlib.resources
        logging
        [.macros [load-macros sqisp-macroexpand __sqisp_macros__]]
        [.types [is-builtin]]
        [.model-patterns [FORM whole times]]
        [.utils [mangle-cfgfunc mangle pairwise]]
        [.models [*]]
        [.bootstrap [stdlib]]
        [pathlib [Path]]
        [pprint [pprint]]
        [funcparserlib.parser [many oneplus maybe NoParseError]]
        [collections [defaultdict]]
        [anytree [Walker Node RenderTree AsciiStyle]])

(setv NEWLINE "\n"
      _model-compilers {}
      _special-form-compilers {}
      _operator-lookup {"=" "=="
                        "!=" "!="
                        "and" "&&"
                        "or" "||"
                        ">" ">"
                        ">=" ">="
                        "<=" "<="
                        "<" "<"
                        "%" "%"})


(defn special
  [names pattern]
  "Declare special operators. The decorated method and the given pattern
   is assigned to _special_form_compilers for each of the listed names."
  (setv pattern (whole pattern))
  (defn d [f]
    (for [-name (if (isinstance names list) names [names])]
      (setv (get _special-form-compilers (str -name)) (, f pattern)))
    f)
  d)

(defn builds-model
  [&rest model-types]
  (defn d [f]
    (for [t model-types]
      (setv (get _model-compilers t) f))
    f)
  d)

(defclass SymbolTable [object]
  (defn --init-- [self _globals]
    (setv self.global-scope (Node _globals)
          self._walker (Walker)))

  (defn scope-from [self scope]
    (Node {} :parent scope))

  (defn lookup
    [self scope value]
    (while True
      (cond [(in value scope.name) (return (get scope.name value))]
            [scope.parent (setv scope scope.parent)]
            [True (return None)])))

  (defn insert
    [self scope key value]
    (setv (get scope.name key) value)))

(defclass SQFASTCompiler [object]
  (defn --init--
    [self &optional [pretty False]]
    (setv self.pretty pretty
          self._seperator (if pretty NEWLINE "")
          self.symbol-table (SymbolTable {(SQFSymbol "this") "_this"
                                          (SQFSymbol "x") "_x"})
          self.can_use_stdlib True)
    (load-macros)

    (when self.can_use_stdlib
      (setv stdlib-fn-names (lfor path (importlib.resources.contents stdlib)
                                  :if (in ".sqp" path)
                                  (-> path Path (. stem))) )
      (for [fn-name stdlib-fn-names]
        (self.symbol-table.insert
          self.symbol-table.global-scope
          fn-name
          (self._mangle-global
            self.symbol-table.global-scope
            (mangle-cfgfunc fn-name))))))

  (defn compile-if-not-str
    [self scope value]
    (if (is (type value) str) value (self.compile value scope)))

  (defn compile-atom
    [self atom scope]
    ((get _model-compilers (type atom)) self scope atom))

  (defn compile-root
    [self root]
    (setv scope self.symbol-table.global-scope)
    (self.compile root scope))

  (defn compile
    [self tree scope]
    (if (none? tree) (return None))
    (self.compile-atom tree scope))

  (defn _compile-implicit-do
    [self scope body]
    (setv expr (SQFExpression [(SQFSymbol "do") #* body])
          root (SQFSymbol "do"))

    (self.compile-do-expression scope expr root body))

  (defn _mangle-global
    [self scope -name]
    (-> scope
        (self.compile-if-not-str -name)
        (.lstrip "_")))

  (defn _mangle-private
    [self scope -name]
    (as-> scope $
        (self.compile-if-not-str $ -name)
        (if (.startswith $ "_") $ (+ "_" $))))

  (defn compile-function-call
    [self scope root args]
    (setv sroot (self.compile-if-not-str scope root)
          sargs (lfor arg args (self.compile-if-not-str scope arg)))


    (if (is-builtin sroot)
        (cond [(zero? (len args)) sroot]
              [(= (len args) 1) f"({sroot} {(get sargs 0)})"]
              [(= (len args) 2) f"({(get sargs 0)} {sroot} {(get sargs 1)})"]
              [True f"({(get sargs 0)} {sroot} [{(.join \", \" (cut sargs 1))}])"])
        (do
          (setv binding (self.symbol-table.lookup scope root)
                sargs (str.join ", " sargs))
          (if-not binding
                  (raise (SyntaxError f"function {root} referenced before assignment."))
                  f"([{sargs}] call {binding})"))))

  (with-decorator
    (special "+" [(many FORM)])
    (special "/" [(many FORM)])
    (special "*" [(many FORM)])
    (special "-" [(many FORM)])
    (defn compile-math-expression
      [self scope expr root args]
      (setv sroot (str root)
            sargs (lfor arg args (self.compile-if-not-str scope arg))
            buff (.join f" {sroot} " sargs))
      f"({buff})"))

  (with-decorator
    (special ["and" "or"] [(many FORM)])
    (defn compile-and-or-expression
      [self scope expr root args]
      (setv sroot (self.compile-if-not-str scope root)
            sroot (get _operator-lookup sroot)
            args (lfor arg args (self.compile-if-not-str scope arg)))

      (cond [(zero? (len args)) "true"]
            [(= (len args 1)) (get args 0)]
            [True (.join f" {sroot} " args)])))

  (with-decorator
    (special  ["import"] [(many FORM)])
    (defn compile-import-expression
      [self scope expr root args]
      (if (any (gfor arg args (not (isinstance arg SQFSymbol))))
          (raise (SyntaxError f"Import only takes symbols, received {args}")))

      (for [arg args]
        (self.symbol-table.insert
          self.symbol-table.global-scope
          arg
          (self._mangle-global self.symbol-table.global-scope arg)))

      (+ "// imported " (str.join ", " args))))

  (with-decorator
    (special ["=" "<" "<=" ">" ">="] [(oneplus FORM)])
    (special ["!="] [(times 2 (float "inf") FORM)])
    (special ["%"] [(times 2 2 FORM)])
    (defn compile-math-expression
      [self scope expr root args]
      (setv sroot (get _operator-lookup (self.compile-if-not-str scope root))
            sargs (lfor arg args (self.compile-if-not-str scope arg)))

      (if (= (len sargs) 1)
          "true"
          (do
            (setv buff [])
            (for [(, left right) (pairwise sargs)]
              (setv left (self.compile-if-not-str scope left)
                    right (self.compile-if-not-str scope right))
              (buff.append f"({left} {sroot} {right})"))
            (str.join " && " buff)))))
  (with-decorator
    (special "reset!" [FORM FORM])
    (defn compile-reset-expression
      [self scope expr root -name value]
      (setv pname (self._mangle-private scope -name)
            value (self.compile-if-not-str scope value)
            defined-in-scope (bool (self.symbol-table.lookup scope -name)))
      (if defined-in-scope
          f"{pname} = {value}"
          (raise (SyntaxError f"attempting to reset undefined var: {-name}")))))

  (with-decorator
    (special "setv" [FORM FORM])
    (defn compile-setv-expression
      [self scope expr root -name value]
      (setv pname (self._mangle-private scope -name)
            value (self.compile-if-not-str scope value))
      (self.symbol-table.insert scope -name pname)
      f"private {pname} = {value}"))

  (with-decorator
    (special "setg" [FORM FORM])
    (defn compile-defglobal-expression
      [self scope expr root -name value]
      (setv value (self.compile-if-not-str scope value)
            gname (self._mangle-global scope -name))
      (self.symbol-table.insert scope -name gname)
      f"{gname} = {value}"))

  (with-decorator
    (special "fn" [FORM (many FORM)])
    (defn compile-fn-expression
      [self scope expr root args body]
      (if-not (isinstance args SQFList)
              (raise (SyntaxError "Args must be a list")))

      (setv new-scope (self.symbol-table.scope-from scope)
            sargs (lfor sarg args (self._mangle-private new-scope sarg)))

      (for [(, -name mname) (zip args sargs)]
        (self.symbol-table.insert new-scope -name mname))

      (setv sargs (.join ", " (gfor arg sargs f"\"{arg}\""))
            params [f"params [{sargs}]"])

      (self._seperator.join
        ["{"  (self._compile-implicit-do new-scope (+ params body)) "}"])))

  (with-decorator
    (special "params" [(many FORM)])
    (defn compile-params-expression
      [self scope expr root symbols]
      (if-not (all (gfor sym symbols (isinstance sym SQFSymbol)))
              (raise (ValueError "Params takes a list of symbols only")))

      (setv args (lfor sym symbols (self._mangle-private scope sym)))

      (for [(, -name mname) (zip symbols args)]
            (self.symbol-table.insert scope -name mname))

      (setv sargs (.join ", " (gfor arg args f"\"{arg}\"")))
      f"params [{sargs}]"))

  (with-decorator
    (special "do" [(many FORM)])
    (defn compile-do-expression
      [self scope expr root body]
      (.join
        f"; {self._seperator}"
        (gfor expression body (self.compile-if-not-str scope expression)))))

  (with-decorator
    (special "if" [FORM FORM (maybe FORM)])
    (special "if*" [FORM FORM (maybe FORM)])
    (defn compile-if-expression
      [self scope expr root pred body else_expr]
      (setv pred (self.compile-if-not-str scope pred)
            if-scope (self.symbol-table.scope-from scope)
            else-scope (self.symbol-table.scope-from scope)
            body (self.compile-if-not-str if-scope body)
            else-expr (if else-expr (self.compile-if-not-str else-scope else-expr))
            end (if else-expr "" ";")
            buff [f"if ({pred}) then" "{" f"{body}" f"}}{end}"])
      (if else-expr
          (setv buff (+ buff ["else" "{" f"{else-expr}" "}"])))
      (self._seperator.join buff)))

  (with-decorator
    (special "for" [FORM (many FORM)])
    (defn compile-for-expression
      [self scope expr root pred body]
      (if-not (isinstance pred SQFList)
              (raise (SyntaxError "condition must be a list")))

      (if (= (len pred) 2)
          (return (self._compile-doseq-expression scope expr root pred body)))

      (if (not-in (len pred) (range 3 (+ 4 1)))
          (raise (SyntaxError f"for takes 3 to 4 arguments {(len cond)} given.")))

      (setv new-scope (self.symbol-table.scope-from scope)
            pred (lfor val pred (self.compile-if-not-str scope val))
            iterator (self._mangle-private new-scope (get pred 0)))

      (self.symbol-table.insert new-scope (get pred 0) iterator)

      (setv start (get pred 1)
            end (get pred 2)
            step (if (= (len pred) 4) (get pred 3))
            body (self._compile-implicit-do new-scope body)
            sstep (if step f"step {step} " "")
            buffer [f"for \"{iterator}\" from {start} to {end} {sstep}do"
                    "{"
                    body
                    "}"])
      (self._seperator.join buffer)))

  (with-decorator
    (special "while" [FORM (many FORM)])
    (defn compile-while-expression
      [self scope expr root pred body]
      (if-not (isinstance pred SQFExpression)
              (raise (SyntaxError "while condition must be an expression")))

      (setv pred (self.compile-if-not-str scope pred)
            new-scope (self.symbol-table.scope-from scope)
            body (self._compile-implicit-do new-scope body)
            buffer [f"while {{{pred}}} do"
                    "{"
                    body
                    "}"])
      (self._seperator.join buffer)))

  (defn _compile-doseq-expression
    [self scope expr root initializer body]
    (if-not (isinstance initializer SQFList)
            (raise (SyntaxError "Initializer must be a list")))

    (if
      (!= (len initializer) 2)
      (raise
        (SyntaxError
          "Initializer must contain only the binding name and the sequence")))

    (setv new-scope (self.symbol-table.scope-from scope)
          (, binding seq) initializer
          binding (self.compile-if-not-str scope binding))
    (self.symbol-table.insert new-scope (get initializer 0) binding)
    (setv binding-expr (SQFExpression [(SQFSymbol "setv")
                                       (SQFSymbol binding)
                                       (SQFSymbol "_x")])
          seq (self.compile-if-not-str new-scope seq)
          body (self._compile-implicit-do new-scope (+ [binding-expr] body))
          buffer ["{" body "}" f" forEach {seq}"])
    (self._seperator.join buffer))

  (with-decorator
    (builds-model SQFString)
    (defn compile-string
      [self scope s]
      f"\"{s}\""))

  (with-decorator
    (builds-model SQFSymbol)
    (defn compile-symbol
      [self scope symbol]
      (setv lookup (self.symbol-table.lookup scope symbol))
      (if lookup lookup (mangle symbol))))

  (with-decorator
    (builds-model SQFList)
    (defn compile-list
      [self scope l]
      (+ "[" (.join ", " (gfor x l (self.compile x scope))) "]")))

  (with-decorator
    (builds-model SQFInteger)
    (builds-model SQFFloat)
    (defn compile-integer
      [self scope val]
      (str val)))

  (with-decorator
    (builds-model SQFDict)
    (defn compile-dict
      [self scope hash-map]
      (setv keys (cut hash-map None None 2)
            values (cut hash-map 1 None 2)
            pairs (SQFList (lfor (, k v) (zip keys values)
                                 (SQFList [k v]))))
      (self.compile (SQFExpression [(SQFSymbol "hash-map") pairs]) scope)))

  (with-decorator
    (builds-model SQFExpression)
    (defn compile-expression
      [self scope expr]

      (setv expr (sqisp-macroexpand expr))
      (if-not expr (raise (SyntaxError "Empty expression.")))
      (setv (, root #* args) (list expr)
            func None)
      (when (isinstance root SQFSymbol)
        (setv sroot (str root))
        (if (in sroot _special-form-compilers)
            (do (setv (, build-method pattern) (get _special-form-compilers sroot))
                (try
                  (setv parse-tree (pattern.parse args))
                  (except [e NoParseError]
                    (raise (SyntaxError "Parse error for form."))))
                (build-method self scope expr sroot #* parse-tree))
            (self.compile-function-call scope sroot args))))))
