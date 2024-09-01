using JuMP

function PrcCap_bounds(r,y,p,bd)
    if (r,y,p,bd) in CAP_BND
        return CAP_BND[r,y,p,bd]
    end
    if bd == "LO"
        return 0
    end
    if bd == "UP"
        return Inf
    end
end

function PrcNcap_bounds(r,y,p,bd)
    if (r,y,p,bd) in NCAP_BND
        return NCAP_BND[r,y,p,bd]
    end
    if bd == "LO"
        return 0
    end
    if bd == "UP"
        return Inf
    end
end

# %% Variables
@variable(model, RegObj[OBV, REGION, CURRENCY] >= 0, container=SparseAxisArray)
@variable(model, ComPrd[REGION, MILEYR, COMMTY, TSLICE] >= 0, container=SparseAxisArray)
@variable(model, ComNet[REGION, MILEYR, COMMTY, TSLICE] >= 0, container=SparseAxisArray)
@variable(model, PrcCap_bounds(r,y,p,"LO") <= PrcCap[r in REGION, y in MODLYR, p in PROCESS] <= PrcCap_bounds(r,y,p,"UP"))
@variable(model, PrcNcap_bounds(r,y,p,"LO") <= PrcNcap[r in REGION, y in MODLYR, p in PROCESS] <= PrcNcap_bounds(r,y,p,"UP"))
@variable(model, PrcAct[REGION, YEAR, MILEYR, PROCESS, TSLICE] >= 0, container=SparseAxisArray)
@variable(model, PrcFlo[REGION, YEAR, MILEYR, PROCESS, COMMTY, TSLICE] >= 0, container=SparseAxisArray)
@variable(model, IreFlo[REGION, YEAR, MILEYR, PROCESS, COMMTY, TSLICE, IMPEXP] >= 0, container=SparseAxisArray)
@variable(model, StgFlo[REGION, YEAR, MILEYR, PROCESS, COMMTY, TSLICE, INOUT] >= 0, container=SparseAxisArray)