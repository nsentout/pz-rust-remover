RustRemover = RustRemover or {}

RustRemover.MODULE = "RustRemover"
RustRemover.COMMAND_REMOVE_RUST = "removeRust"
RustRemover.MAX_DISTANCE = 5.0
RustRemover.FLOAT_EPSILON = 0.00001

RustRemover.CLEANING_FLUID_TYPES = {
    "CleaningLiquid",
    "Bleach",
}

RustRemover.CLEANING_FLUID_ITEM_TYPES = {
    "Base.CleaningLiquid2",
    "Base.Bleach",
}

RustRemover.BUCKET_TYPES = {
    "Base.Bucket",
    "Base.BucketEmpty",
    "Base.BucketWater",
    "Base.BucketWaterDebug",
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

function RustRemover.isFluidContainerNotEmpty(item)
    if not item then return false end
    local fluidContainer = getFluidContainerSafe(item)
    if fluidContainer then
        return fluidContainer:getAmount() > 0.0
    end
    return false
end

function RustRemover.isWaterBucket(item)
    if not item then return false end
    local itemType = item:getFullType()
    local valid = false
    for _, wantedType in ipairs(RustRemover.BUCKET_TYPES) do
        if itemType == wantedType then valid = true break end
    end
    if not valid then return false end

    local fluidContainer = getFluidContainerSafe(item)
    if fluidContainer then
        local primaryFluid = fluidContainer:getPrimaryFluid()
        if not primaryFluid then return false end

        -- Only clean water is accepted.
        if primaryFluid:getFluidTypeString() ~= "Water" then return false end
        if fluidContainer.isTainted and fluidContainer:isTainted() then return false end

        return RustRemover.isFluidContainerNotEmpty(item)
    end

    return false
end

function RustRemover.isCleaningFluidNotEmpty(item)
    if not item then return false end

    if not RustRemover.isItemInTypes(item, RustRemover.CLEANING_FLUID_ITEM_TYPES) then return false end

    local fluidContainer = getFluidContainerSafe(item)
    if not fluidContainer then return false end

    local primaryFluid = fluidContainer:getPrimaryFluid()
    if not primaryFluid then return false end
    if not RustRemover.isCleaningFluid(primaryFluid:getFluidTypeString()) then return false end
    if fluidContainer.isMixture and fluidContainer:isMixture() then return false end

    return not fluidContainer:isEmpty()
end

function RustRemover.isAbsorbent(item)
    if not item then return false end
    local itemType = item:getFullType()
    for _, wantedType in ipairs(RustRemover.CLOTH_TYPES) do
        if itemType == wantedType then return true end
    end
    return false
end

function RustRemover.isCleaningFluid(fluid)
    if not fluid then return false end
    for _, wantedType in ipairs(RustRemover.CLEANING_FLUID_TYPES) do
        if fluid == wantedType then return true end
    end
    return false
end

function RustRemover.isItemInTypes(item, types)
    if not item then return false end
    local itemType = item:getFullType()
    for _, wantedType in ipairs(types) do
        if itemType == wantedType then return true end
    end
    return false
end

local function findFirst(inventoy, types, predicate)
    for _, fullType in ipairs(types) do
        local items = inventoy:getAllTypeRecurse(fullType)
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
    local inventoy = playerObj:getInventory()
    local cleaningFluidContainerItem = findFirst(inventoy, RustRemover.CLEANING_FLUID_ITEM_TYPES, RustRemover.isCleaningFluidNotEmpty)
    local waterContainerItem = findFirst(inventoy, RustRemover.BUCKET_TYPES, RustRemover.isWaterBucket)
    local absorbentItem = findFirst(inventoy, RustRemover.CLOTH_TYPES, RustRemover.isAbsorbent)
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
