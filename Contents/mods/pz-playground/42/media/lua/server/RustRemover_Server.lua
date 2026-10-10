require "RustRemover_Shared"

RustRemover_Server = RustRemover_Server or {}

local function syncItem(item)
    if isServer() and sendItemStats and item then sendItemStats(item) end
end

local function isFluidContainer(item)
    return ComponentType and ComponentType.FluidContainer and item.hasComponent and item:hasComponent(ComponentType.FluidContainer)
end

function RustRemover_Server.perform(playerObj, args)
    if not playerObj or not args or not args.vehicle then return false end
    local vehicle = getVehicleById(tonumber(args.vehicle))
    if not vehicle then
        print("[RustRemover] rejected: vehicle not found")
        return false
    end

    local rust = vehicle:getRust()
    if not rust or rust <= RustRemover.FLOAT_EPSILON then
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
        or not RustRemover.isAbsorbent(absorbentItem) then
        print("[RustRemover] rejected: supplies changed before completion")
        return false
    end

    if not isFluidContainer(cleaningFluidContainerItem) or not isFluidContainer(waterContainerItem) then return false end
    local cleangFluidContainer = cleaningFluidContainerItem:getFluidContainer()
    local waterContainer = waterContainerItem:getFluidContainer()

    local cleaningFluidRemovableLiter = 0.0
    local cleaningFluidNeededLiter = rust * RustRemover.CLEANING_FLUID_NEEDED_LITER
    if cleangFluidContainer:getAmount() < cleaningFluidNeededLiter then
        cleaningFluidRemovableLiter = cleangFluidContainer:getAmount()
    else
        cleaningFluidRemovableLiter = cleaningFluidNeededLiter
    end

    local waterRemovableLiter = 0.0
    local waterNeededLiter = rust * RustRemover.WATER_NEEDED_LITER
    if waterContainer:getAmount() < waterNeededLiter then
        waterRemovableLiter = waterContainer:getAmount()
    else
        waterRemovableLiter = waterNeededLiter
    end

    local cleaningFluidQtyRemovable = cleaningFluidRemovableLiter / RustRemover.CLEANING_FLUID_NEEDED_LITER
    local waterQtyRemovable = waterRemovableLiter / RustRemover.WATER_NEEDED_LITER

    if cleaningFluidQtyRemovable ~= waterQtyRemovable then
        local qtyRemovable = math.min(cleaningFluidQtyRemovable, waterQtyRemovable)
        cleaningFluidRemovableLiter = math.min(qtyRemovable * RustRemover.CLEANING_FLUID_NEEDED_LITER, cleangFluidContainer:getAmount())
        waterRemovableLiter = math.min(qtyRemovable * RustRemover.WATER_NEEDED_LITER, waterContainer:getAmount())
    end

    local rustRemovableQty = waterRemovableLiter / RustRemover.WATER_NEEDED_LITER


    cleangFluidContainer:removeFluid(cleaningFluidRemovableLiter)
    waterContainer:removeFluid(waterRemovableLiter)
    syncItem(cleangFluidContainer)
    syncItem(waterContainer)

    local oldRust = rust
    vehicle:setRust(vehicle:getRust() - rustRemovableQty)
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
