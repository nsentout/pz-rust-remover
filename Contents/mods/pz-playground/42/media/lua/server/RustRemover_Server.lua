require "RustRemover_Shared"

RustRemover_Server = RustRemover_Server or {}

local function syncItem(item)
    if isServer() and sendItemStats and item then sendItemStats(item) end
end

local function isFluidContainer(item)
    return ComponentType and ComponentType.FluidContainer and item.hasComponent and item:hasComponent(ComponentType.FluidContainer)
end

local function getRemovableLiter(fluidContainer, neededLiterForFullClean, rust)
    local removableLiter = 0.
    local neededLiter = rust * neededLiterForFullClean
    if fluidContainer:getAmount() < neededLiter then
        removableLiter = fluidContainer:getAmount()
    else
        removableLiter = neededLiter
    end

    return removableLiter
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
        print("[RustRemover] rejected: missing ingredient")
        return false
    end

    if not isFluidContainer(cleaningFluidContainerItem) or not isFluidContainer(waterContainerItem) then return false end
    local cleangFluidContainer = cleaningFluidContainerItem:getFluidContainer()
    local waterContainer = waterContainerItem:getFluidContainer()

    -- Get amount of fluid that can be emptied from each fluid container to remove a maximum of rust
    local cleaningFluidRemovableLiter = getRemovableLiter(cleangFluidContainer, RustRemover.CLEANING_FLUID_NEEDED_LITER, rust)
    local waterRemovableLiter = getRemovableLiter(waterContainer, RustRemover.WATER_NEEDED_LITER, rust)

    -- For both containers, limit the amount of fluid that can be emptied to the fluid container with the minimum amount of fluid that can be emptied
    local cleaningFluidQtyRemovable = cleaningFluidRemovableLiter / RustRemover.CLEANING_FLUID_NEEDED_LITER
    local waterQtyRemovable = waterRemovableLiter / RustRemover.WATER_NEEDED_LITER

    if cleaningFluidQtyRemovable ~= waterQtyRemovable then
        local qtyRemovable = math.min(cleaningFluidQtyRemovable, waterQtyRemovable)
        cleaningFluidRemovableLiter = math.min(qtyRemovable * RustRemover.CLEANING_FLUID_NEEDED_LITER, cleangFluidContainer:getAmount())
        waterRemovableLiter = math.min(qtyRemovable * RustRemover.WATER_NEEDED_LITER, waterContainer:getAmount())
    end

    local rustRemovableQty = waterRemovableLiter / RustRemover.WATER_NEEDED_LITER

    -- If absorbent is a clean rag, make it dirty
    if absorbentItem:getFullType() == "Base.RippedSheets" then
        playerObj:getInventory():DoRemoveItem(absorbentItem)
        playerObj:getInventory():AddItem("Base.RippedSheetsDirty")
    end

    -- Empty fluid containers
    cleangFluidContainer:removeFluid(cleaningFluidRemovableLiter)
    waterContainer:removeFluid(waterRemovableLiter)
    syncItem(cleangFluidContainer)
    syncItem(waterContainer)

    -- Remove rust
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
