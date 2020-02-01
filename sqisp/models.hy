(defclass SQFObject [object]
  "sqfobject"
  []
  (defn --repr-- [self]
    (.format "{}({})"
             (. self --class-- --name--)
             (.--repr--(super SQFObject self)))))


(defclass SQFString [SQFObject str]
  "SQFString"
  []
  (defn --new-- [cls &optional [s None]]
    (.--new-- (super SQFString cls) cls s)))

(defclass SQFSequence [SQFObject tuple]
  "An abstract type for sequence-like models to inherit from."
  []
  (defn --add-- [self other]
    (.--class--
      self
      (.--add-- (super SQFSequence self)
                (if (isinstance other list) (tuple other) other))))

  (defn --getslice-- [self start end]
    (self.--class-- (.--getslice-- (super SQFSequence self) start end)))

  (defn --getitem-- [self item]
    (setv ret (.--getitem-- (super SQFSequence self) item))
    (if (isinstance item slice) (self.--class-- ret) ret))

  (defn --repr-- [self]
    (str self)))

(defclass SQFDict [SQFSequence])
(defclass SQFExpression [SQFObject tuple])
(defclass SQFList [SQFObject tuple])
(defclass SQFInteger [SQFObject int])
(defclass SQFFloat [SQFObject float])
(defclass SQFSymbol [SQFObject str]
  (defn --new-- [cls &optional [s None]]
    (.--new-- (super SQFSymbol cls) cls s)))
