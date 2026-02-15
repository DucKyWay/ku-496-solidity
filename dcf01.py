r = 0.04

r_monthly = 0.04/12
print(r_monthly)

r_monthly_c = ((1+r)**(1/12)) - 1
print(r_monthly_c)

pv = 100

fv = pv * (1 + r_monthly) ** 12
print(fv)
