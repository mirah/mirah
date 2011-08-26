

def rot13 (value:string)
    result = ""
    d = ' '.toCharArray[0]
    value.toCharArray.each do |c|
        testChar = Character.toLowerCase(c)
        if testChar <= 'm'.toCharArray[0] && testChar >= 'a'.toCharArray[0] then 
            d = char(c + 13)
        end
        if testChar <= 'z'.toCharArray[0] && testChar >= 'n'.toCharArray[0] then 
            d = char(c - 13) 
        end 
        result += d
    end 
    result
end


puts rot13("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
