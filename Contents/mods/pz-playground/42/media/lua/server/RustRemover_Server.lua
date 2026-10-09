require "RustRemover_Shared"

RustRemover_Server = RustRemover_Server or {}

local function syncItem(item)
    if isServer() and sendItemStats and item then sendItemStats(item) end
end

local function emptyLiquid(item, rust)
    if not item then return 0.0 end
    if ComponentType and ComponentType.FluidContainer and item.hasComponent and item:hasComponent(ComponentType.FluidContainer) then
        local fluid = item:getFluidContainer()
        if not fluid then return false end
        
        local fluidToRemove = rust * fluid:getCapacity()
        local oldFluidAmount = fluid:getAmount()
        fluid:removeFluid(fluidToRemove)
        local fluidRemoved = oldFluidAmount - fluid:getAmount()

        syncItem(item)
        return fluidRemoved
    end

    return 0.0
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

    local cleaningLiquid,waterContainerItem,cloth = RustRemover.findSupplies(playerObj)
    if not cleaningLiquid or not waterContainerItem or not cloth then
        print("[RustRemover] rejected: missing/fullness requirement failed")
        return false
    end

    if not RustRemover.isCleaningLiquidNotEmpty(cleaningLiquid)
        or not RustRemover.isWaterBucket(waterContainerItem)
        or not RustRemover.isCleaningCloth(cloth) then
        print("[RustRemover] rejected: supplies changed before completion")
        return false
    end

    local cleaningLiquidRemovedLiter = emptyLiquid(cleaningLiquid, rust)
    if cleaningLiquidRemovedLiter == 0.0 then return false end
    local waterRemovedLiter = emptyLiquid(waterContainerItem, rust)
    if waterRemovedLiter == 0.0 then return false end

    local rustToRemove = waterRemovedLiter / waterContainerItem:getFluidContainer():getCapacity()

    local oldRust = rust
    vehicle:setRust(vehicle:getRust() - rustToRemove)
    if vehicle:getRust() <= RustRemover.FLOAT_EPSILON then vehicle:setRust(0) end
    vehicle:transmitRust()

    print(string.format(
        "[RustRemover] rust removed side=server vehicle=%d oldRust=%.3f newRust=0.000",
        vehicle:getId(), oldRust
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
