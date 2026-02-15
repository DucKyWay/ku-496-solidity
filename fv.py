import math

pv = float(input("pv: "))
r = float(input("r: "))
n = float(input("n: "))
t = float(input("t: "))

fv = pv * (1 + (r/n)) ** (n * t)
print(fv)
