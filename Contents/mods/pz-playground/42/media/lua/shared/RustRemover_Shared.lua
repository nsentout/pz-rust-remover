RustRemover = RustRemover or {}

RustRemover.MODULE = "RustRemover"
RustRemover.COMMAND_REMOVE_RUST = "removeRust"
RustRemover.FLOAT_EPSILON = 0.00001

RustRemover.CLEANING_FLUID_NEEDED_LITER = 1
RustRemover.WATER_NEEDED_LITER = 4.0 
RustRemover.MAX_DISTANCE = 5.0

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

local function getFluidContainerSafe(item)
    if not item then return nil end
    if not ComponentType or not ComponentType.FluidContainer then return nil end
    if not item.hasComponent or not item:hasComponent(ComponentType.FluidContainer) then return nil end
    return item:getFluidContainer()
end

local function isFluidAndNotEmptyAndPure(item, fluid)
    local fluidContainer = getFluidContainerSafe(item)
    if not fluidContainer then return false end

    return not fluidContainer:isEmpty() and fluidContainer:isPureFluid(fluid)
end

local function isFluidAndNotEmptyAndPureAndNotTainted(item, fluid)
    local fluidContainer = getFluidContainerSafe(item)
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
        local fluidContainerItem = inventory:getFirstFluidContainer(fluid:getFluidTypeString())
        if fluidContainerItem and predicate(fluidContainerItem, fluid) then return fluidContainerItem end
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
    return dx*dx + dy*dy <= RustRemover.MAX_DISTANCE * RustRemover.MAX_DISTANCE
end
