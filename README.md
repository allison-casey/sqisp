# arma-lisp

A lisp dialect that compiles to sqf.

## Features
- [ ] macros
- [ ] keywords
- [x] name mangling
- [ ] private by default

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
- [ ] case
- [ ] exitwith
- [ ] waituntil
- [ ] default
- [x] function call syntax
- [ ] comments

## Example

### Input Arma Lisp

```lisp
(= "hello" (if true "hello" "world"))
(def some_num (+ 2 -5 (/ 2.4 30 3.3) (- 20 33)))

(select (count (allUnits)) 2)

(def some_arr [1 2 3 4 5 6])
(if (or (>= some_num 223) (= (% some_num 2) 0))
    (str some_num)
    (if true "Hello" "World"))


(def my_val ( my_func "hello" "world" 24.3 ))

(def even? (fn [val] (= (% val 2) 0)))

(fn [a, b,,, c]
    (hint (str [a b c]))
    (hint "sub dog"))
```

### Output SQF

```sqf
("hello" == if (true) then {
    "hello";
} else {
    "world";
});
some_num = (2 + - 5 + (2.4 / 30 / 3.3) + (20 - 33));
((count allUnits) select 2);
some_arr = [1, 2, 3, 4, 5, 6];
if ((some_num >= 223) || ((some_num % 2) == 0)) then {
    (str some_num);
} else {
    if (true) then {
        "Hello";
    } else {
        "World";
    };
};
my_val = ["hello", "world", 24.3] call my_func;
is_even = {
    params ["val"];
    ((val % 2) == 0);
};
{
    params ["a", "b", "c"];
    (hint (str [a, b, c]));
    (hint "sub dog");
};
```
