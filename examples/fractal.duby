import java.lang.System

def run
  puts "Rendering"
  y = -39.0
  while y <= 39.0
    puts
    x = -39.0
    while x <= 39.0
      i = iterate(x/40.0,y/40.0)
      if (i == 0)
        print "*"
      else
        print " "
      end
      x += 1
    end
    y += 1
  end
  puts
end

def iterate(x:double,y:double)
  cr = y-0.5
  ci = x
  zi = 0.0
  zr = 0.0
  i = 0

  result = 0
  while true
    i += 1
    temp = zr * zi
    zr2 = zr * zr
    zi2 = zi * zi
    zr = zr2 - zi2 + cr
    zi = temp + temp + ci
    if (zi2 + zr2 > 16)
      result = i
      break
    end
    if (i > 1000)
      result = 0
      break
    end
  end

  result
end

i = 0
while i < 10
  start = System.currentTimeMillis
  run
  puts "Time: #{(System.currentTimeMillis - start) / 1000.0}"
  i += 1
end
