RustRemover = RustRemover or {}

RustRemover.MODULE = "RustRemover"
RustRemover.COMMAND_REMOVE_RUST = "removeRust"
RustRemover.MAX_DISTANCE = 5.0
RustRemover.FULL_EPSILON = 0.01

RustRemover.CLEANING_LIQUID_FLUID_TYPES = {
    "CleaningLiquid",
    "Bleach",
}

RustRemover.CLEANING_LIQUID_ITEM_TYPES = {
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

function RustRemover.isItemNotEmpty(item)
    if not item then return false end
    local fluid = getFluidContainerSafe(item)
    if fluid then
        return fluid:getAmount() > 0.0
    end
    if item.IsDrainable and item:IsDrainable() and item.getUsedDelta then
        return item:getUsedDelta() > 0.0
    end
    return false
end

function RustRemover.isWaterBucket(item)
    if not item then return false end
    local ft = item:getFullType()
    local valid = false
    for _, wanted in ipairs(RustRemover.BUCKET_TYPES) do
        if ft == wanted then valid = true break end
    end
    if not valid then return false end

    local fluid = getFluidContainerSafe(item)
    if fluid then
        local primary = fluid:getPrimaryFluid()
        if not primary then return false end

        -- Only clean water is accepted.
        if primary:getFluidTypeString() ~= "Water" then return false end
        if fluid.isTainted and fluid:isTainted() then return false end

        return RustRemover.isItemNotEmpty(item)
    end

    return false
end

function RustRemover.isCleaningLiquidNotEmpty(item)
    if not item then return false end

    if not RustRemover.isItemInTypes(item, RustRemover.CLEANING_LIQUID_ITEM_TYPES) then return false end

    local fluidContainer = getFluidContainerSafe(item)
    if not fluidContainer then return false end

    local fluid = fluidContainer:getPrimaryFluid()
    if not fluid then return false end
    if not RustRemover.isCleaningFluid(fluid:getFluidTypeString()) then return false end
    if fluidContainer.isMixture and fluidContainer:isMixture() then return false end

    return not fluidContainer:isEmpty()
end

function RustRemover.isCleaningCloth(item)
    if not item then return false end
    local ft = item:getFullType()
    for _, wanted in ipairs(RustRemover.CLOTH_TYPES) do
        if ft == wanted then return true end
    end
    return false
end

function RustRemover.isCleaningFluid(fluid)
    if not fluid then return false end
    for _, wanted in ipairs(RustRemover.CLEANING_LIQUID_FLUID_TYPES) do
        if fluid == wanted then return true end
    end
    return false
end

function RustRemover.isItemInTypes(item, types)
    if not item then return false end
    local type = item:getFullType()
    for _, wanted in ipairs(types) do
        if type == wanted then return true end
    end
    return false
end

local function findFirst(inv, types, predicate)
    for _, fullType in ipairs(types) do
        local items = inv:getAllTypeRecurse(fullType)
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
    local inv = playerObj:getInventory()
    local cleaningLiquid = findFirst(inv, RustRemover.CLEANING_LIQUID_ITEM_TYPES, RustRemover.isCleaningLiquidNotEmpty)
    local waterContainer = findFirst(inv, RustRemover.BUCKET_TYPES, RustRemover.isWaterBucket)
    local cloth = findFirst(inv, RustRemover.CLOTH_TYPES, RustRemover.isCleaningCloth)
    return cleaningLiquid, waterContainer, cloth
end

function RustRemover.hasSupplies(playerObj)
    local liquid,bucket,cloth = RustRemover.findSupplies(playerObj)
    return liquid ~= nil and bucket ~= nil and cloth ~= nil
end

function RustRemover.isNearVehicle(playerObj, vehicle)
    if not playerObj or not vehicle then return false end
    local dx = playerObj:getX() - vehicle:getX()
    local dy = playerObj:getY() - vehicle:getY()
    return dx*dx + dy*dy <= RustRemover.MAX_DISTANCE * RustRemover.MAX_DISTANCE
end
