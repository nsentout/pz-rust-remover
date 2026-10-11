RustRemover = RustRemover or {}

RustRemover.CLEANING_FLUID_NEEDED_LITER = 0.5
RustRemover.WATER_NEEDED_LITER = 5.0
RustRemover.MAX_ACTION_DURATION_MS = 500
RustRemover.MAX_DISTANCE_FROM_VEHICLE = 5.0

RustRemover.FLOAT_EPSILON = 0.00001

RustRemover.CLEANING_FLUIDS = {
    Fluid.CleaningLiquid,
    Fluid.Bleach
}

RustRemover.WATER_FLUIDS = {
    Fluid.Water
}

RustRemover.CLOTH_TYPES = {
    "Base.RippedSheets",
    "Base.Sponge",
}

local function isFluidAndNotEmptyAndPure(item, fluid)
    if not item then return false end
    local fluidContainer = item:getFluidContainer()
    if not fluidContainer then return false end

    return not fluidContainer:isEmpty() and fluidContainer:isPureFluid(fluid)
end

local function isFluidAndNotEmptyAndPureAndNotTainted(item, fluid)
    if not item then return false end
    local fluidContainer = item:getFluidContainer()
    if not fluidContainer then return false end

    return isFluidAndNotEmptyAndPure(item, fluid) and not fluidContainer:isTainted()
end

local function isAbsorbent(item)
    if not item then return false end
    local itemType = item:getFullType()
    for _, wantedType in ipairs(RustRemover.CLOTH_TYPES) do
        if itemType == wantedType then return true end
    end
    return false
end

local function findFirstFluidContainerItem(inventory, predicate, fluids)
    for _, fluid in ipairs(fluids) do
        local fluidContainers = inventory:getAllEvalRecurse(function(item)
            if item:getFluidContainer() and predicate(item, fluid)  then
                return true
            end
            return false
        end)

        if not fluidContainers:isEmpty() then
            return fluidContainers:get(0)
        end
    end
    return nil
end

local function findFirstAbsorbentItem(inventory, predicate, types)
    for _, fullType in ipairs(types) do
        local items = inventory:getAllTypeRecurse(fullType)
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if predicate(item) then return item end
            end
        end
    end
    return nil
end

function RustRemover.findSupplies(playerObj)
    if not playerObj or not playerObj:getInventory() then return nil,nil,nil end
    local inventory = playerObj:getInventory()
    local cleaningFluidContainerItem = findFirstFluidContainerItem(inventory, isFluidAndNotEmptyAndPure, RustRemover.CLEANING_FLUIDS)
    local waterContainerItem = findFirstFluidContainerItem(inventory, isFluidAndNotEmptyAndPureAndNotTainted, RustRemover.WATER_FLUIDS)
    local absorbentItem = findFirstAbsorbentItem(inventory, isAbsorbent, RustRemover.CLOTH_TYPES)

    return cleaningFluidContainerItem, waterContainerItem, absorbentItem
end

function RustRemover.hasSupplies(playerObj)
    local cleaningFluidContainerItem, waterContainerItem, absorbentItem = RustRemover.findSupplies(playerObj)
    return cleaningFluidContainerItem ~= nil and waterContainerItem ~= nil and absorbentItem ~= nil
end

function RustRemover.isNearVehicle(playerObj, vehicle)
    if not playerObj or not vehicle then return false end
    local dx = playerObj:getX() - vehicle:getX()
    local dy = playerObj:getY() - vehicle:getY()
    return dx*dx + dy*dy <= RustRemover.MAX_DISTANCE_FROM_VEHICLE * RustRemover.MAX_DISTANCE_FROM_VEHICLE
end
