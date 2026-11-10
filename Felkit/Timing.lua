-- Original timing catalogue: factual Forever 1.60.1 values, not addon source code.
-- Reference version and limitations: docs/AUTOMATIC-TIMING.md.
local _,S=...
local rules={}; S.DotTiming=rules
local function register(ids,seconds,ticks)
    for _,id in ipairs(ids) do rules[id]={duration=seconds,count=ticks} end
end
-- Each rank is explicit: unknown IDs never inherit an arbitrary duration.
register({172},12,4)
register({6222},15,5)
register({6223,7648,11671,11672,25311},18,6)
register({348,707,1094,2941,11665,11667,11668,25309},15,5)
register({980,1014,6217,11711,11712,11713},24,12)
register({18265,18879,18880,18881},30,10)
register({702,1108,6205,7646,11707,11708},120)
register({1714,11719},30)
