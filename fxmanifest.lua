fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Kassio"
description "Clothing store for vRP2 framework"
version "2.0.0"


shared_scripts {
    "@vrp/lib/utils.lua",
    "@ox_lib/init.lua",
    "config.lua"
}

client_script "source/client.lua"

dependencies {
    "vrp",
    "fivem-appearance",
    "ox_lib"
}
