# arma-lisp

A lisp dialect that compiles to sqf.

## Features
- [ ] macros
- [ ] keywords
- [x] name mangling
- [x] private by default

## Expressions
- [x] if 
- [x] def
- [x] basic math expressions [+, -, *, /, %]
- [x] do 
- [x] logical operators [and, or, =, <, <=, >, >=, !=]
- [x] arrays
- [x] for
- [x] while
- [x] fn
- [x] foreach
- [ ] case      [NOTE]: May be unnecessary
- [ ] exitwith  [NOTE]: May be unnecessary
- [ ] waituntil [NOTE]: May be unnecessary
- [ ] default   [NOTE]: May be unnecessary
- [x] function call syntax
- [x] comments

## Example

### Input Arma Lisp

```lisp
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
```

### Output SQF

```sqf
("hello" == if (true) then {
    "hello";
} else {
    "world";
});
private _some_num = (2 + - 5 + (2.4 / 30 / 3.3) + (20 - 33));
((count allUnits) select 2);
private _some_arr = [1, 2, 3, 4, 5, 6];
some_global = "hello global";
anoher_global = "I can even have leading underscores!";
if ((some_num >= 223) || ((some_num % 2) == 0)) then {
    (str some_num);
} else {
    if (true) then {
        "Hello";
    } else {
        "World";
    };
};
private _my_val = ["hello", "world", 24.3] call my_func;
private _is_even = {
    params ["val"];
    ((val % 2) == 0);
};
{
    params ["a", "b", "c"];
    (hint (str [a, b, c]));
    (hint "sub dog");
};
for "i" from 0 to 10 do {
    (hint i);
    (hint "Hello For Loop!");
};
for "i" from 0 to 10 step 2 do {
    (hint i);
};
while {
    (x < 10);
} do {
    (hint x);
};
{
    private _x = _x;
    (hint x);
} forEach [1, 2, 3, 4];
```
