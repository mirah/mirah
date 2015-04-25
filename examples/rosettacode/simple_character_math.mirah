# A simple example of counting
# the characters in a name.  Part of a test
# to kick the tires - @aspleenic

puts "Enter a name: "

s = System.console.readLine()
puts "The name you entered was " + s

name_length = s.length
puts "Your Name is " + name_length + " characters long (that includes spaces)"
