# frozen_string_literal: true

Point = Data.define(:x, :y)

def identity(value) = value

case identity({ foo: 1, bar: 2 })
in { foo: 1, bar: } if bar.even?
  Point.new(x: bar, y: bar.succ)
else
  nil
end

identity({ foo: 1 }) => match
match
