local _,S=...
local A=S.API
S.shardTrace={keys=0,clicks=0,attempts=0,last='no-input'}

-- The game lets an addon delete an item only during a real key press or click,
-- in combat as well as out: each input deletes at most one bag slot.
-- Runs synchronously from that input, never from a bag event or timer.
-- No synthetic key presses, secure-call bypass, click overlay or binding replacement.
-- Each kind of input is judged on its own, in combat and out separately: one the
-- game refuses is remembered and skipped, the others carry on.
function S.autoInput(kind)
    local t=S.shardTrace
    if not S.ready then t.last='not-ready'; return end
    if not S.db.enabled or not S.db.shards or not S.db.autoShards then t.last='disabled'; return end
    kind=(kind or 'key')..(A.combat() and ' in combat' or '')
    if S.db.shardRefused[kind] then t.last='refused'; return end
    -- The last look found nothing to delete and the bags have not changed since.
    if S.shardIdle and GetTime()<S.shardIdle then t.last='nothing'; return end
    if A.cursor() then t.last='cursor'; return end
    if A.call(GetCurrentKeyBoardFocus) then t.last='typing'; return end
    -- A spell waiting for its target would take the shard.
    if A.call(SpellIsTargeting)==true then t.last='targeting'; return end
    if S.prune(kind)=='blocked' then
        S.db.shardRefused[kind]=true
        S.print(string.format(S.L.autoStopped,kind))
    end
end

-- The calls the hooks follow (whichever this client has). The hook runs just
-- after the call, still inside the input; controller buttons only show up here.
local USE_CALLS={'UseAction','CastSpellByName','CastSpellByID','UseItemByName','UseContainerItem',
    'UseInventoryItem','JumpOrAscendStart','InteractUnit'}

function S.setupAutoInput()
    -- Configure keyboard propagation outside combat; never change it in an input callback.
    if S.autoFrame or A.combat() then return end
    local f=CreateFrame('Frame',nil,UIParent)
    f:SetSize(1,1); f:SetPoint('CENTER'); f:EnableMouse(false); f:Show()
    f:SetFrameStrata('BACKGROUND')
    f:SetPropagateKeyboardInput(true)
    f:EnableKeyboard(true)
    f:SetScript('OnKeyDown',function()
        S.shardTrace.keys=S.shardTrace.keys+1
        S.autoInput('key')
    end)
    S.autoFrame=f
    for _,name in ipairs(USE_CALLS) do
        if type(_G[name])=='function' then
            pcall(hooksecurefunc,name,function() S.autoInput(name) end)
        end
    end
    if C_Container and type(C_Container.UseContainerItem)=='function' then
        pcall(hooksecurefunc,C_Container,'UseContainerItem',function() S.autoInput('UseContainerItem') end)
    end
    if WorldFrame and WorldFrame.HookScript then
        WorldFrame:HookScript('OnMouseDown',function(_,button)
            if button=='LeftButton' and A.call(IsMouseButtonDown,'RightButton')~=true then
                S.shardTrace.clicks=S.shardTrace.clicks+1; S.autoInput('click')
            end
        end)
    end
end
