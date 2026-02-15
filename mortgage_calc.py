import pandas as pd

P = 14000000
annual_rate = 1.75
i = annual_rate
n = 10

# P = 1_500_000
# annual_rate = 0.15
# i = annual_rate / 12
# n = 10*12

# monthly payment
PMT = P * (i*(1+i)**n) / ((1+i)**n - 1)

balance = P
rows = []

print("P:", P, "i:", annual_rate, "n:", n)
print("PMT:", PMT, "Total paid:", PMT*n)
print()

for month in range(1, n+1):
    interest = balance * i
    principal = PMT - interest
    balance = balance - principal
    rows.append({
        "Month": month,
        "Payment": round(PMT,2),
        "Principal": round(principal,2),
        "Interest": round(interest,2),
        "Remaining Balance": round(balance,2)
    })

df = pd.DataFrame(rows)
print(df)
# print(df.to_string())
