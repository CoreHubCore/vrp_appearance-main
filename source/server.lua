local Appearance = class("Appearance", vRP.Extension)

function Appearance:__construct()
    vRP.Extension.__construct(self)
    -- Config é carregado como shared_script
    ---@diagnostic disable-next-line: undefined-global
    if cfg then
        ---@diagnostic disable-next-line: undefined-global
        self.cfg = cfg
    else
        self.cfg = {}
        print("^1vrp_appearance: config.lua não foi carregado!^7")
    end
end

Appearance.tunnel = {}
Appearance.event = {}

-- Compra de roupas / salvar aparência
function Appearance.tunnel:buyClothing(storeIndex, clothing)
    local user = vRP.users_by_source[source]
    if not user then return end

    if not self.cfg or not self.cfg[storeIndex] then return end
    local store = self.cfg[storeIndex]

    local price = store.price or 0
    if price > 0 then
        if not user:tryPayment(price) then
            vRP.EXT.Base.remote._notify(user.source, "Você não tem dinheiro suficiente.")
            return
        end
    end

    if clothing and type(clothing) == "table" then
        user:setUData("vRP:clothing", json.encode(clothing))
    end

    vRP.EXT.Base.remote._notify(user.source, ("Você pagou $%d pelas roupas."):format(price))
end

-- Atualizar aparência após mudar
function Appearance.event:updateAppearance(clothing)
    local user = vRP.users_by_source[source]
    if user and clothing and type(clothing) == "table" then
        user:setUData("vRP:clothing", json.encode(clothing))
    end
end

vRP:registerExtension(Appearance)
