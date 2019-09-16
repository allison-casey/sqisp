import copy

from pprint import pprint
from arma_lisp import compile





text = """
;; Equality operators
(= "hello" (if true "hello" "world"))

;; Math Operators
(def some_num (+ 2 -5 (/ 2.4 30 3.3) (- 20 33)))

;; Unified function call syntax
(select (count (allUnits)) 2)

;; Variable definition
(def some_arr [1 2 3 4 5 6])

;; Global Variable Definition
(defglobal some_global "hello global")
(defglobal __anoher_global "I can even have leading underscores!")

;; If Expression
(if (or (>= some_num 223) (= (% some_num 2) 0))
    (str some_num)
    (if true "Hello" "World"))

(def my_val ( my_func "hello" "world" 24.3 ))

;; Define Lambda Expression
(def even? (fn [val] (= (% val 2) 0)))

;; Commas are whitespace
(fn [a, b,,, c]
    (hint (str [a b c]))
    (hint "sub dog"))

;; For loop with optional step
(for [i 0 10]
    (hint i)
    (hint "Hello For Loop!"))

(for [i 0 10 2] ; some inline comment
    (hint i))

;; While Loop
(while (< x 10)
    (hint x))

;; Doseq (forEach) loop
(doseq [x [1, 2, 3, 4]]
    (hint x))
"""

# print("Input LispSQF:", '"""', text.strip(), '"""', sep="\n")
# print()
# print("Compiled SQF:", '"""', compiled_sqf, '"""', sep="\n")


sqf = compile(text)

import subprocess

file_name = "test.sqf"

with open(file_name, "w") as f:
    f.write(sqf)

result = subprocess.run(
    ["sqfvm", "--pretty-print", file_name, "-a", "-n", "-N"], capture_output=True
)

with open(file_name, "w") as f:
    f.write(result.stdout.decode('utf-8'))
