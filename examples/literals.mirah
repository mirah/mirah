str = 'non-interpolated string'
str2 = "interpolated is better than #{str}"
heredoc = <<EOS
this is a here doc
EOS
int = 42
char = ?a
float = 3.14159265358979323846264
regex = /\d(cow)+\w\\/  # in Java, this would be "\\\\d(cow)+\\\\w\\\\\\\\"
regex2 = /interpolated #{regex}/
list = [1, 2, 3]
list[2] = 4
array = byte[5]
array[0] = byte(0)
hash = { "one" => 1, "two" => 2 }
hash["three"] = 3

