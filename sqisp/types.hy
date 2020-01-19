(import [pkg-resources [resource-stream resource-string resource-listdir]] )

(setv --types {})

(defn builtin? [fn-name]
  (in (.lower fn-name) --types))

(defn parse-binary [line]
  (setv (, larg-type fn-name rarg-type) (.split (cut line 2)))
  (, fn-name (dict :type "binary"
                   :left_arg_type larg-type
                   :right_arg_type rarg-type)))

(defn parse-unary [line]
  (setv (, fn-name arg-type) (.split (cut line 2)))
  (, fn-name (dict :type "unary" :argtype arg-type)))

(defn parse-nullary [line]
  (, (.strip (cut line 2)) (dict :type "nullary")))

(defn load-types [path]
  (global --types)
  (setv f (resource-stream --name-- "types"))

  (for [line f]
    (setv line (.decode line "utf-8")
          fn-type (get line 0))
    (cond [(= fn-type "b") (setv (, key value) (parse-binary line)
                                 (get --types key) value)]
          [(= fn-type "u") (setv (, key value) (parse-unary line)
                                 (get --types key) value)]
          [(= fn-type "n") (setv (, key value) (parse-nullary line)
                                 (get --types key) value)])))
