

macro def sqrt(input)
    quote do
        Math.sqrt(Integer.parseInt(`input`))
    end
end

number = '64'

puts sqrt '4'       # => 2
puts sqrt number    # => 8
