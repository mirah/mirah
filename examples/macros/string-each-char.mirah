
macro def eachChar(value, &block)

    quote { 
        `value`.toCharArray.each do | my_char |
            `block.body`
        end 
    }
end

eachChar('laat de leeeuw niet in zijn hempie staan') do | my_char |
    puts my_char
end

