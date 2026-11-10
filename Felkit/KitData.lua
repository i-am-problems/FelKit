local _,S=...
-- Factual ID candidates: Forever WarlockKit 1.2.0, file 9186985.
-- Original implementation; no third-party code or artwork included.
-- Families are ordered highest rank first; runtime requires learned spells.
S.KitData={
 families={
  health={11730,11729,5699,6202,6201}, soul={20757,20756,20755,20752,693},
  fire={17953,17952,17951,6366}, stone={17728,17727,2362},
  imp={688},void={697},succubus={712},incubus={713},felhunter={691},infernal={1122},doom={18540},
  sacrifice={18788},link={19028},domination={18708},
  weakness={11708,11707,7646,6205,1108,702},recklessness={11717,7659,7658,704},
  tongues={11719,1714},elements={1311680,1311677,1311676,440892},exhaustion={18223},havoc={1225228},
  ward={28610,11740,11739,6229},armor={11735,11734,11733,1086,706,696,687},
  summon={698},breath={5697},invisibility={11743,2970,132},eye={126},sense={5500},
 },
 items={health={9421,5510,5509,5511,5512},soul={16896,16895,16893,16892,5232},
  fire={13701,13700,13699,1254},stone={13603,13602,5522}},
 -- Factual rows from client DB2 1.60.1.70425; docs/kit-status-provenance.json.
 -- Strongest first: each rank (same order as families.health) holds its two
 -- Improved Healthstone variants, then the base stone.
 healthItems={19013,19012,9421,19011,19010,5510,19009,19008,5509,19007,19006,5511,19005,19004,5512},
 healthRanks={{19013,19012,9421},{19011,19010,5510},{19009,19008,5509},{19007,19006,5511},{19005,19004,5512}},
 auras={soul={20707,20762,20763,20764,20765},sacrifice={18789,18790,18791,18792},link={19028,25228},
  fire={23480,23481,23482,23483},stone={1237162,1237164,1237165}},
 enchants={fire={1803,1823,1824,1825},stone={8059,8060,8061}},
 groups={
  {key='health',families={'health'},stone=true},
  {key='soul',families={'soul'},stone=true},
  {key='demon',families={'imp','void','succubus','incubus','felhunter','infernal','doom'}},
  {key='sacrifice',families={'sacrifice'},talent=true},
  {key='link',families={'link'},talent=true,self=true,reminder=true},
  {key='domination',families={'domination'},talent=true,self=true},
  {key='curse1',families={'elements','weakness','recklessness','tongues','exhaustion','havoc'}},
  {key='curse2',families={'recklessness','tongues','weakness','elements','exhaustion','havoc'}},
  {key='ward',families={'ward'},self=true},
  {key='armor',families={'armor'},self=true,reminder=true},
  {key='weapon',families={'fire','stone'},stone=true,weapon=true,reminder=true},
  {key='summon',families={'summon'}},
  {key='utility',families={'breath','invisibility','eye','sense'}},
 },
}
