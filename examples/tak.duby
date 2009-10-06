def tak(x:fixnum, y:fixnum, z:fixnum)
  unless y < x
    z
  else
    tak( tak(x-1, y, z),
         tak(y-1, z, x),
         tak(z-1, x, y))
  end
end

i = 0
while i<1000
  tak(24, 16, 8)
  i+=1
end
