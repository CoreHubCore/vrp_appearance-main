-- vRP2 client extension
Tunnel = module("vrp", "lib/Tunnel")
Proxy = module("vrp", "lib/Proxy")

local cvRP = module("vrp", "client/vRP")
vRP = cvRP()
if not vRP then
    print("^1vrp_appearance: Falha ao carregar vRP client^7")
    return
end

local Appearance = class("Appearance", vRP.Extension)
local fivemAppearance = exports["fivem-appearance"]

local wardrobeId = "vRP2:wardrobe"
local wardrobeSelectedId = wardrobeId.."_selected"
local wardrobe = json.decode(GetResourceKvpString(wardrobeId)) or {}
local currentOpenWardrobe

local function inputOutfitName()
    local input = lib.inputDialog("Salvar roupa atual", {"Nome da roupa:"})
    local name = input and input[1]
    if name and name ~= "" then return name end
end

local function saveWardrobe(name)
    if not name then return end
    -- Salvar aparência localmente e notificar servidor (usa fivem-appearance)
    local ped = cache.ped or PlayerPedId()
    local pedAppearance = nil
    if fivemAppearance and fivemAppearance.getPedAppearance then
        pedAppearance = fivemAppearance:getPedAppearance(ped)
    end
    wardrobe[#wardrobe+1] = { name = name, appearance = pedAppearance or {} }
    SetResourceKvp(wardrobeId, json.encode(wardrobe))
    -- enviar para o servidor (pode salvar no cdata)
    TriggerServerEvent("vRP2:saveOutfit", name, pedAppearance)
    lib.notify({ title = "Guarda-roupa", description = "Roupa salva com sucesso!", type = "success" })
end

local function getWardrobe()
    local options = {
        {
            title = "Salvar roupa atual",
            icon = "fa-solid fa-floppy-disk",
            onSelect = function() saveWardrobe(inputOutfitName()) end
        }
    }
    for i, info in ipairs(wardrobe) do
        options[#options+1] = {
            title = info.name,
            arrow = true,
            onSelect = function() currentOpenWardrobe = i; lib.showContext(wardrobeSelectedId) end
        }
    end
    return options
end

local function openWardrobe(menu)
    lib.registerContext({
        id = wardrobeId,
        menu = menu,
        title = "Guarda-roupa",
        options = getWardrobe()
    })
    lib.showContext(wardrobeId)
end

local function startChange(coords, options, storeIndex)
    local ped = cache.ped
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 1.0, true, false, false, false)
    SetEntityHeading(ped, coords.w)
    Wait(250)
    -- Abrir customizador do fivem-appearance (se disponível)
    if fivemAppearance and fivemAppearance.startPlayerCustomization then
        fivemAppearance:startPlayerCustomization(function(result)
            if not result then return end
            ped = PlayerPedId()
            local clothing = nil
            if fivemAppearance and fivemAppearance.getPedAppearance then
                clothing = fivemAppearance:getPedAppearance(ped)
            end
            TriggerServerEvent("vRP2:buyClothing", storeIndex, clothing)
        end, options)
    else
        -- fallback: notify server that player entered the shop
        TriggerServerEvent("vRP2:enterAppearanceShop", storeIndex)
        lib.notify({ title = "Loja de Roupas", description = "Você entrou na loja. Converse com o vendedor.", type = "info" })
    end
end

function Appearance:__construct()
    vRP.Extension.__construct(self)
    -- Config é carregado como shared_script
    ---@diagnostic disable-next-line: undefined-global
    if cfg then
        ---@diagnostic disable-next-line: undefined-global
        self.cfg = cfg
        self:createStores()
    else
        print("^1vrp_appearance: config.lua não foi carregado!^7")
    end
end

function Appearance:createStores()
    if not self.cfg or #self.cfg == 0 then return end
    for i, info in ipairs(self.cfg) do
        if info.locations then
            for _, location in ipairs(info.locations) do
                -- Carregar modelo antes de criar o PED
                local modelHash = joaat(location.model)
                RequestModel(modelHash)
                local timeout = 0
                while not HasModelLoaded(modelHash) and timeout < 10000 do
                    Wait(100)
                    timeout = timeout + 100
                end
                
                if not HasModelLoaded(modelHash) then
                    print("^1vrp_appearance: Falha ao carregar modelo " .. location.model .. "^7")
                    goto continue
                end
                
                local ped = CreatePed(4, modelHash, location.worker.x, location.worker.y, location.worker.z, location.worker.w, false, true)
                if not ped or ped == 0 then
                    print("^1vrp_appearance: Falha ao criar PED para " .. location.model .. "^7")
                    goto continue
                end
                
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetModelAsNoLongerNeeded(modelHash)

                exports.ox_target:addLocalEntity(ped, {
                    {
                        name = "appearance_shop_"..i,
                        icon = "fa-solid fa-shirt",
                        label = info.text or "Loja de Roupas",
                        distance = 2.0,
                        onSelect = function()
                            startChange(location.change, info.appearance, i)
                        end
                    },
                    {
                        name = "appearance_wardrobe_"..i,
                        icon = "fa-solid fa-vest",
                        label = "Abrir guarda-roupa",
                        distance = 2.0,
                        onSelect = function()
                            openWardrobe()
                        end
                    }
                })
                
                ::continue::
            end
        end
    end
end

-- Menu secundário de roupas salvas
lib.registerContext({
    id = wardrobeSelectedId,
    title = "Roupas salvas",
    menu = wardrobeId,
    options = {
        {
            title = "Vestir",
            icon = "fa-solid fa-shirt",
            onSelect = function()
                local selected = wardrobe[currentOpenWardrobe]
                if not selected then return end
                if selected.appearance and next(selected.appearance or {}) then
                    -- aplicar aparência localmente via fivem-appearance (se disponível)
                    if fivemAppearance and fivemAppearance.setPedAppearance then
                        fivemAppearance:setPedAppearance(cache.ped or PlayerPedId(), selected.appearance)
                    end
                    -- notificar servidor para atualizar (opcional)
                    TriggerServerEvent("vRP2:updateAppearance", selected.appearance)
                    lib.notify({ title = "Roupas", description = "Aparência aplicada.", type = "success" })
                else
                    lib.notify({ title = "Info", description = "Roupa vazia, salve uma roupa primeiro", type = "info" })
                end
            end
        },
        {
            title = "Editar nome",
            icon = "fa-solid fa-pen-to-square",
            onSelect = function()
                local selected = wardrobe[currentOpenWardrobe]
                if not selected then return end
                local name = inputOutfitName()
                if not name then return end
                selected.name = name
            end
        },
        {
            title = "Remover",
            icon = "fa-solid fa-trash-can",
            onSelect = function()
                local selected = wardrobe[currentOpenWardrobe]
                if not selected then return end
                local alert = lib.alertDialog({
                    header = "Remover roupa?",
                    content = ("Tem certeza que deseja remover %s?"):format(selected.name),
                    centered = true,
                    cancel = true
                })
                if alert ~= "confirm" then return end
                table.remove(wardrobe, currentOpenWardrobe)
                SetResourceKvp(wardrobeId, json.encode(wardrobe))
            end
        }
    }
})

AddEventHandler("onResourceStop", function(resource)
    if resource ~= cache.resource then return end
    SetResourceKvp(wardrobeId, json.encode(wardrobe))
end)

vRP:registerExtension(Appearance)
