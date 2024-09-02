using JuMP;

LINTY = Set(((r, t, cur) for (r, t, y, cur) in IS_LINT if y in MODLYR))

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

#RP_ACE = Containers.SparseAxisArray(Dict((r, p) => [c for c in COMMTY if (r, p, c) in RPC_ACE] for (r, p, c) in RPC_ACE))
