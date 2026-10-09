RustRemover = RustRemover or {}

RustRemover.MODULE = "RustRemover"
RustRemover.COMMAND_REMOVE_RUST = "removeRust"
RustRemover.MAX_DISTANCE = 5.0
RustRemover.FULL_EPSILON = 0.01

RustRemover.CLEANING_LIQUID_TYPES = {
    "Base.CleaningLiquid2",
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

function RustRemover.isItemFull(item)
    if not item then return false end
    local fluid = getFluidContainerSafe(item)
    if fluid then
        local cap = fluid:getCapacity()
        local amt = fluid:getAmount()
        return cap and cap > 0 and amt >= (cap - RustRemover.FULL_EPSILON)
    end
    if item.IsDrainable and item:IsDrainable() and item.getUsedDelta then
        return item:getUsedDelta() >= (1.0 - RustRemover.FULL_EPSILON)
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

        return RustRemover.isItemFull(item)
    end

    return false
end

function RustRemover.isFullCleaningLiquid(item)
    if not item then return false end

    -- Pass 1: it must be the vanilla B42 Cleaning Liquid bottle.
    if item:getFullType() ~= "Base.CleaningLiquid2" then return false end

    local fluid = getFluidContainerSafe(item)
    if not fluid then return false end

    -- Pass 2: verify that the bottle actually contains Cleaning Liquid.
    local primary = fluid:getPrimaryFluid()
    if not primary then return false end
    if primary:getFluidTypeString() ~= "CleaningLiquid" then return false end

    -- Reject mixed contents.
    if fluid.isMixture and fluid:isMixture() then return false end

    -- Require the standard bottle to be exactly full: 500 / 500 mL.
    local cap = fluid:getCapacity()
    local amt = fluid:getAmount()
    if not cap or not amt then return false end

    local target = 0.5
    local epsilon = RustRemover.FULL_EPSILON
    if math.abs(cap - target) > epsilon then return false end
    return amt >= (target - epsilon)
end

function RustRemover.isCleaningCloth(item)
    if not item then return false end
    local ft = item:getFullType()
    for _, wanted in ipairs(RustRemover.CLOTH_TYPES) do
        if ft == wanted then return true end
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
    local liquid = findFirst(inv, RustRemover.CLEANING_LIQUID_TYPES, RustRemover.isFullCleaningLiquid)
    local bucket = findFirst(inv, RustRemover.BUCKET_TYPES, RustRemover.isWaterBucket)
    local cloth = findFirst(inv, RustRemover.CLOTH_TYPES, RustRemover.isCleaningCloth)
    return liquid, bucket, cloth
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
