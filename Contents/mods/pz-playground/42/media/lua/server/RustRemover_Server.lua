require "RustRemover_Shared"

RustRemover_Server = RustRemover_Server or {}

local function syncItem(item)
    if isServer() and sendItemStats and item then sendItemStats(item) end
end

local function getFluidToRemove(item, rust)
    if not item then return 0.0 end
    if ComponentType and ComponentType.FluidContainer and item.hasComponent and item:hasComponent(ComponentType.FluidContainer) then
        local fluid = item:getFluidContainer()
        if not fluid then return false end

        local fluidLiterToRemove = math.min(rust * fluid:getCapacity(), fluid:getAmount())
        return fluidLiterToRemove / fluid:getCapacity()
    end

    return 0.0
end

local function emptyFluid(item, fluidToRemove)
    if not item then return 0.0 end
    if ComponentType and ComponentType.FluidContainer and item.hasComponent and item:hasComponent(ComponentType.FluidContainer) then
        local fluid = item:getFluidContainer()
        if not fluid then return false end
        
        fluid:removeFluid(fluidToRemove * fluid:getCapacity())

        syncItem(item)
        return true
    end

    return false
end

function RustRemover_Server.perform(playerObj, args)
    if not playerObj or not args or not args.vehicle then return false end
    local vehicle = getVehicleById(tonumber(args.vehicle))
    if not vehicle then
        print("[RustRemover] rejected: vehicle not found")
        return false
    end

    local rust = vehicle:getRust()
    if not rust or rust <= 0.0001 then
        print("[RustRemover] rejected: no rust")
        return false
    end

    if not RustRemover.isNearVehicle(playerObj, vehicle) then
        print("[RustRemover] rejected: player too far")
        return false
    end

    local cleaningFluidContainerItem, waterContainerItem, absorbentItem = RustRemover.findSupplies(playerObj)
    if not cleaningFluidContainerItem or not waterContainerItem or not absorbentItem then
        print("[RustRemover] rejected: missing/fullness requirement failed")
        return false
    end

    if not RustRemover.isCleaningFluidNotEmpty(cleaningFluidContainerItem)
        or not RustRemover.isWaterBucket(waterContainerItem)
        or not RustRemover.isCleaningCloth(absorbentItem) then
        print("[RustRemover] rejected: supplies changed before completion")
        return false
    end

    local cleaningFluidToRemove = getFluidToRemove(cleaningFluidContainerItem, rust)
    local waterToRemove = getFluidToRemove(waterContainerItem, rust)
    local qtyToRemove = math.min(cleaningFluidToRemove, waterToRemove)

    if not emptyFluid(cleaningFluidContainerItem, qtyToRemove) then return false end
    if not emptyFluid(waterContainerItem, qtyToRemove) then return false end

    local oldRust = rust
    vehicle:setRust(vehicle:getRust() - qtyToRemove)
    if vehicle:getRust() <= RustRemover.FLOAT_EPSILON then vehicle:setRust(0) end
    vehicle:transmitRust()

    print(string.format(
        "[RustRemover] rust removed side=server vehicle=%d oldRust=%.3f newRust=%.3f",
        vehicle:getId(), oldRust, vehicle:getRust()
    ))
    return true
end

function RustRemover_Server.onClientCommand(module, command, playerObj, args)
    if module == RustRemover.MODULE
        and command == RustRemover.COMMAND_REMOVE_RUST then
        RustRemover_Server.perform(playerObj, args or {})
    end
end

Events.OnClientCommand.Add(RustRemover_Server.onClientCommand)
