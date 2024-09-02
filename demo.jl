using JuMP

model = Model()

# Sets
include("sets.jl")

# Load demo data (sets and parameters)
include("demo-data.jl")

# Compute parameters
include("parameters.jl")

#Containers.@container(COM_ISMEM[REGION, COMGRP, COMMTY], 0) #binary
#Containers.@container(RP_ISIRE[REGION, PROCESS], 0) #binary

# Compute additional sets
include("compute-sets.jl")

# Create Variables
include("variables.jl")

# %% Objective Function
@expression(model, obj, sum(RegObj[o, r, cur] for o in OBV for (r, cur) in RDCUR))
@objective(model, Min, obj)

# Specify constraints
include("constraints.jl")
