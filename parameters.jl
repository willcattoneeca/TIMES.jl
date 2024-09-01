using JuMP

Containers.@container(MILE[y in MODLYR], y in MILEYR ? 1 : 0)
Containers.@container(ISRP[r in REGION, p in PROCESS], (r, p) in RP ? 1 : 0)
