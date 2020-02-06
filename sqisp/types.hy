(import [pkg-resources [resource-stream resource-string resource-listdir]]
        re)

(setv types {})

(defn kebab->camel [s]
  (setv components (s.split "-"))
  (-> components
      (get 0)
      (+ (.join "" (gfor x (cut components 1) (x.title))))))

(defn builtin? [fn-name]
  (in (re.sub "-" "" (.lower fn-name)) types))

(defn get-base-fn-name [fn-name]
  (when (builtin? fn-name)
    (-> fn-name
        (.replace "bis/" "")
        kebab->camel)))

(defn parse-binary [line]
  (setv (, larg-type fn-name rarg-type) (.split (cut line 2)))
  (dict :type :binary
        :fn fn-name
        :left_arg_type (keyword larg-type)
        :right_arg_type (keyword rarg-type)))

(defn parse-unary [line]
  (setv (, fn-name arg-type) (.split (cut line 2)))
  (dict :type :unary
        :fn  fn-name
        :argtype arg-type))

(defn parse-nullary [line]
  (dict :type :nullary
        :fn (.strip (cut line 2))))

(defn parse-type [line]
  (dict :type :type
        :fn (.strip (cut line 2))))

(defn parse-line [line]
  (setv fn-type (get line 0)
        obj (cond [(= fn-type "b") (parse-binary line)]
                  [(= fn-type "u") (parse-unary line)]
                  [(= fn-type "n") (parse-nullary line)]
                  [(= fn-type "t") (parse-type line)])
        key (get obj "fn"))
  (, f"bis/{key}" obj))

(defn load-types [path]
  (global types)
  (setv f (resource-stream --name-- "types"))

  (for [line f]
    (setv line (.decode line "utf-8")
          (, k v) (parse-line line)
          (get types k) v)))
