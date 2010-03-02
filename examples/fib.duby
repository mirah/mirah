import java.lang.System

def fib(a:int)
  if a < 2
    a
  else
    fib(a - 1) + fib(a - 2)
  end
end

def bench(times:int)
  while times > 0
    time_start = System.currentTimeMillis
    puts "fib(45): #{fib(45)}\nTotal time: #{System.currentTimeMillis - time_start}"
    times -= 1
  end
  nil
end

bench 10
