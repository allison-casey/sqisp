===========
Arma Lisp
===========


.. image:: https://img.shields.io/pypi/v/sqisp.svg
        :target: https://pypi.python.org/pypi/sqisp

.. image:: https://img.shields.io/travis/sjcasey21/sqisp.svg
        :target: https://travis-ci.org/sjcasey21/sqisp

.. image:: https://readthedocs.org/projects/sqisp/badge/?version=latest
        :target: https://sqisp.readthedocs.io/en/latest/?badge=latest
        :alt: Documentation Status




A lisp dialect that compiles to sqf.


* Free software: MIT license
* Documentation: https://sqisp.readthedocs.io.


Features
----------

- [ ] macros
- [ ] keywords
- [x] name mangling
- [x] private by default

Expressions
-------------

- [x] if
- [x] def
- [x] basic math expressions [+, -, \*, /, %]
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
- [x] setv

Example
-----------

Input Arma Lisp
---------------

.. code-block:: lisp
  ;; Import statement adds external sqf functions to the global namespace
  (import "someExternalFunction" "someOtherExternalFunction")

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

  (def my_func (fn [a b c]
                  (hint a)
                  (hint b)
                  (hint c)))
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

Output SQF
-----------

.. code-block::
  // imported someExternalFunction, someOtherExternalFunction;
  ("hello" == if (true) then
  {
      "hello"
  }
  else
  {
      "world"
  }
  );
  private _some_num = (2 + -5 + (2.4 / 30 / 3.3) + (20 - 33));
  ( ( count allUnits ) select 2 );
  private _some_arr = [1, 2, 3, 4, 5, 6];
  some_global = "hello global";
  anoher_global = "I can even have leading underscores!";
  if ((_some_num >= 223) || ((_some_num % 2) == 0)) then
  {
      ( str _some_num )
  }
  else
  {
      if (true) then
      {
          "Hello"
      }
      else
      {
          "World"
      }
  };
  private _my_func =
  {
      params ["_a", "_b", "_c"];
      ( hint _a );
      ( hint _b );
      ( hint _c )
  };
  private _my_val = ["hello", "world", 24.3] call _my_func;
  private _is_even =
  {
      params ["_val"];
      ((_val % 2) == 0)
  };
  {
      params ["_a", "_b", "_c"];
      ( hint ( str [_a, _b, _c] ) );
      ( hint "sub dog" )
  };
  for "_i" from 0 to 10 do
  {
      ( hint _i );
      ( hint "Hello For Loop!" )
  };
  for "_i" from 0 to 10 step 2 do
  {
      ( hint _i )
  };
  while
  {
      (_x < 10)
  }
  do
  {
      ( hint _x )
  };
  {
      private _x = _x;
  ( hint _x ) } forEach [1, 2, 3, 4]
