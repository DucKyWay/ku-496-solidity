import math

fv = float(input("fv: "))
r = float(input("r: "))
t = float(input("t: "))

# fv = pv * (1 + (r/n)) ** (n * t)
pv = fv / (1 + r) ** t
print(pv)
