using JuMP;
#using HiGHS;
using GAMS;

model = Model()
# Sets
include("sets.jl")
# Load demo data (sets and parameters)
include("demo-data.jl")
# Compute parameters
include("parameters.jl")
# Compute additional sets
include("compute-sets.jl")
# Create Variables
include("variables.jl")
# %% Objective Function
@expression(model, obj, sum(RegObj[o, r, cur] for o in OBV for (r, cur) in RDCUR))
@objective(model, Min, obj)
# Specify constraints
include("constraints.jl")
# Set solver
#set_optimizer(model, HiGHS.Optimizer)
set_optimizer(model, GAMS.Optimizer)
set_optimizer_attribute(model, GAMS.Solver(), "CPLEX")
# Solve model
optimize!(model)
# Print solution summary
solution_summary(model)
