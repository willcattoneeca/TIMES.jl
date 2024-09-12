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

        YEAR = union(0, (1900:2200))
        INOUT = Set(["IN", "OUT"])
        IMPEXP = Set(["IMP", "EXP"])
        LIM = Set(["LO", "UP", "FX", "N"])

        TSLVL = Set(["ANNUAL", "SEASON", "WEEKLY", "DAYNITE"])

        COM_TYPE = Set([
            "DEM",         # Demands
            "NRG",         # Energy
            "MAT",         # Material
            "ENV",         # Environmental
            "FIN",          # Financial
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
            "STS",      # Time-slice storage (excluding night storages)
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

        # Input data specs
        data_info = Dict(
            # Sets
            "MILEYR" => "SELECT ALLYEAR FROM MILESTONYR",
            "MODLYR" => "SELECT ALLYEAR FROM MODLYEAR",
            "TSLICE" => "SELECT ALL_TS FROM ALL_TS",
            "REGION" => "SELECT ALL_REG FROM ALL_REG",
            "PROCESS" => "SELECT PRC FROM PRC",
            "COMGRP" => "SELECT COM_GRP FROM COM_GRP",
            "COMMTY" => "SELECT COM_GRP FROM COM",
            "CURRENCY" => "SELECT CUR FROM CUR",
            "RDCUR" => "SELECT REG,CUR FROM RDCUR",
            "RC" => "SELECT R,C FROM RC",
            "RP" => "SELECT R,P FROM RP",
            "RP_FLO" => "SELECT R,P FROM RP_FLO",
            "RP_STD" => "SELECT R,P FROM RP_STD",
            "RP_IRE" => "SELECT ALL_REG,P FROM RP_IRE",
            "RP_STG" => "SELECT R,P FROM RP_STG",
            "RP_PGACT" => "SELECT R,P FROM RP_PGACT",
            "RP_PGFLO" => "SELECT R,P FROM RP_PGFLO",
            "PRC_ACT" => "SELECT REG,PRC FROM PRC_ACT",
            "PRC_VINT" => "SELECT REG,PRC FROM PRC_VINT",
            "RP_AIRE" => "SELECT R,P,IE FROM RP_AIRE",
            "DEM" => "SELECT REG,COM FROM DEM",
            "COM_GMAP" => "SELECT REG,COM_GRP,COM FROM COM_GMAP",
            "TOP" => "SELECT REG,PRC,COM,IO FROM TOP",
            "PRC_TS" => "SELECT ALL_REG,PRC,ALL_TS FROM PRC_TS",
            "RPS_S1" => "SELECT R,P,ALL_TS FROM RPS_S1",
            "RPS_STG" => "SELECT R,P,S FROM RPS_STG",
            "TS_MAP" => "SELECT ALL_REG,ALL_TS,ALL_TS2 FROM TS_MAP",
            "RS_PRETS" => "SELECT R,S,S2 FROM RS_PRETS",
            "RPC" => "SELECT R,P,C FROM RPC",
            "RPC_PG" => "SELECT R,P,C FROM RPC_PG",
            "RPC_IRE" => "SELECT ALL_REG,P,C,IE FROM RPC_IRE",
            "RPC_STG" => "SELECT R,P,C FROM RPC_STG",
            "PRC_STGTSS" => "SELECT REG,PRC,COM FROM PRC_STGTSS",
            "RPG_ACE" => "SELECT R,P,CG,IO FROM RPG_ACE",
            "RPC_ACE" => "SELECT REG,PRC,CG FROM RPC_ACE",
            "AFS" => "SELECT R,T,P,S,BD FROM AFS",
            "RTP" => "SELECT R,ALLYEAR,P FROM RTP",
            "RTP_VARA" => "SELECT R,ALLYEAR,P FROM RTP_VARA",
            "RTP_IPRI" => "SELECT R,ALLYEAR,P,CUR FROM RTP_IPRI",
            "RTP_VARP" => "SELECT R,T,P FROM RTP_VARP",
            "RPCS_VAR" => "SELECT R,P,C,ALL_TS FROM RPCS_VAR",
            "RPCC_FFUNC" => "SELECT REG,PRC,CG,CG2 FROM RPCC_FFUNC",
            "RTP_VINTYR" => "SELECT REG,ALLYEAR,ALLYEAR2,PRC FROM RTP_VINTYR",
            "RTCS" => "SELECT R,ALLYEAR,C,ALL_TS FROM RTCS_VARC",
            "RCS_COMBAL" => "SELECT R,ALLYEAR,C,S,LIM FROM RCS_COMBAL",
            "RCS_COMPRD" => "SELECT R,ALLYEAR,C,S,LIM FROM RCS_COMPRD",
            "RHS_COMPRD" => "SELECT R,ALLYEAR,C,S FROM RHS_COMPRD",
            "RP_PTRAN" => "SELECT R,P,CG,CG2,S FROM RPFF_GGS",
            "RTP_CPTYR" => "SELECT R,ALLYEAR,T,PRC FROM COEF_CPT",
            "IS_LINT" => "SELECT R,T,ALLYEAR,CUR FROM OBJ_LINT",
            "IS_ACOST" => "SELECT R,P,CUR,ALLYEAR FROM OB_ACT",
            # Parameters
            "G_YRFR" => "SELECT ALL_REG,TS,value FROM G_YRFR",
            "RS_STGPRD" => "SELECT R,ALL_TS,value FROM RS_STGPRD",
            "RS_FR" => "SELECT R,S,S2,value FROM RS_FR",
            "PRC_CAPACT" => "SELECT REG,PRC,value FROM PRC_CAPACT",
            "PRC_SC" => "SELECT REG,PRC,value FROM PRC_SC",
            "RS_STGAV" => "SELECT R,ALL_TS,value FROM RS_STGAV",
            "RTCS_FR" => "SELECT R,T,C,S,S2,value FROM RTCS_FR",
            "COM_PROJ" => "SELECT REG,ALLYEAR,COM,value FROM COM_PROJ",
            "COM_IE" => "SELECT REG,ALLYEAR,COM,TS,value FROM COM_IE",
            "COM_FR" => "SELECT REG,ALLYEAR,COM,TS,value FROM COM_FR",
            "NCAP_PASTI" => "SELECT REG,ALLYEAR,PRC,value FROM NCAP_PASTI",
            "CAP_BND" => "SELECT REG,ALLYEAR,PRC,BD,value FROM CAP_BND",
            "NCAP_BND" => "SELECT REG,ALLYEAR,PRC,LIM,value FROM NCAP_BND",
            "COEF_CPT" => "SELECT R,ALLYEAR,T,PRC,value FROM COEF_CPT",
            "COEF_AF" => "SELECT R,ALLYEAR,T,PRC,S,BD,value FROM COEF_AF",
            "COEF_PTRAN" => "SELECT REG,ALLYEAR,PRC,CG,C,CG2,TS,value FROM COEF_PTRAN",
            "FLO_SHAR" => "SELECT REG,ALLYEAR,PRC,C,CG,TS,BD,value FROM FLO_SHAR",
            "PRC_ACTFLO" => "SELECT REG,ALLYEAR,PRC,CG,value FROM PRC_ACTFLO",
            "STG_EFF" => "SELECT REG,ALLYEAR,PRC,value FROM STG_EFF",
            "STG_LOSS" => "SELECT REG,ALLYEAR,PRC,S,value FROM STG_LOSS",
            "STG_CHRG" => "SELECT REG,ALLYEAR,PRC,S,value FROM STG_CHRG",
            "ACT_EFF" => "SELECT REG,YEAR,PRC,CG,TS,value FROM ACT_EFF",
            "OBJ_PVT" => "SELECT R,YEAR,CUR,value FROM OBJ_PVT",
            "OBJ_LINT" => "SELECT R,T,ALLYEAR,CUR,value FROM OBJ_LINT",
            "OBJ_ACOST" => "SELECT R,P,CUR,ALLYEAR,value FROM OB_ACT",
            "OBJ_IPRIC" => "SELECT R,ALLYEAR,P,C,S,IE,CUR,value FROM OBJ_IPRIC",
            "COEF_OBINV" => "SELECT R,YEAR,P,CUR,value FROM COEF_OBINV",
            "COEF_OBFIX" => "SELECT R,YEAR,P,CUR,value FROM COEF_OBFIX",
        )

        function parse_year(df::DataFrame)::DataFrame
            year_cols = ["ALLYEAR", "ALLYEAR2", "T", "YEAR"]
            y_cols = intersect(names(df), year_cols)
            for y_col in y_cols
                df[!, y_col] = parse.(Int16, df[!, y_col])
            end
            return df
        end

        function read_data(data_info::Dict{String,String})::Dict{String,DataFrame}
            data = Dict()
            for (k, query) in data_info
                df = DataFrame(con.execute(db, query))
                data[k] = parse_year(df)
            end
            return data
        end

        function create_symbol(df::DataFrame)
            row_number = nrow(df)
            col_number = ncol(df)
            if row_number > 0 && col_number == 1
                # One-dimensional set
                value = Set(values(df[!, 1]))
            elseif row_number > 0 && col_number > 1
                # Multi-dimensional set or parameter
                if "value" in names(df)
                    value = Dict(Tuple.(eachrow(df[:, Not(:value)])) .=> df.value)
                else
                    value = Set(Tuple.(eachrow(df)))
                end
            else
                # Empty set or parameter
                value = nothing
            end
            return value
        end
        data = read_data(data_info)

        # Create all the symbols from the data
        MILEYR = create_symbol(data["MILEYR"])
        MODLYR = create_symbol(data["MODLYR"])
        TSLICE = create_symbol(data["TSLICE"])
        REGION = create_symbol(data["REGION"])
        PROCESS = create_symbol(data["PROCESS"])
        COMGRP = create_symbol(data["COMGRP"])
        COMMTY = create_symbol(data["COMMTY"])
        CURRENCY = create_symbol(data["CURRENCY"])
        RDCUR = create_symbol(data["RDCUR"])
        RC = create_symbol(data["RC"])
        RP = create_symbol(data["RP"])
        RP_FLO = create_symbol(data["RP_FLO"])
        RP_STD = create_symbol(data["RP_STD"])
        RP_IRE = create_symbol(data["RP_IRE"])
        RP_STG = create_symbol(data["RP_STG"])
        RP_PGACT = create_symbol(data["RP_PGACT"])
        RP_PGFLO = create_symbol(data["RP_PGFLO"])
        PRC_ACT = create_symbol(data["PRC_ACT"])
        PRC_VINT = create_symbol(data["PRC_VINT"])
        RP_AIRE = create_symbol(data["RP_AIRE"])
        DEM = create_symbol(data["DEM"])
        COM_GMAP = create_symbol(data["COM_GMAP"])
        TOP = create_symbol(data["TOP"])
        PRC_TS = create_symbol(data["PRC_TS"])
        RPS_S1 = create_symbol(data["RPS_S1"])
        RPS_STG = create_symbol(data["RPS_STG"])
        TS_MAP = create_symbol(data["TS_MAP"])
        RS_PRETS = create_symbol(data["RS_PRETS"])
        RPC = create_symbol(data["RPC"])
        RPC_PG = create_symbol(data["RPC_PG"])
        RPC_IRE = create_symbol(data["RPC_IRE"])
        RPC_STG = create_symbol(data["RPC_STG"])
        PRC_STGTSS = create_symbol(data["PRC_STGTSS"])
        RPG_ACE = create_symbol(data["RPG_ACE"])
        RPC_ACE = create_symbol(data["RPC_ACE"])
        AFS = create_symbol(data["AFS"])
        RTP = create_symbol(data["RTP"])
        RTP_VARA = create_symbol(data["RTP_VARA"])
        RTP_IPRI = create_symbol(data["RTP_IPRI"])
        RTP_VARP = create_symbol(data["RTP_VARP"])
        RPCS_VAR = create_symbol(data["RPCS_VAR"])
        RPCC_FFUNC = create_symbol(data["RPCC_FFUNC"])
        RTP_VINTYR = create_symbol(data["RTP_VINTYR"])
        RTCS = create_symbol(data["RTCS"])
        RCS_COMBAL = create_symbol(data["RCS_COMBAL"])
        RCS_COMPRD = create_symbol(data["RCS_COMPRD"])
        RHS_COMPRD = create_symbol(data["RHS_COMPRD"])
        RP_PTRAN = create_symbol(data["RP_PTRAN"])
        RTP_CPTYR = create_symbol(data["RTP_CPTYR"])
        IS_LINT = create_symbol(data["IS_LINT"])
        IS_ACOST = create_symbol(data["IS_ACOST"])
        G_YRFR = create_symbol(data["G_YRFR"])
        RS_STGPRD = create_symbol(data["RS_STGPRD"])
        RS_FR = create_symbol(data["RS_FR"])
        PRC_CAPACT = create_symbol(data["PRC_CAPACT"])
        PRC_SC = create_symbol(data["PRC_SC"])
        RS_STGAV = create_symbol(data["RS_STGAV"])
        RTCS_FR = create_symbol(data["RTCS_FR"])
        COM_PROJ = create_symbol(data["COM_PROJ"])
        COM_IE = create_symbol(data["COM_IE"])
        COM_FR = create_symbol(data["COM_FR"])
        NCAP_PASTI = create_symbol(data["NCAP_PASTI"])
        CAP_BND = create_symbol(data["CAP_BND"])
        NCAP_BND = create_symbol(data["NCAP_BND"])
        COEF_CPT = create_symbol(data["COEF_CPT"])
        COEF_AF = create_symbol(data["COEF_AF"])
        COEF_PTRAN = create_symbol(data["COEF_PTRAN"])
        FLO_SHAR = create_symbol(data["FLO_SHAR"])
        PRC_ACTFLO = create_symbol(data["PRC_ACTFLO"])
        STG_EFF = create_symbol(data["STG_EFF"])
        STG_LOSS = create_symbol(data["STG_LOSS"])
        STG_CHRG = create_symbol(data["STG_CHRG"])
        ACT_EFF = create_symbol(data["ACT_EFF"])
        OBJ_PVT = create_symbol(data["OBJ_PVT"])
        OBJ_LINT = create_symbol(data["OBJ_LINT"])
        OBJ_ACOST = create_symbol(data["OBJ_ACOST"])
        OBJ_IPRIC = create_symbol(data["OBJ_IPRIC"])
        COEF_OBINV = create_symbol(data["COEF_OBINV"])
        COEF_OBFIX = create_symbol(data["COEF_OBFIX"])
    end

    @time "Parameters" begin
        Containers.@container(MILE[y in MODLYR], y in MILEYR ? 1 : 0)
    end

    @time "Compute sets" begin
        LINTY = Dict{Tuple{String,Int16,String},Vector{Int16}}(
            (g.R[1], g.T[1], g.CUR[1]) => g.ALLYEAR for
            g in groupby(data["IS_LINT"], [:R, :T, :CUR])
        )
        RTP_VNT = Dict{Tuple{String,Int16,String},Vector{Int16}}(
            (g.REG[1], g.ALLYEAR2[1], g.PRC[1]) => g.ALLYEAR for
            g in groupby(data["RTP_VINTYR"], [:REG, :ALLYEAR2, :PRC])
        )
        RTV_PRC = Dict{Tuple{String,Int16,Int16},Vector{String}}(
            (g.REG[1], g.ALLYEAR2[1], g.ALLYEAR[1]) => g.PRC for
            g in groupby(data["RTP_VINTYR"], [:REG, :ALLYEAR2, :ALLYEAR])
        )
        RTP_CPT = Dict{Tuple{String,Int16,String},Vector{Int16}}(
            (g.R[1], g.T[1], g.PRC[1]) => g.ALLYEAR for
            g in groupby(data["RTP_CPTYR"], [:R, :T, :PRC])
        )
        RTP_AFS = Dict{Tuple{String,Int16,String,String},Vector{String}}(
            (g.R[1], g.T[1], g.P[1], g.BD[1]) => g.S for
            g in groupby(data["AFS"], [:R, :T, :P, :BD])
        )
        RP_TS = Dict{Tuple{String,String},Vector{String}}(
            (g.ALL_REG[1], g.PRC[1]) => g.ALL_TS for g in groupby(data["PRC_TS"], [:ALL_REG, :PRC])
        )
        RP_S1 = Dict{Tuple{String,String},Vector{String}}(
            (g.R[1], g.P[1]) => g.ALL_TS for g in groupby(data["RPS_S1"], [:R, :P])
        )
        RP_PGC = Dict{Tuple{String,String},Vector{String}}(
            (g.R[1], g.P[1]) => g.C for g in groupby(data["RPC_PG"], [:R, :P])
        )
        RP_CIE = Dict{Tuple{String,String},Vector{Tuple{String,String}}}(
            (g.ALL_REG[1], g.P[1]) => Tuple.(eachrow(g[!, [:C, :IE]])) for
            g in groupby(data["RPC_IRE"], [:ALL_REG, :P])
        )
        RPC_TS = Dict{Tuple{String,String,String},Vector{String}}(
            (g.R[1], g.P[1], g.C[1]) => g.ALL_TS for g in groupby(data["RPCS_VAR"], [:R, :P, :C])
        )
        RPIO_C = Dict{Tuple{String,String,String},Vector{String}}(
            (g.REG[1], g.PRC[1], g.IO[1]) => g.COM for g in groupby(data["TOP"], [:REG, :PRC, :IO])
        )
        RCIO_P = Dict{Tuple{String,String,String},Vector{String}}(
            (g.REG[1], g.COM[1], g.IO[1]) => g.PRC for g in groupby(data["TOP"], [:REG, :COM, :IO])
        )
        RCIE_P = Dict{Tuple{String,String,String},Vector{String}}(
            (g.ALL_REG[1], g.C[1], g.IE[1]) => g.P for
            g in groupby(data["RPC_IRE"], [:ALL_REG, :C, :IE])
        )
        RP_ACE =
            !isnothing(RPC_ACE) ?
            Dict{Tuple{String,String},Vector{String}}(
                (g.REG[1], g.PRC[1]) => g.CG for g in groupby(data["RPC_ACE"], [:REG, :PRC])
            ) : nothing
        R_P = Dict{String,Vector{String}}(g.R[1] => g.P for g in groupby(data["RP"], :R))
        R_C = Dict{String,Vector{String}}(g.R[1] => g.C for g in groupby(data["RC"], :R))
        RP_C = Dict{Tuple{String,String},Vector{String}}(
            (g.R[1], g.P[1]) => g.C for g in groupby(data["RPC"], [:R, :P])
        )
        R_CPT = Dict{String,Vector{Tuple{Int16,Int16,String}}}(
            g.R[1] => Tuple.(eachrow(g[!, [:ALLYEAR, :T, :PRC]])) for
            g in groupby(data["RTP_CPTYR"], :R)
        )
    end

    @time "Compute indexes" begin
        # Create intermediate dataframes
        EQs_CAPACT = innerjoin(
            rename(data["RTP_VINTYR"], [:r, :v, :t, :p]),
            rename(data["AFS"], [:r, :t, :p, :s, :bd]),
            on = [:r, :t, :p],
        )
        EQs_FLOSHR = innerjoin(
            innerjoin(
                rename(data["FLO_SHAR"][:, Not(:value)], [:r, :v, :p, :c, :cg, :s, :bd]),
                rename(data["RTP_VARA"], [:r, :t, :p]),
                on = [:r, :p],
            ),
            innerjoin(
                rename(data["RTP_VINTYR"], [:r, :v, :t, :p]),
                rename(data["RPCS_VAR"], [:r, :p, :c, :s]),
                on = [:r, :p],
            ),
            on = [:r, :v, :p, :c, :s, :t],
        )
        vars_base = innerjoin(
            rename(data["RTP_VINTYR"], [:r, :v, :t, :p]),
            rename(data["RTP_VARA"], [:r, :t, :p]),
            on = [:r, :t, :p],
        )
        # Create filters
        filters = Dict{String,Set{Tuple}}()
        filters["EQ_ACTFLO"] = Set(
            Tuple.(
                eachrow(
                    innerjoin(
                        innerjoin(
                            rename(data["RTP_VINTYR"], [:r, :v, :t, :p]),
                            rename(data["PRC_TS"], [:r, :p, :s]),
                            on = [:r, :p],
                        ),
                        rename(data["PRC_ACT"], [:r, :p]),
                        on = [:r, :p],
                    ),
                )
            ),
        )
        filters["EQL_CAPACT"] =
            Set(Tuple.(eachrow(filter(:bd => f -> f == "UP", EQs_CAPACT)[!, [:r, :v, :t, :p, :s]])))
        filters["EQE_CAPACT"] =
            Set(Tuple.(eachrow(filter(:bd => f -> f == "FX", EQs_CAPACT)[!, [:r, :v, :t, :p, :s]])))
        filters["EXPR_FLOSHR"] = Set(Tuple.(eachrow(EQs_FLOSHR)))
        filters["EQL_FLOSHR"] = Set(Tuple.(eachrow(filter(:bd => f -> f == "LO", EQs_FLOSHR))))
        filters["EQG_FLOSHR"] = Set(Tuple.(eachrow(filter(:bd => f -> f == "UP", EQs_FLOSHR))))
        filters["EQE_FLOSHR"] = Set(Tuple.(eachrow(filter(:bd => f -> f == "FX", EQs_FLOSHR))))
        filters["EQE_ACTEFF"] = Set(
            Tuple.(
                eachrow(
                    innerjoin(
                        innerjoin(
                            rename(data["RPG_ACE"], [:r, :p, :cg, :io]),
                            rename(data["RTP_VARA"], [:r, :t, :p]),
                            on = [:r, :p],
                        ),
                        innerjoin(
                            rename(data["RTP_VINTYR"], [:r, :v, :t, :p]),
                            rename(data["RPS_S1"], [:r, :p, :s]),
                            on = [:r, :p],
                        ),
                        on = [:r, :p, :t],
                    ),
                )
            ),
        )
        filters["EQ_PTRANS"] = Set(
            Tuple.(
                eachrow(
                    innerjoin(
                        innerjoin(
                            innerjoin(
                                rename(data["RP_PTRAN"], [:r, :p, :cg1, :cg2, :s1]),
                                rename(data["RTP_VARA"], [:r, :t, :p]),
                                on = [:r, :p],
                            ),
                            innerjoin(
                                rename(data["RTP_VINTYR"], [:r, :v, :t, :p]),
                                rename(data["RPS_S1"], [:r, :p, :s]),
                                on = [:r, :p],
                            ),
                            on = [:r, :p, :t],
                        ),
                        rename(data["RS_FR"][:, Not(:value)], [:r, :s1, :s]),
                        on = [:r, :s1, :s],
                    ),
                )
            ),
        )
        filters["EQG_COMBAL"] = Set(
            Tuple.(
                eachrow(
                    filter(:bd => f -> f == "LO", rename(data["RCS_COMBAL"], [:r, :t, :c, :s, :bd]))[
                        :,
                        Not(:bd),
                    ],
                )
            ),
        )
        filters["EQE_COMBAL"] = Set(
            Tuple.(
                eachrow(
                    filter(:bd => f -> f == "FX", rename(data["RCS_COMBAL"], [:r, :t, :c, :s, :bd]))[
                        :,
                        Not(:bd),
                    ],
                )
            ),
        )
        filters["EQE_COMPRD"] = Set(
            Tuple.(
                eachrow(
                    filter(:bd => f -> f == "FX", rename(data["RCS_COMPRD"], [:r, :t, :c, :s, :bd]))[
                        :,
                        Not(:bd),
                    ],
                )
            ),
        )
        filters["EQ_STGTSS"] = Set(
            Tuple.(
                eachrow(
                    innerjoin(
                        rename(data["RTP_VINTYR"], [:r, :v, :t, :p]),
                        rename(data["RPS_STG"], [:r, :p, :s]),
                        on = [:r, :p],
                    ),
                )
            ),
        )
        filters["var_PrcAct"] = Set(
            Tuple.(
                eachrow(innerjoin(vars_base, rename(data["PRC_TS"], [:r, :p, :s]), on = [:r, :p]))
            ),
        )
        filters["var_PrcFlo"] = Set(
            Tuple.(eachrow(innerjoin(vars_base, rename(data["RP_FLO"], [:r, :p]), on = [:r, :p]))),
        )
        filters["var_IreFlo"] = Set(
            Tuple.(
                eachrow(
                    innerjoin(
                        innerjoin(vars_base, rename(data["RP_IRE"], [:r, :p]), on = [:r, :p]),
                        rename(data["RPC_IRE"], [:r, :p, :c, :ie]),
                        on = [:r, :p],
                    ),
                )
            ),
        )
        filters["var_StgFlo"] = Set(
            Tuple.(
                eachrow(
                    innerjoin(
                        innerjoin(vars_base, rename(data["RP_STG"], [:r, :p]), on = [:r, :p]),
                        rename(data["TOP"], [:r, :p, :c, :io]),
                        on = [:r, :p],
                    ),
                )
            ),
        )
    end


    @time "Variables" begin
        function PrcCap_bounds(r, y, p, bd)
            if haskey(CAP_BND, (r, y, p, bd))
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
            if haskey(NCAP_BND, (r, y, p, bd))
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
        @variable(
            model,
            ComPrd[r in REGION, t in MILEYR, c in get(R_C, r, Set()), s in TSLICE] >= 0
        )
        @variable(
            model,
            ComNet[r in REGION, t in MILEYR, c in get(R_C, r, Set()), s in TSLICE] >= 0
        )
        @variable(
            model,
            PrcCap_bounds(r, v, p, "LO") <=
            PrcCap[r in REGION, v in MODLYR, p in get(R_P, r, Set())] <=
            PrcCap_bounds(r, v, p, "UP")
        )
        @variable(
            model,
            PrcNcap_bounds(r, v, p, "LO") <=
            PrcNcap[r in REGION, v in MODLYR, p in get(R_P, r, Set())] <=
            PrcNcap_bounds(r, v, p, "UP")
        )
        @variable(
            model,
            PrcAct[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in get(RTV_PRC, (r, t, v), Set()),
                s in get(RP_TS, (r, p), Set());
                ((r, t, p) in RTP_VARA),
            ] >= 0
        )
        #PrcAct[(r, v, t, p, s) in filters["var_PrcAct"]] >= 0
        @variable(
            model,
            PrcFlo[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in get(RTV_PRC, (r, t, v), Set()),
                c in get(RP_C, (r, p), Set()),
                s in get(RPC_TS, (r, p, c), Set());
                ((r, p) in RP_FLO) && ((r, t, p) in RTP_VARA),
            ] >= 0
        )
        @variable(
            model,
            IreFlo[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in get(RTV_PRC, (r, t, v), Set()),
                c in get(RP_C, (r, p), Set()),
                s in get(RP_TS, (r, p), Set()),
                ie in IMPEXP;
                ((r, p) in RP_IRE) && ((r, t, p) in RTP_VARA) && ((r, p, c, ie) in RPC_IRE),
            ] >= 0
        )
        @variable(
            model,
            StgFlo[
                r in REGION,
                v in MODLYR,
                t in MILEYR,
                p in get(RTV_PRC, (r, t, v), Set()),
                c in get(RP_C, (r, p), Set()),
                s in get(RP_TS, (r, p), Set()),
                io in INOUT;
                ((r, p) in RP_STG) && ((r, t, p) in RTP_VARA) && ((r, p, c, io) in TOP),
            ] >= 0
        )
    end

    @time "Objective" begin
        @expression(model, obj, sum(RegObj[o, r, cur] for o in OBV for (r, cur) in RDCUR))
        @objective(model, Min, obj)
    end

    @time "Constraints" begin
        # Objective function constituents
        @constraint(
            model,
            EQ_OBJINV[(r, cur) in RDCUR],
            sum(
                (
                    OBJ_PVT[r, t, cur] *
                    COEF_CPT[r, v, t, p] *
                    get(COEF_OBINV, (r, v, p, cur), 0) *
                    ((v in MILEYR ? PrcNcap[r, v, p] : 0) + get(NCAP_PASTI, (r, v, p), 0))
                ) for (v, t, p) in R_CPT[r]
            ) == RegObj["OBJINV", r, cur]
        )
        @constraint(
            model,
            EQ_OBJFIX[(r, cur) in RDCUR],
            sum(
                (
                    OBJ_PVT[r, t, cur] *
                    COEF_CPT[r, v, t, p] *
                    get(COEF_OBFIX, (r, v, p, cur), 0) *
                    ((v in MILEYR ? PrcNcap[r, v, p] : 0) + get(NCAP_PASTI, (r, v, p), 0))
                ) for (v, t, p) in R_CPT[r]
            ) == RegObj["OBJFIX", r, cur]
        )
        @constraint(
            model,
            EQ_OBJVAR[(r, cur) in RDCUR],
            sum(
                sum(
                    sum(
                        OBJ_LINT[r, t, y, cur] * get(OBJ_ACOST, (r, p, cur, y), 0) for
                        y in LINTY[r, t, cur]
                    ) * sum(
                        PrcAct[r, v, t, p, s] * ((r, p) in RP_STG ? RS_STGAV[r, s] : 1) for
                        v in RTP_VNT[r, t, p] for s in RP_TS[r, p]
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
                ) for p in R_P[r]
            ) == RegObj["OBJVAR", r, cur]
        )
        # %% Activity to Primary Group
        @constraint(
            model,
            EQ_ACTFLO[(r, v, t, p, s) in filters["EQ_ACTFLO"]],
            ((r, t, p) in RTP_VARA ? PrcAct[r, v, t, p, s] : 0) == sum(
                (
                    (r, p) in RP_IRE ?
                    sum(IreFlo[r, v, t, p, c, s, ie] for ie in IMPEXP if (r, p, ie) in RP_AIRE) :
                    PrcFlo[r, v, t, p, c, s]
                ) for c in RP_PGC[r, p]
            )
        )
        # %% Activity to Capacity
        @constraint(
            model,
            EQL_CAPACT[(r, v, y, p, s) in filters["EQL_CAPACT"],],
            (
                (r, p) in RP_STG ?
                sum(
                    PrcAct[r, v, y, p, ts] *
                    RS_FR[r, ts, s] *
                    exp(isnothing(PRC_SC) ? 0 : PRC_SC[r, p]) / RS_STGPRD[r, s] for
                    ts in RP_TS[r, p] if haskey(RS_FR, (r, s, ts))
                ) : sum(PrcAct[r, v, y, p, ts] for ts in RP_TS[r, p] if haskey(RS_FR, (r, s, ts)))
            ) <= (
                ((r, p) in RP_STG ? 1 : G_YRFR[r, s]) *
                PRC_CAPACT[r, p] *
                (
                    (r, p) in PRC_VINT ?
                    COEF_AF[r, v, y, p, s, "UP"] *
                    COEF_CPT[r, v, y, p] *
                    (MILE[v] * PrcNcap[r, v, p] + get(NCAP_PASTI, (r, v, p), 0)) :
                    sum(
                        COEF_AF[r, m, y, p, s, "UP"] *
                        COEF_CPT[r, m, y, p] *
                        ((MILE[m] * PrcNcap[r, m, p]) + get(NCAP_PASTI, (r, m, p), 0)) for
                        m in RTP_CPT[r, y, p]
                    )
                )
            )
        )
        @constraint(
            model,
            EQE_CAPACT[(r, v, y, p, s) in filters["EQE_CAPACT"]],
            (
                (r, p) in RP_STG ?
                sum(
                    PrcAct[r, v, y, p, ts] *
                    RS_FR[r, ts, s] *
                    exp(isnothing(PRC_SC) ? 0 : PRC_SC[r, p]) / RS_STGPRD[r, s] for
                    ts in RP_TS[r, p] if haskey(RS_FR, (r, s, ts))
                ) : sum(PrcAct[r, v, y, p, ts] for ts in RP_TS[r, p]haskey(RS_FR, (r, s, ts)))
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
        @constraint(
            model,
            EQE_CPT[
                (r, y, p) in RTP
                (r, y, p) in RTP_VARP || haskey(CAP_BND, (r, y, p, "FX"))
            ],
            ((r, y, p) in RTP_VARP ? PrcCap[r, y, p] : CAP_BND[r, y, p, "FX"]) == sum(
                COEF_CPT[r, v, y, p] *
                ((MILE[v] * PrcNcap[r, v, p]) + get(NCAP_PASTI, (r, v, p), 0)) for
                v in RTP_CPT[r, y, p]
            )
        )
        @constraint(
            model,
            EQL_CPT[
                (r, y, p) in RTP
                !((r, y, p) in RTP_VARP) && haskey(CAP_BND, (r, y, p, "LO"))
            ],
            ((r, y, p) in RTP_VARP ? PrcCap[r, y, p] : CAP_BND[r, y, p, "LO"]) <= sum(
                COEF_CPT[r, v, y, p] *
                ((MILE[v] * PrcNcap[r, v, p]) + get(NCAP_PASTI, (r, v, p), 0)) for
                v in RTP_CPT[r, y, p]
            )
        )
        @constraint(
            model,
            EQG_CPT[
                (r, y, p) in RTP
                !((r, y, p) in RTP_VARP) && haskey(CAP_BND, (r, y, p, "UP"))
            ],
            ((r, y, p) in RTP_VARP ? PrcCap[r, y, p] : CAP_BND[r, y, p, "UP"]) >= sum(
                COEF_CPT[r, v, y, p] *
                ((MILE[v] * PrcNcap[r, v, p]) + get(NCAP_PASTI, (r, v, p), 0)) for
                v in RTP_CPT[r, y, p]
            )
        )
        # %% Process Flow Shares
        @expression(
            model,
            EXPR_FLOSHR[(r, v, p, c, cg, s, l, t) in filters["EXPR_FLOSHR"]],
            sum(
                FLO_SHAR[r, v, p, c, cg, s, l] * sum(
                    PrcFlo[r, v, t, p, com, ts] * get(RS_FR, (r, s, ts), 0) for
                    com in RPIO_C[r, p, io] for ts in RPC_TS[r, p, c] if (r, cg, com) in COM_GMAP
                ) for io in INOUT if c in RPIO_C[r, p, io]
            )
        )
        @constraint(
            model,
            EQL_FLOSHR[(r, v, p, c, cg, s, l, t) in filters["EQL_FLOSHR"]],
            EXPR_FLOSHR[(r, v, p, c, cg, s, l, t)] <= PrcFlo[r, v, t, p, c, s]
        )
        @constraint(
            model,
            EQG_FLOSHR[(r, v, p, c, cg, s, l, t) in filters["EQG_FLOSHR"]],
            EXPR_FLOSHR[(r, v, p, c, cg, s, l, t)] >= PrcFlo[r, v, t, p, c, s]
        )
        @constraint(
            model,
            EQE_FLOSHR[(r, v, p, c, cg, s, l, t) in filters["EQE_FLOSHR"]],
            EXPR_FLOSHR[(r, v, p, c, cg, s, l, t)] == PrcFlo[r, v, t, p, c, s]
        )
        # %% Activity efficiency:
        @constraint(
            model,
            EQE_ACTEFF[(r, p, cg, io, t, v, s) in filters["EQE_ACTEFF"]],
            (
                !isnothing(RP_ACE) ?
                sum(
                    sum(
                        PrcFlo[r, v, t, p, c, ts] *
                        get(ACT_EFF, (r, v, p, c, ts), 1) *
                        get(RS_FR, (r, s, ts), 0) *
                        (1 + RTCS_FR[r, t, c, s, ts]) for ts in RPC_TS[r, p, c]
                    ) for c in RP_ACE[r, p] if (r, cg, c) in COM_GMAP
                ) : 0
            ) == sum(
                get(RS_FR, (r, s, ts), 0) * (
                    (r, p) in RP_PGFLO ?
                    sum(
                        (
                            (r, p) in RP_PGACT ? PrcAct[r, v, t, p, ts] :
                            PrcFlo[r, v, t, p, c, ts] / PRC_ACTFLO[r, v, p, c]
                        ) / get(ACT_EFF, (r, v, p, c, ts), 1) * (1 + RTCS_FR[r, t, c, s, ts]) for
                        c in RP_PGC[r, p]
                    ) : PrcAct[r, v, t, p, ts]
                ) / max(1e-6, ACT_EFF[r, v, p, cg, ts]) for ts in RP_TS[r, p]
            )
        )
        # %% Process Transformation
        @constraint(
            model,
            EQ_PTRANS[(r, p, cg1, cg2, s1, t, v, s) in filters["EQ_PTRANS"]],
            sum(
                sum(
                    PrcFlo[r, v, t, p, c, ts] *
                    get(RS_FR, (r, s, ts), 0) *
                    (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for ts in RPC_TS[r, p, c]
                ) for io in INOUT for c in RPIO_C[r, p, io] if (r, cg2, c) in COM_GMAP
            ) == sum(
                get(COEF_PTRAN, (r, v, p, cg1, c, cg2, ts), 0) *
                get(RS_FR, (r, s, ts), 0) *
                (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) *
                PrcFlo[r, v, t, p, c, ts] for io in INOUT for c in RPIO_C[r, p, io] for
                ts in RPC_TS[r, p, c]
            )
        )
        # %% Commodity Balance - Greater
        @constraint(
            model,
            EQG_COMBAL[(r, t, c, s) in filters["EQG_COMBAL"]],
            (
                !isnothing(RHS_COMPRD) && ((r, t, c, s) in RHS_COMPRD) ? ComPrd[r, t, c, s] :
                (
                    sum(
                        (
                            (r, p, c) in RPC_STG ?
                            sum(
                                sum(
                                    StgFlo[r, v, t, p, c, ts, "OUT"] *
                                    get(RS_FR, (r, s, ts), 0) *
                                    (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) *
                                    STG_EFF[r, v, p] for v in RTP_VNT[r, t, p]
                                ) for ts in RPC_TS[r, p, c]
                            ) :
                            sum(
                                sum(
                                    PrcFlo[r, v, t, p, c, ts] *
                                    get(RS_FR, (r, s, ts), 0) *
                                    (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for
                                    v in RTP_VNT[r, t, p]
                                ) for ts in RPC_TS[r, p, c]
                            )
                        ) for p in get(RCIO_P, (r, c, "OUT"), Set()) if (r, t, p) in RTP_VARA;
                        init = 0,
                    ) + sum(
                        sum(
                            sum(
                                IreFlo[r, v, t, p, c, ts, "IMP"] *
                                get(RS_FR, (r, s, ts), 0) *
                                (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                            ) for ts in RPC_TS[r, p, c]
                        ) for p in get(RCIE_P, (r, c, "IMP"), Set()) if (r, t, p) in RTP_VARA;
                        init = 0,
                    )
                ) * COM_IE[r, t, c, s]
            ) >=
            sum(
                (
                    (r, p, c) in RPC_STG ?
                    sum(
                        sum(
                            StgFlo[r, v, t, p, c, ts, "IN"] *
                            get(RS_FR, (r, s, ts), 0) *
                            (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c]
                    ) :
                    (sum(
                        sum(
                            PrcFlo[r, v, t, p, c, ts] *
                            get(RS_FR, (r, s, ts), 0) *
                            (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c]
                    ))
                ) for p in get(RCIO_P, (r, c, "IN"), Set()) if (r, t, p) in RTP_VARA;
                init = 0,
            ) +
            sum(
                sum(
                    sum(
                        IreFlo[r, v, t, p, c, ts, "EXP"] *
                        get(RS_FR, (r, s, ts), 0) *
                        (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                    ) for ts in RPC_TS[r, p, c]
                ) for p in get(RCIE_P, (r, c, "EXP"), Set()) if (r, t, p) in RTP_VARA;
                init = 0,
            ) +
            get(COM_PROJ, (r, t, c), 0) * COM_FR[r, t, c, s]
        )
        # %% Commodity Balance - Equal
        @constraint(
            model,
            EQE_COMBAL[(r, t, c, s) in filters["EQE_COMBAL"]],
            (
                !isnothing(RHS_COMPRD) && ((r, t, c, s) in RHS_COMPRD) ? ComPrd[r, t, c, s] :
                (
                    sum(
                        (
                            (r, p, c) in RPC_STG ?
                            sum(
                                sum(
                                    StgFlo[r, v, t, p, c, ts, "OUT"] *
                                    get(RS_FR, (r, s, ts), 0) *
                                    (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) *
                                    STG_EFF[r, v, p] for v in RTP_VNT[r, t, p]
                                ) for ts in RPC_TS[r, p, c]
                            ) :
                            (sum(
                                sum(
                                    PrcFlo[r, v, t, p, c, ts] *
                                    get(RS_FR, (r, s, ts), 0) *
                                    (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for
                                    v in RTP_VNT[r, t, p]
                                ) for ts in RPC_TS[r, p, c]
                            ))
                        ) for p in RCIO_P[r, c, "OUT"] if (r, t, p) in RTP_VARA
                    ) + sum(
                        sum(
                            sum(
                                IreFlo[r, v, t, p, c, ts, "IMP"] *
                                get(RS_FR, (r, s, ts), 0) *
                                (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                            ) for ts in RPC_TS[r, p, c]
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
                            get(RS_FR, (r, s, ts), 0) *
                            (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c]
                    ) :
                    (sum(
                        sum(
                            PrcFlo[r, v, t, p, c, ts] *
                            get(RS_FR, (r, s, ts), 0) *
                            (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c]
                    ))
                ) for p in RCIO_P[r, c, "IN"] if (r, t, p) in RTP_VARA
            ) +
            sum(
                sum(
                    sum(
                        IreFlo[r, v, t, p, c, ts, "EXP"] *
                        get(RS_FR, (r, s, ts), 0) *
                        (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                    ) for ts in RPC_TS[r, p, c]
                ) for p in RCIE_P[r, c, "EXP"] if (r, t, p) in RTP_VARA
            ) +
            RHS_COMBAL[r, t, c, s] * ComNet[r, t, c, s] +
            get(COM_PROJ, (r, t, c), 0) * COM_FR[r, t, c, s]
        )
        # %% Commodity Production
        @constraint(
            model,
            EQE_COMPRD[(r, t, c, s) in filters["EQE_COMPRD"]],
            sum(
                (
                    (r, p, c) in RPC_STG ?
                    sum(
                        sum(
                            StgFlo[r, v, t, p, c, ts, "OUT"] *
                            get(RS_FR, (r, s, ts), 0) *
                            (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) *
                            STG_EFF[r, v, p] for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c]
                    ) :
                    sum(
                        sum(
                            PrcFlo[r, v, t, p, c, ts] *
                            get(RS_FR, (r, s, ts), 0) *
                            (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c]
                    )
                ) + sum(
                    sum(
                        sum(
                            IreFlo[r, v, t, p, c, ts, "IMP"] *
                            get(RS_FR, (r, s, ts), 0) *
                            (1 + get(RTCS_FR, (r, t, c, s, ts), 0)) for v in RTP_VNT[r, t, p]
                        ) for ts in RPC_TS[r, p, c]
                    ) for p in RCIE_P[r, c, "IMP"] if (r, t, p) in RTP_VARA
                ) for p in RCIO_P[r, c, "OUT"] if (r, t, p) in RTP_VARA
            ) * COM_IE[r, t, c, s] == ComPrd[r, t, c, s]
        )
        # %% Timeslice Storage Transformation
        @constraint(
            model,
            EQ_STGTSS[(r, v, y, p, s) in filters["EQ_STGTSS"]],
            PrcAct[r, v, y, p, s] == sum(
                (
                    PrcAct[r, v, y, p, all_s] +
                    get(STG_CHRG, (r, y, p, all_s), 0) +
                    sum(
                        StgFlo[r, v, y, p, c, all_s, io] / PRC_ACTFLO[r, v, p, c] *
                        (io == "IN" ? 1 : -1) for (r, p, c, io) in TOP if (r, p, c) in PRC_STGTSS
                    ) +
                    (PrcAct[r, v, y, p, s] + PrcAct[r, v, y, p, all_s]) / 2 * (
                        (
                            1 - exp(
                                min(
                                    0,
                                    (!isnothing(STG_LOSS) ? get(STG_LOSS, (r, v, p, all_s), 0) : 0),
                                ) * G_YRFR[r, all_s] / RS_STGPRD[r, s],
                            )
                        ) +
                        max(0, (!isnothing(STG_LOSS) ? get(STG_LOSS, (r, v, p, all_s), 0) : 0)) *
                        G_YRFR[r, all_s] / RS_STGPRD[r, s]
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