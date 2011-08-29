def getInput:int
    s = System.console.readLine()
    Integer.parseInt(s)
end


number = int(Math.random() * 10 + 1)

puts "guess the number between 1 and 10"
guessed = false
while !guessed do
    userNumber = getInput
    if userNumber == number
        guessed = true
        puts "you guessed it"
    elsif userNumber > number 
        puts "too high"
    else
        puts "too low"        
    end
end
