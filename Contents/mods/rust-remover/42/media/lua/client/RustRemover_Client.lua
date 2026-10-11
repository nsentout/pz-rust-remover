require "RustRemover_Shared"

RustRemover_Client = RustRemover_Client or {}

local function round(x)
    return math.floor(x + 0.5)
end

local function tooltip(hasCleaningFluid, hasWater, hasAbsorbent, rust)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.maxLineWidth = 1000
    tooltip.description = getText("Tooltip_RR_RemoveRust") .. " <LINE>" .. getText("Tooltip_RR_RustLevel", round(rust * 100))

    if not hasCleaningFluid or not hasWater or not hasAbsorbent then
        tooltip.description = tooltip.description .. " <LINE>"
    end

    if not hasCleaningFluid then
       tooltip.description = tooltip.description .. " <LINE>" .. getText("Tooltip_RR_MissingCleaningLiquid")
    end

    if not hasWater then
       tooltip.description = tooltip.description .. " <LINE>" .. getText("Tooltip_RR_MissingWater")
    end

    if not hasAbsorbent then
       tooltip.description = tooltip.description .. " <LINE>" .. getText("Tooltip_RR_MissingAbsorbent")
    end

    return tooltip
end

function RustRemover_Client.startAction(playerObj, vehicle)
    if not RustRemover.isNearVehicle(playerObj, vehicle) then
        playerObj:Say(getText("IGUI_RR_PlayerText_TooFarFromVehicle"))
        return
    end
    if RustRemover.hasSupplies(playerObj) then
        ISTimedActionQueue.add(ISRemoveVehicleRustAction:new(playerObj, vehicle))
    end
end

function RustRemover_Client.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not playerObj:isAlive() then return end

    local vehicle = IsoObjectPicker.Instance:PickVehicle(getMouseXScaled(), getMouseYScaled())
    if not vehicle or not vehicle:getRust() or vehicle:getRust() <= RustRemover.FLOAT_EPSILON then return end

    local cleaningFluidContainerItem, waterContainerItem, absorbentItem = RustRemover.findSupplies(playerObj)
    local option = context:addOption(getText("ContextMenu_RR_RemoveRust"), playerObj, RustRemover_Client.startAction, vehicle)
    option.toolTip = tooltip(cleaningFluidContainerItem ~= nil, waterContainerItem ~= nil, absorbentItem ~= nil, vehicle:getRust())
    if not (cleaningFluidContainerItem and waterContainerItem and absorbentItem) then option.notAvailable = true end
end

Events.OnFillWorldObjectContextMenu.Add(RustRemover_Client.onFillWorldObjectContextMenu)
