(import copy
        importlib.resources
        logging
        [.macros [hy->sqf load-macros sqisp-macroexpand __sqisp_macros__]]
        [.types [builtin? get-base-fn-name]]
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
      _model-compilers {str (fn [compiler scope s] s)}
      _special-form-compilers {}
      _identity-symbols #{(SQFSymbol "true")
                          (SQFSymbol "false")}
      _operator-lookup {"=" "isEqualTo"
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
    (if (in value _identity-symbols)
        value
        (while True
          (cond [(in value scope.name) (return (get scope.name value))]
                [scope.parent (setv scope scope.parent)]
                [True (raise
                        (SyntaxError
                          f"function {value} referenced before assignment."))]))))

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
          self.can-use-stdlib True)

    (load-macros)
    (self._add-stdlib-to-scope))

  (defn compile-atom
    [self atom scope]
    ((get _model-compilers (type atom)) self scope atom))

  (defn compile
    [self tree &optional scope]
    (if-not scope
            (setv scope
                  (self.symbol-table.scope-from self.symbol-table.global-scope)))
    (if (none? tree) (return None))
    (if (isinstance tree list)
        (self._compile-implicit-do scope tree)
        (self.compile-atom tree scope)))

  (defn _compile-seq
    [self scope &rest args]
    (lfor arg args (self.compile arg scope)))

  (defn _add-stdlib-to-scope [self]
    "
    Adds all of the standard library function names to the
    file's global scope
    "
    (if-not self.can-use-stdlib (return))

    (setv stdlib-fn-names (lfor path (importlib.resources.contents stdlib)
                                :if (in ".sqp" path)
                                (-> path Path (. stem))))
    (for [fn-name stdlib-fn-names]
      (self.symbol-table.insert
        self.symbol-table.global-scope
        (SQFString fn-name)
        (self._mangle-global
          self.symbol-table.global-scope
          (mangle-cfgfunc fn-name)))))

  ;; ----------------
  ;; Compiler Helpers

  (defn _compile-implicit-do
    [self scope body]
    "Compile `body` wrapped in a `do` expression"
    (setv expr (SQFExpression [(SQFSymbol "do") #* body])
          root (SQFSymbol "do"))

    (self.compile-do-expression scope expr root body :iife False))

  (defn _mangle-global
    [self scope -name]
    "SQF requires globally scoped variables not have a leading underscore"
    (mangle (.lstrip  "_")))

  (defn _mangle-private
    [self scope -name]
    "SQF requires private variables to have a leading underscore"
    (mangle (if (.startswith -name "_")
                -name
                (+ "_" -name))))

  (defn compile-function-call
    [self scope root args]
    (setv sroot (self.compile root scope )
          sargs (lfor arg args (self.compile arg scope)))

    (if (builtin? sroot)
        (do
          (setv sroot (get-base-fn-name sroot))
          (cond [(zero? (len args)) sroot]
               [(= (len args) 1) f"({sroot} {(get sargs 0)})"]
               [(= (len args) 2) f"({(get sargs 0)} {sroot} {(get sargs 1)})"]
               [True f"({(get sargs 0)} {sroot} [{(.join \", \" (cut sargs 1))}])"]))
        (do
          (setv binding (if (root.startswith "{")
                            root
                            (self.symbol-table.lookup scope root))
                sargs (str.join ", " sargs))
          f"([{sargs}] call {binding})")))

  (with-decorator
    (special "+" [(many FORM)])
    (special "/" [(many FORM)])
    (special "*" [(many FORM)])
    (special "-" [(many FORM)])
    (defn compile-math-expression
      [self scope expr root args]
      (setv sroot (str root)
            sargs (self._compile-seq scope #* args)
            buff (.join f" {sroot} " sargs))
      f"({buff})"))

  (with-decorator
    (special ["and" "or"] [(many FORM)])
    (defn compile-and-or-expression
      [self scope expr root args]
      (setv sroot (self.compile root scope )
            sroot (get _operator-lookup sroot)
            args (self._compile-seq scope #* args))

      (cond [(zero? (len args)) "true"]
            [(= (len args) 1) (get args 0)]
            [True (+ f"{(get args 0)} {sroot} "
                     (.join f" {sroot} " (gfor arg (cut args 1)
                                               f"{{{arg}}}")))])))

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
      (setv sroot (get _operator-lookup (self.compile root scope))
            sargs (self._compile-seq scope #* args))

      (if (= (len sargs) 1)
          "true"
          (do
            (setv buff [])
            (for [(, left right) (pairwise sargs)]
              (setv left (self.compile left scope)
                    right (self.compile right scope))
              (buff.append f"({left} {sroot} {right})"))
            (str.join " && " buff)))))

  (with-decorator
    (special "reset!" [FORM FORM])
    (defn compile-reset-expression
      [self scope expr root -name value]
      (setv pname (self._mangle-private scope -name)
            value (self.compile value scope)
            defined-in-scope (bool (self.symbol-table.lookup scope -name)))
      (if defined-in-scope
          f"{pname} = {value}"
          (raise (SyntaxError f"attempting to reset undefined var: {-name}")))))

  (with-decorator
    (special "setv" [FORM FORM])
    (defn compile-setv-expression
      [self scope expr root -name value]
      (setv pname (self._mangle-private scope -name)
            value (self.compile value scope))
      (self.symbol-table.insert scope -name pname)
      f"private {pname} = {value}"))

  (with-decorator
    (special "setg" [FORM FORM])
    (defn compile-defglobal-expression
      [self scope expr root -name value]
      (setv gname (self._mangle-global scope -name))
      (self.symbol-table.insert scope -name gname)
      (setv value (self.compile value scope))
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
      [self scope expr root body &optional [iife True]]
      (if iife
          (self.compile-expression
            scope
            (hy->sqf `((fn [] ~@body))))
          (.join
            f"; {self._seperator}"
            (self._compile-seq scope #* body)))))

  (with-decorator
    (special "try" [(many FORM)])
    (defn compile-try-expression
      [self scope expr root body]
      (setv try-scope (self.symbol-table.scope-from scope)
            catch-scope (self.symbol-table.scope-from scope)
            last-expr (get body -1))
      (if-not (= (get last-expr 0) (SQFSymbol "catch"))
              (raise
                (TypeError "Try must have a catch block as the last expression.")))

      (setv (, catch-root exception-binding #* catch-body) last-expr)
      (self._seperator.join
        ["try {"
         (self.compile (hy->sqf `(do ~@(butlast body))) try-scope)
         "}"
         "catch {"
         (self.compile
           (hy->sqf `(do (setv ~exception-binding _exception)
                         ~@catch-body))
           catch-scope)
         "}"])))

  (with-decorator
    (special "if" [FORM FORM (maybe FORM)])
    (special "if*" [FORM FORM (maybe FORM)])
    (defn compile-if-expression
      [self scope expr root pred body else_expr]
      (setv pred (self.compile pred scope)
            if-scope (self.symbol-table.scope-from scope)
            else-scope (self.symbol-table.scope-from scope)
            body (self.compile body if-scope)
            else-expr (if else-expr (self.compile else-expr else-scope))
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
            iterator (get pred 0)
            (, start end #* step) (self._compile-seq scope #* (cut pred 1))
            step (if step (first step))
            siterator (self._mangle-private new-scope iterator))

      (if (isinstance iterator SQFSymbol)
          (self.symbol-table.insert new-scope iterator siterator))

      (setv body (self._compile-implicit-do new-scope body)
            sstep (if step f"step {step} " "")
            buffer [f"for \"{siterator}\" from {start} to {end} {sstep}do"
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

      (setv pred (self.compile pred scope )
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
          (, binding seq) initializer)
    (self.symbol-table.insert new-scope (get initializer 0) binding)
    (setv binding-expr (SQFExpression [(SQFSymbol "setv")
                                       (SQFSymbol binding)
                                       (SQFSymbol "x")])
          seq (self.compile
                (SQFExpression [(SQFSymbol "iter-items") seq])
                new-scope)
          body (self._compile-implicit-do new-scope (+ [binding-expr] body))
          buffer ["{" body "}" f" forEach {seq}"])
    (self._seperator.join buffer))

  (with-decorator
    (builds-model SQFString)
    (builds-model SQFKeyword)
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
    (builds-model SQFSet)
    (defn compile-set
      [self scope hash-set]
      (self.compile (SQFExpression [(SQFSymbol "hash-set") (SQFList hash-set)]) scope)))

  (with-decorator
    (builds-model SQFExpression)
    (defn compile-expression
      [self scope expr]

      (setv expr (sqisp-macroexpand expr))
      (if-not expr (raise (SyntaxError "Empty expression.")))
      (setv (, root #* args) (list expr)
            func None)
      (cond
        [(isinstance root SQFSymbol)
         (do
           (setv sroot (str root))
           (if (in sroot _special-form-compilers)
               (do (setv
                     (, build-method pattern) (get _special-form-compilers sroot))
                   (try
                     (setv parse-tree (pattern.parse args))
                     (except [e NoParseError]
                       (raise (SyntaxError "Parse error for form."))))
                   (build-method self scope expr sroot #* parse-tree))
               (self.compile-function-call scope sroot args)))]
        [(isinstance root SQFExpression)
         (self.compile-function-call
           scope
           (self.compile-expression scope root)
           args)]
          )
      )))
