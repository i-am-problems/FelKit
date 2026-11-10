-- Click anywhere on an enemy card, DoT bars included, to target that enemy.
--
-- Targeting needs secure buttons, and the game lets no add-on move a secure
-- button or change its unit in combat, while card geometry turns secret there.
-- So one secure button per card is laid over it out of combat, from the public
-- layout; the holder hides as combat starts and comes back after it, so a
-- stale button never targets the wrong enemy.
-- Buttons hang from their own holder on UIParent: a secure frame anchored to a
-- card would lock the card layout (and the panel) in combat.
local _,S=...
local P={buttons={},entries={},shown=0}; S.CardClick=P
local A=S.API
local INTERVAL=0.1

local function lockdown() return InCombatLockdown and InCombatLockdown() and true or false end
-- From PLAYER_REGEN_DISABLED until the player leaves combat, buttons stay away.
local function blocked()
    if lockdown() then return true end
    if P.suspended and UnitAffectingCombat and A.call(UnitAffectingCombat,'player')==true then return true end
    P.suspended=nil; return false
end
local function number(v) v=A.public(v); return type(v)=='number' and v or nil end
-- Rectangle in UIParent units, or nil when hidden, unplaced or secret.
local function rect(f)
    if not f or not f:IsVisible() then return end
    local ok,l,b,w,h=pcall(function() return f:GetLeft(),f:GetBottom(),f:GetWidth(),f:GetHeight() end)
    if not ok then return end
    l,b,w,h=number(l),number(b),number(w),number(h)
    if not (l and b and w and h) or w<=0 or h<=0 then return end
    local s=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
    return l*s,b*s,(l+w)*s,(b+h)*s
end
-- Tooltips of the bars under a button follow the cursor as if it were absent.
local function forward()
    local btn=P.hover; local e=btn and btn.entry; local over
    if e and e.bars then
        for _,f in ipairs(e.bars) do if f:IsVisible() and f:IsMouseOver() then over=f; break end end
    end
    if over==P.over then return end
    local old=P.over; P.over=over
    if old then local script=old:GetScript('OnLeave'); if script then script(old) end end
    if over then local script=over:GetScript('OnEnter'); if script then script(over) end end
end
local function holder()
    if P.holder or lockdown() then return P.holder end
    local h=CreateFrame('Frame','FelkitCardClick',UIParent,'SecureHandlerStateTemplate')
    h:SetAllPoints(UIParent)
    if RegisterStateDriver then RegisterStateDriver(h,'visibility','[combat] hide; show') end
    h:SetScript('OnUpdate',function()
        if P.hover then forward() end
        local now=GetTime()
        if now-(P.placed or 0)>=INTERVAL then P.place() end
    end)
    P.holder=h; return h
end
local function button(i)
    local b=P.buttons[i]
    if b then return b end
    b=CreateFrame('Button',nil,P.holder,'SecureActionButtonTemplate')
    b:RegisterForClicks('AnyUp'); b:SetAttribute('useOnKeyDown',false)
    b:SetAttribute('type1','target')
    local glow=b:CreateTexture(nil,'HIGHLIGHT'); glow:SetAllPoints(); glow:SetColorTexture(1,1,1,0.06)
    b:SetScript('OnEnter',function(self) P.hover=self; forward() end)
    b:SetScript('OnLeave',function(self) if P.hover==self then P.hover=nil; forward() end end)
    P.buttons[i]=b; return b
end
-- entries: {frame=card, token=unit token, bars=optional frames with tooltips};
-- clip: optional frame whose rectangle bounds the buttons (a scroll frame).
function P.set(entries,clip)
    P.entries=entries or {}; P.clip=clip
    if not blocked() then P.place() end
end
function P.place()
    P.placed=GetTime()
    -- No enemy card and no button shown: no secure holder and no work.
    if not next(P.entries or {}) and (P.shown or 0)==0 then return end
    if blocked() or not holder() then return end
    local cl,cb,cr,ct
    if P.clip then cl,cb,cr,ct=rect(P.clip) end
    local entries=(cl or not P.clip) and P.entries or {}
    local used=0
    for _,e in ipairs(entries) do
        local token=e.token
        local l,b,r,t
        if type(token)=='string' and token~='none' then l,b,r,t=rect(e.frame) end
        if l and cl then l,b,r,t=math.max(l,cl),math.max(b,cb),math.min(r,cr),math.min(t,ct) end
        if l and r-l>=2 and t-b>=2 then
            used=used+1
            local btn=button(used); btn.entry=e
            if btn.token~=token then btn:SetAttribute('unit',token); btn.token=token end
            local key=string.format('%.1f:%.1f:%.1f:%.1f',l,b,r-l,t-b)
            if btn.key~=key then
                btn:ClearAllPoints(); btn:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',l,b); btn:SetSize(r-l,t-b); btn.key=key
            end
            btn:SetFrameStrata(e.frame:GetFrameStrata()); btn:SetFrameLevel(e.frame:GetFrameLevel()+20)
            btn:Show()
        end
    end
    for i=used+1,#P.buttons do local btn=P.buttons[i]; btn:Hide(); btn.entry=nil end
    P.shown=used
end
-- PLAYER_REGEN_DISABLED fires just before the lockdown: last chance to hide.
function P.hide()
    P.suspended=true; P.hover=nil; forward()
    if lockdown() then return end
    for _,btn in ipairs(P.buttons) do btn:Hide(); btn.entry=nil end
    P.shown=0
end
function P.resume() P.suspended=nil; P.place() end
