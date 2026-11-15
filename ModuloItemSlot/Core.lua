local ADDON_NAME, MIS = ...
MIS = MIS or {}
_G.ModuloItemSlot = MIS

MIS.name = ADDON_NAME or "ModuloItemSlot"
MIS.version = "1.0.0"

local SLOT_ORDER = {
    { slot=1, name="Head", loc="INVTYPE_HEAD", inv="HeadSlot" },
    { slot=2, name="Neck", loc="INVTYPE_NECK", inv="NeckSlot" },
    { slot=3, name="Shoulders", loc="INVTYPE_SHOULDER", inv="ShoulderSlot" },
    { slot=4, name="Shirt", loc="INVTYPE_BODY", inv="ShirtSlot" },
    { slot=5, name="Chest", loc="INVTYPE_CHEST", inv="ChestSlot" },
    { slot=6, name="Waist", loc="INVTYPE_WAIST", inv="WaistSlot" },
    { slot=7, name="Legs", loc="INVTYPE_LEGS", inv="LegsSlot" },
    { slot=8, name="Feet", loc="INVTYPE_FEET", inv="FeetSlot" },
    { slot=9, name="Wrist", loc="INVTYPE_WRIST", inv="WristSlot" },
    { slot=10, name="Hands", loc="INVTYPE_HAND", inv="HandsSlot" },
    { slot=11, name="Ring 1", loc="INVTYPE_FINGER", inv="Finger0Slot" },
    { slot=12, name="Ring 2", loc="INVTYPE_FINGER", inv="Finger1Slot" },
    { slot=13, name="Trinket 1", loc="INVTYPE_TRINKET", inv="Trinket0Slot" },
    { slot=14, name="Trinket 2", loc="INVTYPE_TRINKET", inv="Trinket1Slot" },
    { slot=15, name="Back", loc="INVTYPE_CLOAK", inv="BackSlot" },
    { slot=16, name="Main Hand", loc="INVTYPE_WEAPONMAINHAND", inv="MainHandSlot" },
    { slot=17, name="Off Hand", loc="INVTYPE_WEAPONOFFHAND", inv="SecondaryHandSlot" },
    { slot=18, name="Ranged", loc="INVTYPE_RANGED", inv="RangedSlot" },
    { slot=19, name="Tabard", loc="INVTYPE_TABARD", inv="TabardSlot" },
}
local SLOT_BY_ID = {}
for _, entry in ipairs(SLOT_ORDER) do SLOT_BY_ID[entry.slot] = entry end
MIS.SlotDefinitions, MIS.SlotByID = SLOT_ORDER, SLOT_BY_ID

local DEFAULTS = {
    orientation="HORIZONTAL", flyoutDirection="UP", tooltipMode="FULL",
    iconScale=100, spacing=3, showLabels=false,
    point="CENTER", relativePoint="CENTER", x=0, y=-190, slots={},
}
for _, entry in ipairs(SLOT_ORDER) do DEFAULTS.slots[entry.slot] = true end
MIS.db, MIS.frame, MIS.flyout = nil, nil, nil
MIS.slotButtons, MIS.itemButtons = {}, {}
MIS.pendingRefresh, MIS.openSlot = false, nil
MIS.itemCache = nil

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value)=="table" then
            if type(target[key])~="table" then target[key]={} end
            CopyDefaults(target[key], value)
        elseif target[key]==nil then target[key]=value end
    end
end
local function InitDB()
    if type(_G.ModuloItemSlotDB)~="table" then _G.ModuloItemSlotDB={} end
    MIS.db=_G.ModuloItemSlotDB
    if type(MIS.db.slots)~="table" then
        MIS.db.slots={}
        local oldSlot=tonumber(MIS.db.slot)
        for _, entry in ipairs(SLOT_ORDER) do MIS.db.slots[entry.slot]=(oldSlot and entry.slot==oldSlot or oldSlot==nil) end
    end
    if MIS.db.iconScale==nil and MIS.db.scale then MIS.db.iconScale=math.floor((tonumber(MIS.db.scale) or 1)*100+0.5) end
    CopyDefaults(MIS.db, DEFAULTS)
    MIS.db.orientation = MIS.db.orientation=="VERTICAL" and "VERTICAL" or "HORIZONTAL"
    local validDirections={UP=true,DOWN=true,LEFT=true,RIGHT=true}
    if not validDirections[MIS.db.flyoutDirection] then MIS.db.flyoutDirection="UP" end
    local validTooltips={FULL=true,NAME=true,OFF=true}
    if not validTooltips[MIS.db.tooltipMode] then MIS.db.tooltipMode="FULL" end
    MIS.db.iconScale=math.max(70,math.min(160,tonumber(MIS.db.iconScale) or 100))
    MIS.db.spacing=math.max(0,math.min(12,tonumber(MIS.db.spacing) or 3))
end
local function IsCombat() return InCombatLockdown and InCombatLockdown() end
local function GetItemInstant(item)
    if C_Item and C_Item.GetItemInfoInstant then return C_Item.GetItemInfoInstant(item) end
    if GetItemInfoInstant then return GetItemInfoInstant(item) end
end
local function GetItemName(item)
    if C_Item and C_Item.GetItemInfo then
        local name = C_Item.GetItemInfo(item)
        if name then return name end
    end
    if GetItemInfo then
        local name = GetItemInfo(item)
        if name then return name end
    end
    return nil
end
local function ApplyQuickslotSkin(button, iconSize)
    -- Blizzard's standard rounded action-button frame; no item-quality border.
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    local normal = button:GetNormalTexture()
    if normal then
        normal:ClearAllPoints()
        normal:SetPoint("CENTER", button, "CENTER", 0, 0)
        normal:SetSize(iconSize * 1.78, iconSize * 1.78)
    end
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
end
local function ContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
    if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
    return 0
end
local function ContainerInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then return C_Container.GetContainerItemInfo(bag,slot) end
    if GetContainerItemInfo then
        local texture,count,locked,quality,readable,lootable,link=GetContainerItemInfo(bag,slot)
        return {iconFileID=texture,stackCount=count,isLocked=locked,hyperlink=link}
    end
end
local function ItemMatchesSlot(item,targetSlot)
    local _,_,_,equipLoc=GetItemInstant(item)
    local wanted=SLOT_BY_ID[targetSlot]
    if not equipLoc or not wanted then return false end
    if targetSlot==16 then return equipLoc=="INVTYPE_WEAPON" or equipLoc=="INVTYPE_2HWEAPON" or equipLoc=="INVTYPE_WEAPONMAINHAND" end
    if targetSlot==17 then return equipLoc=="INVTYPE_WEAPON" or equipLoc=="INVTYPE_WEAPONOFFHAND" or equipLoc=="INVTYPE_SHIELD" or equipLoc=="INVTYPE_HOLDABLE" end
    if targetSlot==18 then return equipLoc=="INVTYPE_RANGED" or equipLoc=="INVTYPE_RANGEDRIGHT" or equipLoc=="INVTYPE_THROWN" or equipLoc=="INVTYPE_RELIC" end
    return equipLoc==wanted.loc
end
local function FindItems(targetSlot)
    if MIS.itemCache and MIS.itemCache[targetSlot] then return MIS.itemCache[targetSlot] end
    local results={}
    for bag=0,4 do
        for bagSlot=1,ContainerSlots(bag) do
            local info=ContainerInfo(bag,bagSlot)
            local link=info and info.hyperlink
            if link and not info.isLocked then
                local itemID=info.itemID or select(1,GetItemInstant(link))
                if itemID and ItemMatchesSlot(itemID,targetSlot) then
                    results[#results+1]={itemID=itemID,link=link,name=info.itemName or GetItemName(link),icon=info.iconFileID,count=info.stackCount or 1,bag=bag,bagSlot=bagSlot}
                end
            end
        end
    end
    table.sort(results,function(a,b)
        local an=tostring(a.name or a.itemID)
        local bn=tostring(b.name or b.itemID)
        if an==bn then return a.itemID<b.itemID end
        return an<bn
    end)
    MIS.itemCache = MIS.itemCache or {}
    MIS.itemCache[targetSlot] = results
    return results
end
local function EquippedInfo(slot)
    local link=GetInventoryItemLink and GetInventoryItemLink("player",slot)
    if not link then return nil end
    return {link=link,icon=GetInventoryItemTexture and GetInventoryItemTexture("player",slot)}
end
local function TooltipFor(owner, link, name)
    if not MIS.db or MIS.db.tooltipMode=="OFF" then return end
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    if MIS.db.tooltipMode=="FULL" and link then GameTooltip:SetHyperlink(link)
    else
        local itemName = link and GetItemName(link)
        GameTooltip:AddLine(itemName or name or "Unknown item",1,0.82,0)
    end
    GameTooltip:Show()
end
local function EmptySlotTexture(entry)
    if GetInventorySlotInfo then
        local _, texture=GetInventorySlotInfo(entry.inv)
        if texture then return texture end
    end
    return "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
end
local function CreateSlotButton(parent,entry)
    local button=CreateFrame("Button","ModuloItemSlotSlot"..entry.slot,parent)
    button:SetSize(38,38)
    button.icon=button:CreateTexture(nil,"BACKGROUND")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07,0.93,0.07,0.93)
    button.icon:SetTexture(EmptySlotTexture(entry))
    ApplyQuickslotSkin(button,38)
    -- Native Blizzard cooldown swipe and countdown, updated only by cooldown/
    -- equipment events (no OnUpdate polling).
    button.cooldown=CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button)
    button.cooldown:SetFrameLevel(button:GetFrameLevel()+1)
    if button.cooldown.SetDrawSwipe then button.cooldown:SetDrawSwipe(true) end
    if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(true) end
    if button.cooldown.SetHideCountdownNumbers then button.cooldown:SetHideCountdownNumbers(false) end
    button.slotID=entry.slot
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart",function() if IsAltKeyDown and IsAltKeyDown() and not IsCombat() then MIS.frame:StartMoving() end end)
    button:SetScript("OnDragStop",function()
        MIS.frame:StopMovingOrSizing()
        local point,_,relativePoint,x,y=MIS.frame:GetPoint(1)
        MIS.db.point,MIS.db.relativePoint,MIS.db.x,MIS.db.y=point,relativePoint,x,y
    end)
    button:SetScript("OnClick",function(self) if IsAltKeyDown and IsAltKeyDown() then return end; if MIS.ToggleFlyout then MIS.ToggleFlyout(self.slotID) end end)
    button:SetScript("OnEnter",function(self)
        if MIS.db.tooltipMode=="OFF" then return end
        local equipped=EquippedInfo(self.slotID)
        TooltipFor(self,equipped and equipped.link,entry.name)
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return button
end
local function PickupBagItem(bag, bagSlot)
    if C_Container and C_Container.PickupContainerItem then
        return C_Container.PickupContainerItem(bag,bagSlot)
    end
    if PickupContainerItem then return PickupContainerItem(bag,bagSlot) end
end
local function SwapBagItemIntoSlot(data,slotID)
    -- TrinketMenu's proven swap sequence: pick the bag item up, then pick
    -- the explicit inventory slot up. This swaps rather than equipping into
    -- whichever duplicate slot happens to be chosen automatically.
    if IsCombat() then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("Modulo ItemSlot: equipment cannot be swapped during combat.",1,0.2,0.2) end
        return false
    end
    if not data or not data.bag or not data.bagSlot then return false end
    if (CursorHasItem and CursorHasItem()) or (SpellIsTargeting and SpellIsTargeting()) then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("Modulo ItemSlot: finish the current cursor action first.",1,0.2,0.2) end
        return false
    end
    if IsInventoryItemLocked and IsInventoryItemLocked(slotID) then return false end

    -- Revalidate the captured bag position immediately before pickup. Bag
    -- contents can move between opening the flyout and clicking an icon.
    local current=ContainerInfo(data.bag,data.bagSlot)
    local currentID=current and (current.itemID or select(1,GetItemInstant(current.hyperlink or "")))
    if not current or not current.hyperlink or current.isLocked or currentID~=data.itemID then
        MIS.itemCache=nil
        MIS.Refresh()
        return false
    end

    PickupBagItem(data.bag,data.bagSlot)
    if CursorHasItem and not CursorHasItem() then
        MIS.itemCache=nil
        return false
    end
    if PickupInventoryItem then
        PickupInventoryItem(slotID)
    else
        -- If this client lacks the inventory pickup API, return the item to
        -- its source bag slot instead of leaving it on the cursor.
        PickupBagItem(data.bag,data.bagSlot)
        return false
    end
    -- If the destination rejected the item, restore it to its original bag
    -- position so we never leave an item attached to the cursor.
    if CursorHasItem and CursorHasItem() then
        PickupBagItem(data.bag,data.bagSlot)
        MIS.itemCache=nil
        return false
    end

    MIS.itemCache=nil
    if MIS.flyout then MIS.flyout:Hide() end
    MIS.openSlot=nil
    MIS.Refresh()
    return true
end

local function CreateItemButton(parent,index)
    local button=CreateFrame("Button","ModuloItemSlotItem"..index,parent)
    button:SetSize(36,36)
    button:RegisterForClicks("AnyUp")
    button.icon=button:CreateTexture(nil,"BACKGROUND")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07,0.93,0.07,0.93)
    ApplyQuickslotSkin(button,36)
    button.count=button:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall")
    button.count:SetPoint("BOTTOMRIGHT",-2,2)
    button:SetScript("OnClick",function(self)
        if self.itemData then SwapBagItemIntoSlot(self.itemData,self.destinationSlot) end
    end)
    button:SetScript("OnEnter",function(self)
        if self.itemLink and MIS.db.tooltipMode~="OFF" then TooltipFor(self,self.itemLink,self.itemName) end
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return button
end
local function BuildFlyout()
    if MIS.flyout then return MIS.flyout end
    local frame=CreateFrame("Frame","ModuloItemSlotFlyout",UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    for i=1,30 do MIS.itemButtons[i]=CreateItemButton(frame,i) end
    frame:Hide()
    MIS.flyout=frame
    return frame
end
local BASE_ICON_SIZE = 38
local function CurrentIconSize() return math.floor(BASE_ICON_SIZE*(MIS.db.iconScale/100)+0.5) end
local function PositionBar(frame,visibleCount)
    local size,gap=CurrentIconSize(),MIS.db.spacing
    local vertical=MIS.db.orientation=="VERTICAL"
    local labelHeight=MIS.db.showLabels and 14 or 0
    local buttonHeight=size+labelHeight
    local index=0
    for _,entry in ipairs(SLOT_ORDER) do
        local button=MIS.slotButtons[entry.slot]
        if MIS.db.slots[entry.slot] then
            index=index+1
            button:Show()
            -- Keep the icon/button square; labels live below it and never move the border.
            button:SetSize(size,size)
            ApplyQuickslotSkin(button,size)
            button.icon:ClearAllPoints()
            button.icon:SetAllPoints(button)
            if vertical then
                button:ClearAllPoints()
                button:SetPoint("TOP",frame,"TOP",0,-((index-1)*(buttonHeight+gap)))
            else
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT",frame,"TOPLEFT",(index-1)*(size+gap),0)
            end
            if MIS.db.showLabels then
                if not button.label then
                    button.label=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                    button.label:SetPoint("TOP",button,"BOTTOM",0,-1)
                    button.label:SetTextColor(1,0.82,0)
                    button.label:SetText(entry.name)
                    button.label:SetWidth(math.max(size+14,58))
                    button.label:SetJustifyH("CENTER")
                end
                button.label:SetWidth(math.max(size+14,58))
                button.label:Show()
            elseif button.label then button.label:Hide() end
        else button:Hide() end
    end
    local labelWidth = MIS.db.showLabels and math.max(size+14,58) or size
    if vertical then
        frame:SetSize(labelWidth,math.max(size,visibleCount*buttonHeight+math.max(0,visibleCount-1)*gap))
    else
        frame:SetSize(math.max(size,visibleCount*size+math.max(0,visibleCount-1)*gap),buttonHeight)
    end
end
local function UpdateSlotCooldown(slotID)
    local button=MIS.slotButtons[slotID]
    if not button or not button.cooldown then return end
    if not GetInventoryItemCooldown then
        button.cooldown:Hide()
        return
    end
    local start,duration,enable=GetInventoryItemCooldown("player",slotID)
    if enable~=0 and start and duration and start>0 and duration>0 then
        button.cooldown:SetCooldown(start,duration)
        button.cooldown:Show()
    else
        button.cooldown:Clear()
        button.cooldown:Hide()
    end
end
local function RefreshCooldowns()
    -- Hidden/disabled slots have no visible cooldown overlay to update.
    -- Revisit them when the player enables the slot (MIS.Refresh).
    for _,entry in ipairs(SLOT_ORDER) do
        if MIS.db and MIS.db.slots[entry.slot] then
            UpdateSlotCooldown(entry.slot)
        end
    end
end
local function RefreshSlotButton(entry)
    local button=MIS.slotButtons[entry.slot]
    if not button then return end
    local equipped=EquippedInfo(entry.slot)
    button.icon:SetTexture(equipped and equipped.icon or EmptySlotTexture(entry))
    UpdateSlotCooldown(entry.slot)
end
local function PositionFlyout(frame,anchor,count)
    local direction=MIS.db.flyoutDirection
    local size=CurrentIconSize()
    local gap=4
    -- Flyout axis is perpendicular to the main bar:
    -- horizontal bar => vertical item list; vertical bar => horizontal item row.
    local flyoutHorizontal = MIS.db.orientation=="VERTICAL"
    local width,height
    if flyoutHorizontal then width=count*size+math.max(0,count-1)*gap; height=size
    else width=size; height=count*size+math.max(0,count-1)*gap end
    frame:SetSize(math.max(size,width),math.max(size,height))
    for i,button in ipairs(MIS.itemButtons) do
        if i<=count then
            button:SetSize(size,size)
            ApplyQuickslotSkin(button,size)
            button:ClearAllPoints()
            if flyoutHorizontal then button:SetPoint("LEFT",frame,"LEFT",(i-1)*(size+gap),0)
            else button:SetPoint("TOP",frame,"TOP",0,-((i-1)*(size+gap))) end
        end
    end
    frame:ClearAllPoints()
    if direction=="UP" then frame:SetPoint("BOTTOM",anchor,"TOP",0,5)
    elseif direction=="DOWN" then frame:SetPoint("TOP",anchor,"BOTTOM",0,-5)
    elseif direction=="LEFT" then frame:SetPoint("RIGHT",anchor,"LEFT",-5,0)
    elseif direction=="RIGHT" then frame:SetPoint("LEFT",anchor,"RIGHT",5,0) end
end
local function PopulateFlyout(slotID,anchor)
    if IsCombat() then return false end
    local frame=BuildFlyout()
    local entry=SLOT_BY_ID[slotID]
    if not entry then return false end
    local items=FindItems(slotID)
    for i,button in ipairs(MIS.itemButtons) do
        local data=items[i]
        if data then
            button.icon:SetTexture(data.icon)
            button.count:SetText(data.count and data.count>1 and data.count or "")
            button.itemLink=data.link
            button.itemName=data.name or GetItemName(data.link) or data.link
            button.itemData=data
            button.destinationSlot=slotID
            button:Show()
        else
            button:Hide(); button.itemLink=nil; button.itemName=nil
            button.itemData=nil; button.destinationSlot=nil
        end
    end
    local visible=math.min(#items,#MIS.itemButtons)
    if visible==0 then frame:Hide(); MIS.openSlot=nil; return true end
    PositionFlyout(frame,anchor,visible)
    frame:Show()
    MIS.openSlot=slotID
    return true
end
function MIS.ToggleFlyout(slotID)
    if IsCombat() then return end
    if MIS.flyout and MIS.flyout:IsShown() and MIS.openSlot==slotID then MIS.flyout:Hide(); MIS.openSlot=nil; return end
    PopulateFlyout(slotID,MIS.slotButtons[slotID])
end
local function BuildBar()
    if MIS.frame then return MIS.frame end
    local frame=CreateFrame("Frame","ModuloItemSlotBar",UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self)
        if IsAltKeyDown and IsAltKeyDown() and not IsCombat() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local point,_,relativePoint,x,y=self:GetPoint(1)
        MIS.db.point,MIS.db.relativePoint,MIS.db.x,MIS.db.y=point,relativePoint,x,y
    end)
    for _,entry in ipairs(SLOT_ORDER) do MIS.slotButtons[entry.slot]=CreateSlotButton(frame,entry) end
    MIS.frame=frame
    BuildFlyout()
    return frame
end
function MIS.Refresh()
    if not MIS.db or not MIS.frame then return end
    if IsCombat() then MIS.pendingRefresh=true; return end
    MIS.pendingRefresh=false
    local frame=MIS.frame
    frame:ClearAllPoints()
    frame:SetPoint(MIS.db.point or "CENTER",UIParent,MIS.db.relativePoint or "CENTER",MIS.db.x or 0,MIS.db.y or -190)
    local count=0
    for _,entry in ipairs(SLOT_ORDER) do
        if MIS.db.slots[entry.slot] then
            count=count+1
            RefreshSlotButton(entry)
        else
            -- Hidden buttons need no inventory icon or cooldown queries.
            local button=MIS.slotButtons[entry.slot]
            if button and button.cooldown then button.cooldown:Hide() end
        end
    end
    PositionBar(frame,count)
    frame:Show()
    if MIS.flyout and MIS.flyout:IsShown() and MIS.openSlot then PopulateFlyout(MIS.openSlot,MIS.slotButtons[MIS.openSlot]) end
end
function MIS.SetIconScale(value) MIS.db.iconScale=math.max(70,math.min(160,tonumber(value) or 100)); MIS.Refresh() end
function MIS.SetOrientation(value)
    MIS.db.orientation=value=="VERTICAL" and "VERTICAL" or "HORIZONTAL"
    if MIS.db.orientation=="HORIZONTAL" and MIS.db.flyoutDirection~="UP" and MIS.db.flyoutDirection~="DOWN" then MIS.db.flyoutDirection="UP" end
    if MIS.db.orientation=="VERTICAL" and MIS.db.flyoutDirection~="LEFT" and MIS.db.flyoutDirection~="RIGHT" then MIS.db.flyoutDirection="LEFT" end
    MIS.Refresh()
end
function MIS.SetFlyoutDirection(value)
    local allowed=MIS.db.orientation=="VERTICAL" and (value=="LEFT" or value=="RIGHT") or MIS.db.orientation=="HORIZONTAL" and (value=="UP" or value=="DOWN")
    if allowed then MIS.db.flyoutDirection=value; MIS.Refresh() end
end
function MIS.SetTooltipMode(value)
    if value=="FULL" or value=="NAME" or value=="OFF" then MIS.db.tooltipMode=value end
end
function MIS.SetSlotEnabled(slotID,value)
    slotID=tonumber(slotID); if not SLOT_BY_ID[slotID] then return end
    MIS.db.slots[slotID]=value==true; MIS.Refresh()
end
function MIS.SetLabels(value) MIS.db.showLabels=value==true; MIS.Refresh() end
function MIS.SetSpacing(value) MIS.db.spacing=math.max(0,math.min(12,tonumber(value) or 3)); MIS.Refresh() end
function MIS.ToggleBar() if not MIS.frame then BuildBar() end; if MIS.frame:IsShown() then MIS.frame:Hide() else MIS.frame:Show() end end
function MIS.OpenSettings()
    if MIS._settingsCategory and Settings and Settings.OpenToCategory then Settings.OpenToCategory(MIS._settingsCategory:GetID()) end
end
local loader=CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("BAG_UPDATE_DELAYED")
loader:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Cooldown-only events update only the small overlay frames. They do not
-- rescan bags, rebuild flyouts, or reposition the bar.
loader:RegisterEvent("BAG_UPDATE_COOLDOWN")
loader:RegisterEvent("SPELL_UPDATE_COOLDOWN")
loader:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
loader:RegisterEvent("UNIT_INVENTORY_CHANGED")
loader:SetScript("OnEvent",function(_,event,addonName,arg1)
    if event=="ADDON_LOADED" then
        if addonName~=MIS.name then return end
        InitDB(); BuildBar(); MIS.Refresh()
    elseif event=="PLAYER_REGEN_ENABLED" then if MIS.pendingRefresh then MIS.Refresh() end
    elseif MIS.db and (event=="BAG_UPDATE_COOLDOWN" or event=="SPELL_UPDATE_COOLDOWN" or event=="ACTIONBAR_UPDATE_COOLDOWN") then
        RefreshCooldowns()
    elseif MIS.db and event=="UNIT_INVENTORY_CHANGED" then
        if arg1=="player" then RefreshCooldowns() end
    elseif MIS.db and (event=="PLAYER_ENTERING_WORLD" or event=="BAG_UPDATE_DELAYED" or event=="PLAYER_EQUIPMENT_CHANGED") then
        if event=="BAG_UPDATE_DELAYED" then MIS.itemCache=nil end
        MIS.Refresh()
    end
end)
SLASH_MODULOITEMSLOT1="/mis"; SLASH_MODULOITEMSLOT2="/moduloitemslot"
SlashCmdList.MODULOITEMSLOT=function(message)
    local command=strlower(strtrim(message or ""))
    if command=="" or command=="toggle" then MIS.ToggleBar()
    elseif command=="settings" then MIS.OpenSettings()
    elseif command=="reset" then
        for key,value in pairs(DEFAULTS) do if type(value)=="table" then MIS.db[key]={}; for k,v in pairs(value) do MIS.db[key][k]=v end else MIS.db[key]=value end end
        MIS.Refresh()
    else print("Modulo ItemSlot: hold ALT and drag the bar to move it; /mis [toggle|settings|reset]") end
end
