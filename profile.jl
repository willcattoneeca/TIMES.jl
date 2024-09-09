using JuMP;
using HiGHS;

using SQLite;
using DataFrames;
using JuMP;
using OrderedCollections: OrderedDict;

using Profile
using ProfileView

function run_model()

    @time "Create model" begin
        model = Model()
    end

    @time "System Sets" begin

        YEAR = string.(union(0, (1900:2200)))
        INOUT = Set(["IN", "OUT"])
        IMPEXP = Set(["IMP", "EXP"])
        LIM = Set(["LO", "UP", "FX", "N"])

        TSLVL = Set(["ANNUAL", "SEASON", "WEEKLY", "DAYNITE"])

        COM_TYPE = Set([
            "DEM",         # Demands
            "NRG",         # Energy
            "MAT",         # Material
            "ENV",         # Environmental
            "FIN",         # Financial
        ])

        PRC_GRP = Set([
            "XTRACT",  # Extraction
            "RENEW",   # Renewables (limited)
            "PRE",     # Energy
            "PRW",     # Material (by weight)
            "PRV",     # Material (by volume)
            "REF",     # Refined Products
            "ELE",     # Electric Generation
            "HPL",     # Heat Generation
            "CHP",     # Combined Heat+Power
            "DMD",     # Demand Devices
            "DISTR",   # Distribution Systems
            "CORR",    # Corridor Device'
            "STG",     # Storage
            "NST",     # Night (Off-peak) Storage
            "IRE",     # Inter-region exchange (IMPort/EXPort)
            "STK",     # Stockpiling
            "MISC",    # Miscellaneous
            "STS",     # Time-slice storage (excluding night storages)
        ])

        UPT = Set(["COLD", "WARM", "HOT"])

        UC_NAME = Set([
            "COST",
            "DELIV",
            "TAX",
            "SUB",
            "EFF",
            "NET",
            "N",
            "GROWTH",
            "PERIOD",
            "PERDISC",
            "BUILDUP",
            "CUMSUM",
            "CUM+",
            "SYNC",
            "YES",
            "CAPACT",
            "CAPFLO",
            "NEWFLO",
            "ONLINE",
            "ANNUL",
            "INVCOST",
            "INVTAX",
            "INVSUB",
            "FLO_COST",
            "FLO_DELIV",
            "FLO_SUB",
            "FLO_TAX",
            "NCAP_COST",
            "NCAP_ITAX",
            "NCAP_ISUB",
        ])

        UC_GRPTYPE = Set(["ACT", "FLO", "IRE", "CAP", "NCAP", "COMNET", "COMPRD", "COMCON", "UCN"])

        UC_COST = Set(["COST", "DELIV", "TAX", "SUB", "ANNUL"])

        COSTAGG = Set([
            "INV",
            "INVTAX",
            "INVSUB",
            "FOM",
            "FOMTAX",
            "FOMSUB",
            "COMTAX",
            "COMSUB",
            "FLOTAX",
            "FLOSUB",
            "INVTAXSUB",
            "INVALL",
            "FOMTAXSUB",
            "FOMALL",
            "FIX",
            "FIXTAX",
            "FIXSUB",
            "FIXTAXSUB",
            "FIXALL",
            "COMTAXSUB",
            "FLOTAXSUB",
            "ALLTAX",
            "ALLSUB",
            "ALLTAXSUB",
        ])

        # Internal Sets	
        OBV = Set(["OBJINV", "OBJFIX", "OBJVAR"])
    end


    @time "Get data" begin
        db = SQLite.DB("PROTO.db3")
        con = DBInterface

        queries = [
            # Sets
            Dict("query" => "SELECT ALLYEAR FROM MILESTONYR", "entity" => "MILEYR"),
            Dict("query" => "SELECT ALLYEAR FROM MODLYEAR", "entity" => "MODLYR"),
            Dict("query" => "SELECT ALL_TS FROM ALL_TS", "entity" => "TSLICE"),
            Dict("query" => "SELECT ALL_REG FROM ALL_REG", "entity" => "REGION"),
            Dict("query" => "SELECT PRC FROM PRC", "entity" => "PROCESS"),
            Dict("query" => "SELECT COM_GRP FROM COM_GRP", "entity" => "COMGRP"),
            Dict("query" => "SELECT COM_GRP FROM COM", "entity" => "COMMTY"),
            Dict("query" => "SELECT CUR FROM CUR", "entity" => "CURRENCY"),
            Dict("query" => "SELECT REG,CUR FROM RDCUR", "entity" => "RDCUR"),
            Dict("query" => "SELECT R,C FROM RC", "entity" => "RC"),
            Dict("query" => "SELECT R,P FROM RP", "entity" => "RP"),
            Dict("query" => "SELECT R,P FROM RP_FLO", "entity" => "RP_FLO"),
            Dict("query" => "SELECT R,P FROM RP_STD", "entity" => "RP_STD"),
            Dict("query" => "SELECT ALL_REG,P FROM RP_IRE", "entity" => "RP_IRE"),
            Dict("query" => "SELECT R,P FROM RP_STG", "entity" => "RP_STG"),
            Dict("query" => "SELECT R,P FROM RP_PGACT", "entity" => "RP_PGACT"),
            Dict("query" => "SELECT R,P FROM RP_PGFLO", "entity" => "RP_PGFLO"),
            Dict("query" => "SELECT REG,PRC FROM PRC_ACT", "entity" => "PRC_ACT"),
            Dict("query" => "SELECT REG,PRC FROM PRC_VINT", "entity" => "PRC_VINT"),
            Dict("query" => "SELECT R,P,IE FROM RP_AIRE", "entity" => "RP_AIRE"),
            Dict("query" => "SELECT REG,COM FROM DEM", "entity" => "DEM"),
            Dict("query" => "SELECT REG,COM_GRP,COM FROM COM_GMAP", "entity" => "COM_GMAP"),
            Dict("query" => "SELECT REG,PRC,COM,IO FROM TOP", "entity" => "TOP"),
            Dict("query" => "SELECT ALL_REG,PRC,ALL_TS FROM PRC_TS", "entity" => "PRC_TS"),
            Dict("query" => "SELECT R,P,ALL_TS FROM RPS_S1", "entity" => "RPS_S1"),
            Dict("query" => "SELECT R,P,S FROM RPS_STG", "entity" => "RPS_STG"),
            Dict("query" => "SELECT ALL_REG,ALL_TS,ALL_TS2 FROM TS_MAP", "entity" => "TS_MAP"),
            Dict("query" => "SELECT R,S,S2 FROM RS_PRETS", "entity" => "RS_PRETS"),
            Dict("query" => "SELECT R,P,C FROM RPC", "entity" => "RPC"),
            Dict("query" => "SELECT R,P,C FROM RPC_PG", "entity" => "RPC_PG"),
            Dict("query" => "SELECT ALL_REG,P,C,IE FROM RPC_IRE", "entity" => "RPC_IRE"),
            Dict("query" => "SELECT R,P,C FROM RPC_STG", "entity" => "RPC_STG"),
            Dict("query" => "SELECT REG,PRC,COM FROM PRC_STGTSS", "entity" => "PRC_STGTSS"),
            Dict("query" => "SELECT R,P,CG,IO FROM RPG_ACE", "entity" => "RPG_ACE"),
            Dict("query" => "SELECT REG,PRC,CG FROM RPC_ACE", "entity" => "RPC_ACE"),
            Dict("query" => "SELECT R,T,P,S,BD FROM AFS", "entity" => "AFS"),
            Dict("query" => "SELECT R,ALLYEAR,P FROM RTP", "entity" => "RTP"),
            Dict("query" => "SELECT R,ALLYEAR,P FROM RTP_VARA", "entity" => "RTP_VARA"),
            Dict("query" => "SELECT R,ALLYEAR,P,CUR FROM RTP_IPRI", "entity" => "RTP_IPRI"),
            Dict("query" => "SELECT R,T,P FROM RTP_VARP", "entity" => "RTP_VARP"),
            Dict("query" => "SELECT R,P,C,ALL_TS FROM RPCS_VAR", "entity" => "RPCS_VAR"),
            Dict("query" => "SELECT REG,PRC,CG,CG2 FROM RPCC_FFUNC", "entity" => "RPCC_FFUNC"),
            Dict(
                "query" => "SELECT REG,ALLYEAR,ALLYEAR2,PRC FROM RTP_VINTYR",
                "entity" => "RTP_VINTYR",
            ),
            Dict("query" => "SELECT R,ALLYEAR,C,ALL_TS FROM RTCS_VARC", "entity" => "RTCS"),
            Dict("query" => "SELECT R,ALLYEAR,C,S,LIM FROM RCS_COMBAL", "entity" => "RCS_COMBAL"),
            Dict("query" => "SELECT R,ALLYEAR,C,S,LIM FROM RCS_COMPRD", "entity" => "RCS_COMPRD"),
            Dict("query" => "SELECT R,ALLYEAR,C,S FROM RHS_COMPRD", "entity" => "RHS_COMPRD"),
            Dict("query" => "SELECT R,P,CG,CG2,S FROM RPFF_GGS", "entity" => "RP_PTRAN"),
            Dict("query" => "SELECT R,ALLYEAR,T,PRC FROM COEF_CPT", "entity" => "RTP_CPTYR"),
            Dict("query" => "SELECT R,T,ALLYEAR,CUR FROM OBJ_LINT", "entity" => "IS_LINT"),
            Dict("query" => "SELECT R,P,CUR,ALLYEAR FROM OB_ACT", "entity" => "IS_ACOST"),
            # Parameters
            Dict("query" => "SELECT ALL_REG,TS,value FROM G_YRFR", "entity" => "G_YRFR"),
            Dict("query" => "SELECT R,ALL_TS,value FROM RS_STGPRD", "entity" => "RS_STGPRD"),
            Dict("query" => "SELECT R,S,S2,value FROM RS_FR", "entity" => "RS_FR"),
            Dict("query" => "SELECT REG,PRC,value FROM PRC_CAPACT", "entity" => "PRC_CAPACT"),
            Dict("query" => "SELECT REG,PRC,value FROM PRC_SC", "entity" => "PRC_SC"),
            Dict("query" => "SELECT R,ALL_TS,value FROM RS_STGAV", "entity" => "RS_STGAV"),
            Dict("query" => "SELECT R,T,C,S,S2,value FROM RTCS_FR", "entity" => "RTCS_FR"),
            Dict("query" => "SELECT REG,ALLYEAR,COM,value FROM COM_PROJ", "entity" => "COM_PROJ"),
            Dict("query" => "SELECT REG,ALLYEAR,COM,TS,value FROM COM_IE", "entity" => "COM_IE"),
            Dict("query" => "SELECT REG,ALLYEAR,COM,TS,value FROM COM_FR", "entity" => "COM_FR"),
            Dict(
                "query" => "SELECT REG,ALLYEAR,PRC,value FROM NCAP_PASTI",
                "entity" => "NCAP_PASTI",
            ),
            Dict("query" => "SELECT REG,ALLYEAR,PRC,BD,value FROM CAP_BND", "entity" => "CAP_BND"),
            Dict(
                "query" => "SELECT REG,ALLYEAR,PRC,LIM,value FROM NCAP_BND",
                "entity" => "NCAP_BND",
            ),
            Dict("query" => "SELECT R,ALLYEAR,T,PRC,value FROM COEF_CPT", "entity" => "COEF_CPT"),
            Dict(
                "query" => "SELECT R,ALLYEAR,T,PRC,S,BD,value FROM COEF_AF",
                "entity" => "COEF_AF",
            ),
            Dict(
                "query" => "SELECT REG,ALLYEAR,PRC,CG,C,CG2,TS,value FROM COEF_PTRAN",
                "entity" => "COEF_PTRAN",
            ),
            Dict(
                "query" => "SELECT REG,ALLYEAR,PRC,C,CG,TS,BD,value FROM FLO_SHAR",
                "entity" => "FLO_SHAR",
            ),
            Dict(
                "query" => "SELECT REG,ALLYEAR,PRC,CG,value FROM PRC_ACTFLO",
                "entity" => "PRC_ACTFLO",
            ),
            Dict("query" => "SELECT REG,ALLYEAR,PRC,value FROM STG_EFF", "entity" => "STG_EFF"),
            Dict("query" => "SELECT REG,ALLYEAR,PRC,S,value FROM STG_LOSS", "entity" => "STG_LOSS"),
            Dict("query" => "SELECT REG,ALLYEAR,PRC,S,value FROM STG_CHRG", "entity" => "STG_CHRG"),
            Dict("query" => "SELECT REG,YEAR,PRC,CG,TS,value FROM ACT_EFF", "entity" => "ACT_EFF"),
            Dict("query" => "SELECT R,YEAR,CUR,value FROM OBJ_PVT", "entity" => "OBJ_PVT"),
            Dict("query" => "SELECT R,T,ALLYEAR,CUR,value FROM OBJ_LINT", "entity" => "OBJ_LINT"),
            Dict("query" => "SELECT R,P,CUR,ALLYEAR,value FROM OB_ACT", "entity" => "OBJ_ACOST"),
            Dict(
                "query" => "SELECT R,ALLYEAR,P,C,S,IE,CUR,value FROM OBJ_IPRIC",
                "entity" => "OBJ_IPRIC",
            ),
            Dict("query" => "SELECT R,YEAR,P,CUR,value FROM COEF_OBINV", "entity" => "COEF_OBINV"),
            Dict("query" => "SELECT R,YEAR,P,CUR,value FROM COEF_OBFIX", "entity" => "COEF_OBFIX"),
        ]

        function create_symbol(symbol::String, val::Any)
            eval(Meta.parse("$symbol = val"))
        end

        function read_data(queries::Vector{Dict{String,String}})::Dict{String,Any}
            data = Dict()
            for q in queries
                df = DataFrame(con.execute(db, q["query"]))
                row_number = nrow(df)
                col_number = ncol(df)
                # One-dimensional set
                if row_number > 0 && col_number == 1
                    data[q["entity"]] = Set(values(df[!, 1]))
                    # Multi-dimensional set or parameter
                elseif row_number > 0 && col_number > 1
                    if "value" in names(df)
                        dict = OrderedDict(Tuple.(eachrow(df[:, Not(:value)])) .=> df.value)
                        data[q["entity"]] = Containers.SparseAxisArray(dict)
                    else
                        data[q["entity"]] = Set(Tuple.(eachrow(df)))
                    end
                    # Empty set or parameter
                else
                    data[q["entity"]] = nothing
                end
            end
            return data
        end

        data = read_data(queries)

        # Create global variables
        symbol = nothing
        val = nothing

        # Create sets and parameters by iterating through data and changing values of global variables
        for (k, v) in data
            global symbol = k
            global val = v
            create_symbol(symbol, val)
        end

    end

    @time "Parameters" begin
        Containers.@container(MILE[y in MODLYR], y in MILEYR ? 1 : 0)
    end

    @time "Compute sets" begin
        LINTY = Containers.SparseAxisArray(
            Dict(
                (r, t, cur) => [y for y in MODLYR if (r, t, y, cur) in IS_LINT] for
                (r, t, y, cur) in IS_LINT
            ),
        )

        RTP_VNT = Containers.SparseAxisArray(
            Dict(
                (r, t, p) => [y for y in MODLYR if (r, y, t, p) in RTP_VINTYR] for
                (r, y, t, p) in RTP_VINTYR
            ),
        )

        RTP_CPT = Containers.SparseAxisArray(
            Dict(
                (r, t, p) => [y for y in MODLYR if (r, y, t, p) in RTP_CPTYR] for
                (r, y, t, p) in RTP_CPTYR
            ),
        )

        RTP_AFS = Containers.SparseAxisArray(
            Dict(
                (r, t, p, l) => [s for s in TSLICE if (r, t, p, s, l) in AFS] for
                (r, t, p, s, l) in AFS
            ),
        )

        RP_TS = Containers.SparseAxisArray(
            Dict((r, p) => [s for s in TSLICE if (r, p, s) in PRC_TS] for (r, p, s) in PRC_TS),
        )

        RP_S1 = Containers.SparseAxisArray(
            Dict((r, p) => [s for s in TSLICE if (r, p, s) in RPS_S1] for (r, p, s) in RPS_S1),
        )

        RP_PGC = Containers.SparseAxisArray(
            Dict((r, p) => [c for c in COMMTY if (r, p, c) in RPC_PG] for (r, p, c) in RPC_PG),
        )

        RP_CIE = Containers.SparseAxisArray(
            Dict(
                (r, p) =>
                    [(c, ie) for c in COMMTY for ie in IMPEXP if (r, p, c, ie) in RPC_IRE] for
                (r, p, c, ie) in RPC_IRE
            ),
        )

        RPC_TS = Containers.SparseAxisArray(
            Dict(
                (r, p, c) => [s for s in TSLICE if (r, p, c, s) in RPCS_VAR] for
                (r, p, c, s) in RPCS_VAR
            ),
        )

        RPIO_C = Containers.SparseAxisArray(
            Dict(
                (r, p, io) => [c for c in COMMTY if (r, p, c, io) in TOP] for (r, p, c, io) in TOP
            ),
        )

        RCIO_P = Containers.SparseAxisArray(
            Dict(
                (r, c, io) => [p for p in PROCESS if (r, p, c, io) in TOP] for (r, p, c, io) in TOP
            ),
        )

        RCIE_P = Containers.SparseAxisArray(
            Dict(
                (r, c, ie) => [p for p in PROCESS if (r, p, c, ie) in RPC_IRE] for
                (r, p, c, ie) in RPC_IRE
            ),
        )

        RP_ACE =
            !isnothing(RPC_ACE) ?
            Containers.SparseAxisArray(
                Dict(
                    (r, p) => [c for c in COMMTY if (r, p, c) in RPC_ACE] for (r, p, c) in RPC_ACE
                ),
            ) : nothing
    end

    @time "Variables" begin


        function PrcCap_bounds(r, y, p, bd)
            if (r, y, p, bd) in eachindex(CAP_BND)
                return CAP_BND[r, y, p, bd]
            end
            if bd == "LO"
                return 0
            end
            if bd == "UP"
                return Inf
            end
        end
        
        function PrcNcap_bounds(r, y, p, bd)
            if (r, y, p, bd) in eachindex(NCAP_BND)
                return NCAP_BND[r, y, p, bd]
            end
            if bd == "LO"
                return 0
            end
            if bd == "UP"
                return Inf
            end
        end
        
        # %% Variables
        @variable(model, RegObj[OBV, REGION, CURRENCY] >= 0)
        @variable(model, ComPrd[REGION, MILEYR, COMMTY, TSLICE] >= 0)
        @variable(model, ComNet[REGION, MILEYR, COMMTY, TSLICE] >= 0)
        @variable(
            model,
            PrcCap_bounds(r, v, p, "LO") <=
            PrcCap[r in REGION, v in MODLYR, p in PROCESS] <=
            PrcCap_bounds(r, v, p, "UP")
        )
        @variable(
            model,
            PrcNcap_bounds(r, v, p, "LO") <=
            PrcNcap[r in REGION, v in MODLYR, p in PROCESS] <=
            PrcNcap_bounds(r, v, p, "UP")
        )
        @variable(
            model,
            PrcAct[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in PROCESS,
                s in TSLICE;
                ((r, t, p) in RTP_VARA) && ((r, v, t, p) in RTP_VINTYR) && ((r, p, s) in PRC_TS),
            ] >= 0
        )
        @variable(
            model,
            PrcFlo[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in PROCESS,
                c in COMMTY,
                s in TSLICE;
                ((r, p) in RP_FLO) &&
                ((r, t, p) in RTP_VARA) &&
                ((r, v, t, p) in RTP_VINTYR) &&
                ((r, p, c) in RPC) &&
                ((r, p, c, s) in RPCS_VAR),
            ] >= 0
        )
        @variable(
            model,
            IreFlo[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in PROCESS,
                c in COMMTY,
                s in TSLICE,
                ie in IMPEXP;
                ((r, p) in RP_IRE) &&
                ((r, t, p) in RTP_VARA) &&
                ((r, v, t, p) in RTP_VINTYR) &&
                ((r, p, c) in RPC) &&
                ((r, p, s) in PRC_TS) &&
                ((r, p, c, ie) in RPC_IRE),
            ] >= 0
        )
        @variable(
            model,
            StgFlo[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in PROCESS,
                c in COMMTY,
                s in TSLICE,
                io in INOUT;
                ((r, p) in RP_STG) &&
                ((r, t, p) in RTP_VARA) &&
                ((r, v, t, p) in RTP_VINTYR) &&
                ((r, p, c) in RPC) &&
                ((r, p, s) in PRC_TS) &&
                ((r, p, c, io) in TOP),
            ] >= 0
        )
        
    end

    @time "Objective" begin
        @expression(model, obj, sum(RegObj[o, r, cur] for o in OBV for (r, cur) in RDCUR))
        @objective(model, Min, obj)
    end

    @time "Constraints" begin
        # Objective function constituents
        @time "EQ_OBJINV" @constraint(
            model,
            EQ_OBJINV[r in REGION, cur in CURRENCY; (r, cur) in RDCUR],
            sum(
                (
                    OBJ_PVT[r, t, cur] *
                    COEF_CPT[r, v, t, p] *
                    COEF_OBINV[r, v, p, cur] *
                    (
                        (v in MILEYR ? PrcNcap[r, v, p] : 0) +
                        ((r, v, p) in eachindex(NCAP_PASTI) ? NCAP_PASTI[r, v, p] : 0)
                    )
                ) for (r, v, t, p) in RTP_CPTYR if (r, v, p, cur) in eachindex(COEF_OBINV)
            ) == RegObj["OBJINV", r, cur]
        )

        @time "EQ_OBJFIX" @constraint(
            model,
            EQ_OBJFIX[r in REGION, cur in CURRENCY; (r, cur) in RDCUR],
            sum(
                (
                    OBJ_PVT[r, t, cur] *
                    COEF_CPT[r, v, t, p] *
                    COEF_OBFIX[r, v, p, cur] *
                    (
                        (v in MILEYR ? PrcNcap[r, v, p] : 0) +
                        ((r, v, p) in eachindex(NCAP_PASTI) ? NCAP_PASTI[r, v, p] : 0)
                    )
                ) for (r, v, t, p) in RTP_CPTYR if (r, v, p, cur) in eachindex(COEF_OBFIX)
            ) == RegObj["OBJFIX", r, cur]
        )

        @time "EQ_OBJVAR" @constraint(
            model,
            EQ_OBJVAR[r in REGION, cur in CURRENCY; (r, cur) in RDCUR],
            sum(
                sum(
                    (
                        (r, p, cur, t) in eachindex(OBJ_ACOST) ?
                        sum(
                            OBJ_LINT[r, t, y, cur] * OBJ_ACOST[r, p, cur, y] for
                            y in LINTY[r, t, cur]
                        ) * sum(
                            PrcAct[r, v, t, p, s] * ((r, p) in RP_STG ? RS_STGAV[r, s] : 1) for
                            v in RTP_VNT[r, t, p] for s in RP_TS[r, p]
                        ) : 0
                    ) + (
                        (r, t, p, cur) in RTP_IPRI ?
                        sum(
                            sum(
                                OBJ_LINT[r, t, y, cur] * OBJ_IPRIC[r, y, p, c, s, ie, cur] for
                                y in LINTY[r, t, cur]
                            ) * sum(IreFlo[r, v, t, p, c, s, ie] for v in RTP_VNT[r, t, p]) for
                            s in RP_TS[r, p] for (c, ie) in RP_CIE[r, p]
                        ) : 0
                    ) for t in MILEYR if (r, t, p) in RTP_VARA
                ) for p in PROCESS if (r, p) in RP
            ) == RegObj["OBJVAR", r, cur]
        )

        # %% Activity to Primary Group
        @time "EQ_ACTFLO" @constraint(
            model,
            EQ_ACTFLO[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in PROCESS,
                s in TSLICE;
                (r, v, t, p) in RTP_VINTYR && (r, p) in PRC_ACT && s in RP_TS[r, p],
            ],
            ((r, t, p) in RTP_VARA ? PrcAct[r, v, t, p, s] : 0) == sum(
                (
                    (r, p) in RP_IRE ?
                    sum(IreFlo[r, v, t, p, c, s, ie] for ie in IMPEXP if (r, p, ie) in RP_AIRE) :
                    PrcFlo[r, v, t, p, c, s]
                ) for c in RP_PGC[r, p]
            )
        )

        # %% Activity to Capacity
        @time "EQL_CAPACT" @constraint(
            model,
            EQL_CAPACT[
                r in REGION,
                v in MODLYR,
                y in MILEYR,
                p in PROCESS,
                s in TSLICE;
                (r, v, y, p) in RTP_VINTYR &&
                (r, y, p, "UP") in eachindex(RTP_AFS) &&
                s in RTP_AFS[r, y, p, "UP"],
            ],
            (
                (r, p) in RP_STG ?
                sum(
                    PrcAct[r, v, y, p, ts] *
                    RS_FR[r, ts, s] *
                    exp(isnothing(PRC_SC) ? 0 : PRC_SC[r, p]) / RS_STGPRD[r, s] for
                    ts in RP_TS[r, p] if (r, s, ts) in eachindex(RS_FR)
                ) :
                sum(PrcAct[r, v, y, p, ts] for ts in RP_TS[r, p] if (r, s, ts) in eachindex(RS_FR))
            ) <= (
                ((r, p) in RP_STG ? 1 : G_YRFR[r, s]) *
                PRC_CAPACT[r, p] *
                (
                    (r, p) in PRC_VINT ?
                    COEF_AF[r, v, y, p, s, "UP"] *
                    COEF_CPT[r, v, y, p] *
                    (
                        MILE[v] * PrcNcap[r, v, p] +
                        ((r, v, p) in eachindex(NCAP_PASTI) ? NCAP_PASTI[r, v, p] : 0)
                    ) :
                    sum(
                        COEF_AF[r, m, y, p, s, "UP"] *
                        COEF_CPT[r, m, y, p] *
                        (
                            (MILE[m] * PrcNcap[r, m, p]) +
                            ((r, m, p) in eachindex(NCAP_PASTI) ? NCAP_PASTI[r, m, p] : 0)
                        ) for m in RTP_CPT[r, y, p]
                    )
                )
            )
        )


        @time "EQE_CAPACT" @constraint(
            model,
            EQE_CAPACT[
                r in REGION,
                v in MODLYR,
                y in MILEYR,
                p in PROCESS,
                s in TSLICE;
                (r, v, y, p) in RTP_VINTYR &&
                (r, y, p, "FX") in eachindex(RTP_AFS) &&
                s in RTP_AFS[r, y, p, "FX"],
            ],
            (
                (r, p) in RP_STG ?
                sum(
                    PrcAct[r, v, y, p, ts] *
                    RS_FR[r, ts, s] *
                    exp(isnothing(PRC_SC) ? 0 : PRC_SC[r, p]) / RS_STGPRD[r, s] for
                    ts in RP_TS[r, p] if (r, s, ts) in eachindex(RS_FR)
                ) :
                sum(PrcAct[r, v, y, p, ts] for ts in RP_TS[r, p] if (r, s, ts) in eachindex(RS_FR))
            ) == (
                ((r, p) in RP_STG ? 1 : G_YRFR[r, s]) *
                PRC_CAPACT[r, p] *
                (
                    (r, p) in PRC_VINT ?
                    COEF_AF[r, v, y, p, s, "FX"] *
                    COEF_CPT[r, v, y, p] *
                    (MILE[v] * PrcNcap[r, v, p] + NCAP_PASTI[r, v, p]) :
                    sum(
                        COEF_AF[r, m, y, p, s, "FX"] *
                        COEF_CPT[r, m, y, p] *
                        ((MILE[m] * PrcNcap[r, m, p]) + NCAP_PASTI[r, m, p]) for
                        m in RTP_CPT[r, y, p]
                    )
                )
            )
        )

        # %% Capacity Transfer
        @time "EQE_CPT" @constraint(
            model,
            EQE_CPT[
                r in REGION,
                y in MODLYR,
                p in PROCESS;
                (r, y, p) in RTP &&
                ((r, y, p) in RTP_VARP || (r, y, p, "FX") in eachindex(CAP_BND)),
            ],
            ((r, y, p) in RTP_VARP ? PrcCap[r, y, p] : CAP_BND[r, y, p, "FX"]) == sum(
                COEF_CPT[r, v, y, p] * (
                    (MILE[v] * PrcNcap[r, v, p]) +
                    ((r, v, p) in eachindex(NCAP_PASTI) ? NCAP_PASTI[r, v, p] : 0)
                ) for v in RTP_CPT[r, y, p]
            )
        )

        @time "EQL_CPT" @constraint(
            model,
            EQL_CPT[
                r in REGION,
                y in MODLYR,
                p in PROCESS;
                (r, y, p) in RTP &&
                (!((r, y, p) in RTP_VARP) && (r, y, p, "LO") in eachindex(CAP_BND)),
            ],
            ((r, y, p) in RTP_VARP ? PrcCap[r, y, p] : CAP_BND[r, y, p, "LO"]) <= sum(
                COEF_CPT[r, v, y, p] * (
                    (MILE[v] * PrcNcap[r, v, p]) +
                    ((r, v, p) in eachindex(NCAP_PASTI) ? NCAP_PASTI[r, v, p] : 0)
                ) for v in RTP_CPT[r, y, p]
            )
        )

        @time "EQG_CPT" @constraint(
            model,
            EQG_CPT[
                r in REGION,
                y in MODLYR,
                p in PROCESS;
                (r, y, p) in RTP &&
                (!((r, y, p) in RTP_VARP) && (r, y, p, "UP") in eachindex(CAP_BND)),
            ],
            ((r, y, p) in RTP_VARP ? PrcCap[r, y, p] : CAP_BND[r, y, p, "UP"]) >= sum(
                COEF_CPT[r, v, y, p] * (
                    (MILE[v] * PrcNcap[r, v, p]) +
                    ((r, v, p) in eachindex(NCAP_PASTI) ? NCAP_PASTI[r, v, p] : 0)
                ) for v in RTP_CPT[r, y, p]
            )
        )

        # %% Process Flow Shares
        @time "EQL_FLOSHR" @constraint(
            model,
            EQL_FLOSHR[
                r in REGION,
                v in MODLYR,
                p in PROCESS,
                c in COMMTY,
                cg in COMGRP,
                s in TSLICE,
                l in ["LO"],
                t in MILEYR;
                (r, v, p, c, cg, s, l) in eachindex(FLO_SHAR) &&
                (r, t, p) in RTP_VARA &&
                v in RTP_VNT[r, t, p] &&
                s in RPC_TS[r, p, c],
            ],
            sum(
                FLO_SHAR[r, v, p, c, cg, s, l] * sum(
                    PrcFlo[r, v, t, p, com, ts] * RS_FR[r, s, ts] for com in RPIO_C[r, p, io] for
                    ts in RPC_TS[r, p, com] if
                    ((r, cg, com) in COM_GMAP && (r, s, ts) in eachindex(RS_FR))
                ) for io in INOUT if c in RPIO_C[r, p, io]
            ) <= PrcFlo[r, v, t, p, c, s]
        )

        @time "EQL_FLOSHR" @constraint(
            model,
            EQG_FLOSHR[
                r in REGION,
                v in MODLYR,
                p in PROCESS,
                c in COMMTY,
                cg in COMGRP,
                s in TSLICE,
                l in ["UP"],
                t in MILEYR;
                (r, v, p, c, cg, s, l) in eachindex(FLO_SHAR) &&
                (r, t, p) in RTP_VARA &&
                v in RTP_VNT[r, t, p] &&
                s in RPC_TS[r, p, c],
            ],
            sum(
                FLO_SHAR[r, v, p, c, cg, s, l] * sum(
                    PrcFlo[r, v, t, p, com, ts] * RS_FR[r, s, ts] for com in RPIO_C[r, p, io] for
                    ts in RPC_TS[r, p, com] if
                    ((r, cg, com) in COM_GMAP && (r, s, ts) in eachindex(RS_FR))
                ) for io in INOUT if c in RPIO_C[r, p, io]
            ) >= PrcFlo[r, v, t, p, c, s]
        )

        @time "EQL_FLOSHR" @constraint(
            model,
            EQE_FLOSHR[
                r in REGION,
                v in MODLYR,
                p in PROCESS,
                c in COMMTY,
                cg in COMGRP,
                s in TSLICE,
                l in ["FX"],
                t in MILEYR;
                (r, v, p, c, cg, s, l) in eachindex(FLO_SHAR) &&
                (r, t, p) in RTP_VARA &&
                v in RTP_VNT[r, t, p] &&
                s in RPC_TS[r, p, c],
            ],
            (
                sum(
                    FLO_SHAR[r, v, p, c, cg, s, l] * sum(
                        PrcFlo[r, v, t, p, com, ts] * RS_FR[r, s, ts] for com in RPIO_C[r, p, io]
                        for ts in RPC_TS[r, p, com] if
                        ((r, cg, com) in COM_GMAP && (r, s, ts) in eachindex(RS_FR))
                    ) for io in INOUT if c in RPIO_C[r, p, io]
                ) == PrcFlo[r, v, t, p, c, s]
            )
        )

        # %% Activity efficiency:
        @time "EQE_ACTEFF" @constraint(
            model,
            EQE_ACTEFF[
                r in REGION,
                p in PROCESS,
                cg in COMGRP,
                io in INOUT,
                t in MILEYR,
                v in MODLYR,
                s in TSLICE;
                !isnothing(RPG_ACE) &&
                (r, p, cg, io) in RPG_ACE &&
                s in RP_S1[r, p] &&
                (r, t, p) in RTP_VARA &&
                v in RTP_VNT[r, t, p],
            ],
            (
                !isnothing(RP_ACE) ?
                sum(
                    sum(
                        PrcFlo[r, v, t, p, c, ts] *
                        ((r, v, p, c, ts) in eachindex(ACT_EFF) ? ACT_EFF[r, v, p, c, ts] : 1) *
                        RS_FR[r, s, ts] *
                        (1 + RTCS_FR[r, t, c, s, ts]) for
                        ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                    ) for c in RP_ACE[r, p] if (r, cg, c) in COM_GMAP
                ) : 0
            ) == sum(
                RS_FR[r, s, ts] * (
                    (r, p) in RP_PGFLO ?
                    sum(
                        (
                            (r, p) in RP_PGACT ? PrcAct[r, v, t, p, ts] :
                            PrcFlo[r, v, t, p, c, ts] / PRC_ACTFLO[r, v, p, c]
                        ) / ((r, v, p, c, ts) in eachindex(ACT_EFF) ? ACT_EFF[r, v, p, c, ts] : 1) *
                        (1 + RTCS_FR[r, t, c, s, ts]) for c in RP_PGC[r, p]
                    ) : PrcAct[r, v, t, p, ts]
                ) / max(1e-6, ACT_EFF[r, v, p, cg, ts]) for
                ts in RP_TS[r, p] if (r, s, ts) in eachindex(RS_FR)
            )
        )

        # %% Process Transformation SLOW
        @time "EQ_PTRANS" @constraint(
            model,
            EQ_PTRANS[
                r in REGION,
                p in PROCESS,
                cg1 in COMGRP,
                cg2 in COMGRP,
                s1 in TSLICE,
                t in MILEYR,
                v in MODLYR,
                s in TSLICE;
                (r, p, cg1, cg2, s1) in RP_PTRAN &&
                (r, s1, s) in eachindex(RS_FR) &&
                s in RP_S1[r, p] &&
                (r, t, p) in RTP_VARA &&
                v in RTP_VNT[r, t, p],
            ],
            sum(
                sum(
                    PrcFlo[r, v, t, p, c, ts] *
                    RS_FR[r, s, ts] *
                    (1 + ((r, t, c, s, ts) in eachindex(RTCS_FR) ? RTCS_FR[r, t, c, s, ts] : 0)) for
                    ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                ) for io in INOUT for c in RPIO_C[r, p, io] if (r, cg2, c) in COM_GMAP
            ) == sum(
                COEF_PTRAN[r, v, p, cg1, c, cg2, ts] *
                RS_FR[r, s, ts] *
                (1 + ((r, t, c, s, ts) in eachindex(RTCS_FR) ? RTCS_FR[r, t, c, s, ts] : 0)) *
                PrcFlo[r, v, t, p, c, ts] for io in INOUT for c in RPIO_C[r, p, io] for
                ts in RPC_TS[r, p, c] if (
                    (r, s, ts) in eachindex(RS_FR) ?
                    ((r, v, p, cg1, c, cg2, ts) in eachindex(COEF_PTRAN) ? true : false) : false
                )
            )
        )


        # %% Commodity Balance - Greater
        @time "EQG_COMBAL" @constraint(
            model,
            EQG_COMBAL[
                r in REGION,
                t in MILEYR,
                c in COMMTY,
                s in TSLICE;
                (r, t, c, s, "LO") in RCS_COMBAL,
            ],
            (
                !isnothing(RHS_COMPRD) && ((r, t, c, s) in RHS_COMPRD) ? ComPrd[r, t, c, s] :
                (
                    (
                        (r, c, "OUT") in eachindex(RCIO_P) ?
                        sum(
                            (
                                (r, p, c) in RPC_STG ?
                                sum(
                                    sum(
                                        StgFlo[r, v, t, p, c, ts, "OUT"] *
                                        RS_FR[r, s, ts] *
                                        (
                                            1 + (
                                                (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                                RTCS_FR[r, t, c, s, ts] : 0
                                            )
                                        ) *
                                        STG_EFF[r, v, p] for v in RTP_VNT[r, t, p]
                                    ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                                ) :
                                sum(
                                    sum(
                                        PrcFlo[r, v, t, p, c, ts] *
                                        RS_FR[r, s, ts] *
                                        (
                                            1 + (
                                                (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                                RTCS_FR[r, t, c, s, ts] : 0
                                            )
                                        ) for v in RTP_VNT[r, t, p]
                                    ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                                )
                            ) for p in RCIO_P[r, c, "OUT"] if (r, t, p) in RTP_VARA
                        ) : 0
                    ) + (
                        (r, c, "IMP") in eachindex(RCIE_P) ?
                        sum(
                            sum(
                                sum(
                                    IreFlo[r, v, t, p, c, ts, "IMP"] *
                                    RS_FR[r, s, ts] *
                                    (
                                        1 + (
                                            (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                            RTCS_FR[r, t, c, s, ts] : 0
                                        )
                                    ) for v in RTP_VNT[r, t, p]
                                ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                            ) for p in RCIE_P[r, c, "IMP"] if (r, t, p) in RTP_VARA
                        ) : 0
                    )
                ) * COM_IE[r, t, c, s]
            ) >=
            (
                (r, c, "IN") in eachindex(RCIO_P) ?
                sum(
                    (
                        (r, p, c) in RPC_STG ?
                        sum(
                            sum(
                                StgFlo[r, v, t, p, c, ts, "IN"] *
                                RS_FR[r, s, ts] *
                                (
                                    1 + (
                                        (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                        RTCS_FR[r, t, c, s, ts] : 0
                                    )
                                ) for v in RTP_VNT[r, t, p]
                            ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                        ) :
                        (sum(
                            sum(
                                PrcFlo[r, v, t, p, c, ts] *
                                RS_FR[r, s, ts] *
                                (
                                    1 + (
                                        (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                        RTCS_FR[r, t, c, s, ts] : 0
                                    )
                                ) for v in RTP_VNT[r, t, p]
                            ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                        ))
                    ) for p in RCIO_P[r, c, "IN"] if (r, t, p) in RTP_VARA
                ) : 0
            ) +
            (
                (r, c, "EXP") in eachindex(RCIE_P) ?
                sum(
                    sum(
                        sum(
                            IreFlo[r, v, t, p, c, ts, "EXP"] *
                            RS_FR[r, s, ts] *
                            (
                                1 + (
                                    (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                    RTCS_FR[r, t, c, s, ts] : 0
                                )
                            ) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                    ) for p in RCIE_P[r, c, "EXP"] if (r, t, p) in RTP_VARA
                ) : 0
            ) +
            ((r, t, c) in eachindex(COM_PROJ) ? COM_PROJ[r, t, c] * COM_FR[r, t, c, s] : 0)
        )

        # %% Commodity Balance - Equal
        @time "EQE_COMBAL" @constraint(
            model,
            EQE_COMBAL[
                r in REGION,
                t in MILEYR,
                c in COMMTY,
                s in TSLICE;
                (r, t, c, s, "FX") in RCS_COMBAL,
            ],
            (
                !isnothing(RHS_COMPRD) && ((r, t, c, s) in RHS_COMPRD) ? ComPrd[r, t, c, s] :
                (
                    sum(
                        (
                            (r, p, c) in RPC_STG ?
                            sum(
                                sum(
                                    StgFlo[r, v, t, p, c, ts, "OUT"] *
                                    RS_FR[r, s, ts] *
                                    (
                                        1 + (
                                            (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                            RTCS_FR[r, t, c, s, ts] : 0
                                        )
                                    ) *
                                    STG_EFF[r, v, p] for v in RTP_VNT[r, t, p]
                                ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                            ) :
                            (sum(
                                sum(
                                    PrcFlo[r, v, t, p, c, ts] *
                                    RS_FR[r, s, ts] *
                                    (
                                        1 + (
                                            (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                            RTCS_FR[r, t, c, s, ts] : 0
                                        )
                                    ) for v in RTP_VNT[r, t, p]
                                ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                            ))
                        ) for p in RCIO_P[r, c, "OUT"] if (r, t, p) in RTP_VARA
                    ) + sum(
                        sum(
                            sum(
                                IreFlo[r, v, t, p, c, ts, "IMP"] *
                                RS_FR[r, s, ts] *
                                (
                                    1 + (
                                        (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                        RTCS_FR[r, t, c, s, ts] : 0
                                    )
                                ) for v in RTP_VNT[r, t, p]
                            ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                        ) for p in RCIE_P[r, c, "IMP"] if (r, t, p) in RTP_VARA
                    )
                ) * COM_IE[r, t, c, s]
            ) ==
            sum(
                (
                    (r, p, c) in RPC_STG ?
                    sum(
                        sum(
                            StgFlo[r, v, t, p, c, ts, "IN"] *
                            RS_FR[r, s, ts] *
                            (
                                1 + (
                                    (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                    RTCS_FR[r, t, c, s, ts] : 0
                                )
                            ) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                    ) :
                    (sum(
                        sum(
                            PrcFlo[r, v, t, p, c, ts] *
                            RS_FR[r, s, ts] *
                            (
                                1 + (
                                    (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                    RTCS_FR[r, t, c, s, ts] : 0
                                )
                            ) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                    ))
                ) for p in RCIO_P[r, c, "IN"] if (r, t, p) in RTP_VARA
            ) +
            sum(
                sum(
                    sum(
                        IreFlo[r, v, t, p, c, ts, "EXP"] *
                        RS_FR[r, s, ts] *
                        (1 + ((r, t, c, s, ts) in eachindex(RTCS_FR) ? RTCS_FR[r, t, c, s, ts] : 0))
                        for v in RTP_VNT[r, t, p]
                    ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                ) for p in RCIE_P[r, c, "EXP"] if (r, t, p) in RTP_VARA
            ) +
            RHS_COMBAL[r, t, c, s] * ComNet[r, t, c, s] +
            ((r, t, c) in eachindex(COM_PROJ) ? COM_PROJ[r, t, c] * COM_FR[r, t, c, s] : 0)
        )

        # %% Commodity Production
        @time "EQE_COMPRD" @constraint(
            model,
            EQE_COMPRD[
                r in REGION,
                t in MILEYR,
                c in COMMTY,
                s in TSLICE;
                !isnothing(RCS_COMPRD) && (r, t, c, s, "FX") in RCS_COMPRD,
            ],
            sum(
                (
                    (r, p, c) in RPC_STG ?
                    sum(
                        sum(
                            StgFlo[r, v, t, p, c, ts, "OUT"] *
                            RS_FR[r, s, ts] *
                            (
                                1 + (
                                    (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                    RTCS_FR[r, t, c, s, ts] : 0
                                )
                            ) *
                            STG_EFF[r, v, p] for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                    ) :
                    sum(
                        sum(
                            PrcFlo[r, v, t, p, c, ts] *
                            RS_FR[r, s, ts] *
                            (
                                1 + (
                                    (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                    RTCS_FR[r, t, c, s, ts] : 0
                                )
                            ) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                    )
                ) + sum(
                    sum(
                        sum(
                            IreFlo[r, v, t, p, c, ts, "IMP"] *
                            RS_FR[r, s, ts] *
                            (
                                1 + (
                                    (r, t, c, s, ts) in eachindex(RTCS_FR) ?
                                    RTCS_FR[r, t, c, s, ts] : 0
                                )
                            ) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c] if (r, s, ts) in eachindex(RS_FR)
                    ) for p in RCIE_P[r, c, "IMP"] if (r, t, p) in RTP_VARA
                ) for p in RCIO_P[r, c, "OUT"] if (r, t, p) in RTP_VARA
            ) * COM_IE[r, t, c, s] == ComPrd[r, t, c, s]
        )

        # %% Timeslice Storage Transformation
        @time "EQ_STGTSS" @constraint(
            model,
            EQ_STGTSS[
                r in REGION,
                v in MODLYR,
                y in MILEYR,
                p in PROCESS,
                s in TSLICE;
                (r, v, y, p) in RTP_VINTYR && (r, p, s) in RPS_STG,
            ],
            PrcAct[r, v, y, p, s] == sum(
                (
                    PrcAct[r, v, y, p, all_s] +
                    ((r, y, p, all_s) in eachindex(STG_CHRG) ? STG_CHRG[r, y, p, all_s] : 0) +
                    sum(
                        StgFlo[r, v, y, p, c, all_s, io] / PRC_ACTFLO[r, v, p, c] *
                        (io == "IN" ? 1 : -1) for (r, p, c, io) in TOP if (r, p, c) in PRC_STGTSS
                    ) +
                    (PrcAct[r, v, y, p, s] + PrcAct[r, v, y, p, all_s]) / 2 * (
                        (
                            1 - exp(
                                min(
                                    0,
                                    (
                                        !isnothing(STG_LOSS) &&
                                        (r, v, p, all_s) in eachindex(STG_LOSS) ?
                                        STG_LOSS[r, v, p, all_s] : 0
                                    ),
                                ) * G_YRFR[r, all_s] / RS_STGPRD[r, s],
                            )
                        ) +
                        max(
                            0,
                            (
                                !isnothing(STG_LOSS) && (r, v, p, all_s) in eachindex(STG_LOSS) ?
                                STG_LOSS[r, v, p, all_s] : 0
                            ),
                        ) * G_YRFR[r, all_s] / RS_STGPRD[r, s]
                    )
                ) for all_s in TSLICE if (r, s, all_s) in RS_PRETS
            )
        )
    end
    
    @time "Solve model" begin
        set_optimizer(model, HiGHS.Optimizer)    
        optimize!(model)
    end

    return(model)
end

# First run is for precompilation
@time "End to end model run" solved_model = run_model()
solution_summary(solved_model) # Print solution summary

# Now profile the code
Profile.clear()
@profile @time "End to end model run" run_model()
solution_summary(solved_model) # Print solution summary

ProfileView.view()