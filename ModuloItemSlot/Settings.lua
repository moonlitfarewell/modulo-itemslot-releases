local MIS=_G.ModuloItemSlot
if not MIS then return end
local function RegisterSettings()
    if not Settings or type(Settings.RegisterVerticalLayoutCategory)~="function" or MIS._settingsCategory then return end
    local category=Settings.RegisterVerticalLayoutCategory("Modulo ItemSlot")
    if Settings.RegisterAddOnCategory then Settings.RegisterAddOnCategory(category) end
    MIS._settingsCategory=category
    local function checkbox(id,title,getter,setter,tooltip)
        local setting=Settings.RegisterProxySetting(category,"MODULO_ITEM_SLOT_"..id,"boolean",title,false,getter,setter)
        Settings.CreateCheckbox(category,setting,tooltip)
    end
    local function slider(id,title,defaultValue,minValue,maxValue,step,getter,setter,tooltip,formatter)
        local setting=Settings.RegisterProxySetting(category,"MODULO_ITEM_SLOT_"..id,"number",title,defaultValue,getter,setter)
        local options=Settings.CreateSliderOptions(minValue,maxValue,step)
        if formatter and options.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,formatter)
        end
        Settings.CreateSlider(category,setting,options,tooltip)
    end
    if Settings.RegisterInitializer and CreateSettingsListSectionHeaderInitializer then Settings.RegisterInitializer(category,CreateSettingsListSectionHeaderInitializer("Equipment Bar")) end
    local orientation=Settings.RegisterProxySetting(category,"MODULO_ITEM_SLOT_ORIENTATION","string","Bar orientation","HORIZONTAL",function() return MIS.db.orientation end,function(v) MIS.SetOrientation(v) end)
    local orientationValues=Settings.CreateControlTextContainer(); orientationValues:Add("HORIZONTAL","Horizontal"); orientationValues:Add("VERTICAL","Vertical")
    Settings.CreateDropdown(category,orientation,function() return orientationValues:GetData() end,"Arrange enabled equipment slots in one horizontal or vertical bar.")
    slider("ICON_SCALE","Icon size (%)",100,70,160,5,function() return MIS.db.iconScale end,function(v) MIS.SetIconScale(v) end,"Scale the slot icons and the complete bar proportionally.",function(value)
        local pixels=math.floor(38*(tonumber(value) or 100)/100+0.5)
        return string.format("%d%%  (%d px)",tonumber(value) or 100,pixels)
    end)
    slider("SPACING","Button spacing",3,0,12,1,function() return MIS.db.spacing end,function(v) MIS.SetSpacing(v) end,"Set the gap between equipment slots in pixels.",function(value)
        return string.format("%d px",tonumber(value) or 0)
    end)
    checkbox("LABELS","Show slot labels",function() return MIS.db.showLabels end,function(v) MIS.SetLabels(v) end,"Show or hide the names beneath slot icons.")
    local direction=Settings.RegisterProxySetting(category,"MODULO_ITEM_SLOT_FLYOUT_DIRECTION","string","Item window direction","UP",function() return MIS.db.flyoutDirection end,function(v) MIS.SetFlyoutDirection(v) end)
    Settings.CreateDropdown(category,direction,function()
        local values=Settings.CreateControlTextContainer()
        if MIS.db.orientation=="VERTICAL" then values:Add("LEFT","Left"); values:Add("RIGHT","Right")
        else values:Add("UP","Up"); values:Add("DOWN","Down") end
        return values:GetData()
    end,"Horizontal bars support Up/Down; vertical bars support Left/Right.")
    local tooltip=Settings.RegisterProxySetting(category,"MODULO_ITEM_SLOT_TOOLTIP_MODE","string","Hover tooltips","FULL",function() return MIS.db.tooltipMode end,function(v) MIS.SetTooltipMode(v) end)
    local tooltipValues=Settings.CreateControlTextContainer(); tooltipValues:Add("FULL","Full item tooltip"); tooltipValues:Add("NAME","Item name only"); tooltipValues:Add("OFF","Off")
    Settings.CreateDropdown(category,tooltip,function() return tooltipValues:GetData() end,"Choose full item details, a compact item-name tooltip, or no hover tooltip.")
    if Settings.RegisterInitializer and CreateSettingsListSectionHeaderInitializer then Settings.RegisterInitializer(category,CreateSettingsListSectionHeaderInitializer("Equipment Slots")) end
    for _,entry in ipairs(MIS.SlotDefinitions) do
        local slotID=entry.slot
        checkbox("SLOT_"..slotID,entry.name,function() return MIS.db.slots[slotID]==true end,function(v) MIS.SetSlotEnabled(slotID,v) end,"Show or hide "..entry.name.." as an independent equipment button.")
    end
end
local frame=CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent",function(_,_,addonName) if addonName==MIS.name then RegisterSettings() end end)
if MIS.name and C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(MIS.name) then RegisterSettings() end
