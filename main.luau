local word = 'Nigger'
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()

local COMAL_COUNTY_PLACE_ID = 12640026687
local isComalCounty = game.PlaceId == COMAL_COUNTY_PLACE_ID

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local SoundService = game:GetService('SoundService')
local LocalPlayer = Players.LocalPlayer

local ACSEngine = ReplicatedStorage:FindFirstChild('ACS_Engine')
local ACSEvents = ACSEngine and ACSEngine:FindFirstChild('Events')
local ServerBulletRemote = ACSEvents and ACSEvents:FindFirstChild('ServerBullet')
local WhizzRemote = ACSEvents and ACSEvents:FindFirstChild('Whizz')
local SuppressionRemote = ACSEvents and ACSEvents:FindFirstChild('Suppression')
local DamageRemote = ACSEvents and ACSEvents:FindFirstChild('Damage')
local BreachRemote = ACSEvents and ACSEvents:FindFirstChild('Breach')
local AcessIdRemote = ACSEvents and ACSEvents:FindFirstChild('AcessId')

local secretkey
if AcessIdRemote then
    local ok, secret = pcall(function()
        return AcessIdRemote:InvokeServer(LocalPlayer.UserId)
    end)
    if ok and secret then
        secretkey = secret .. '-' .. LocalPlayer.UserId
    end
end

local Window = Library:CreateWindow({
    Title = word .. ' County',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Main = Window:AddTab('Main')
local CountyTab = Window:AddTab('Comal County')
local UISettings = Window:AddTab('UI Settings')

local function considerGunModule(module, best)
    if not (module:IsA('ModuleScript') and module.Name == 'ACS_Settings' and module.Parent) then
        return best
    end

    local ok, settings = pcall(require, module)
    if not ok or type(settings) ~= 'table' then
        return best
    end

    local head = settings.HeadDamage
    local damage

    if type(head) == 'table' then
        damage = tonumber(head[2]) or tonumber(head[1])
    elseif type(head) == 'number' then
        damage = head
    end

    if damage and damage > best.damage then
        best.damage = damage
        best.settings = settings
        best.gun = module.Parent
    end

    return best
end

local function pickHighestDamageGun()
    local best = { gun = nil, settings = nil, damage = -math.huge }

    for _, module in ipairs(ReplicatedStorage:GetDescendants()) do
        considerGunModule(module, best)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local backpack = player:FindFirstChildOfClass('Backpack')
        if backpack then
            for _, module in ipairs(backpack:GetDescendants()) do
                considerGunModule(module, best)
            end
        end

        local character = player.Character
        if character then
            for _, module in ipairs(character:GetDescendants()) do
                considerGunModule(module, best)
            end
        end
    end

    return best.gun, best.settings, best.damage
end

local KillGun, KillGunSettings, KillGunDamage
local KillGunMod = { DamageMod = 1, minDamageMod = 1 }
local KillGunConnection
local KillGunLabel

local function killGunLabelText()
    if KillGun and KillGun:IsDescendantOf(game) then
        return ('Using: %s (head %s)'):format(KillGun.Name, tostring(KillGunDamage))
    end
    return 'No ACS gun found.'
end

local function updateKillGunLabel()
    if KillGunLabel then
        KillGunLabel:SetText(killGunLabelText())
    end
end

local function clearKillGun()
    if KillGunConnection then
        KillGunConnection:Disconnect()
        KillGunConnection = nil
    end
    KillGun, KillGunSettings, KillGunDamage = nil, nil, nil
end

local function rescanKillGun()
    clearKillGun()
    KillGun, KillGunSettings, KillGunDamage = pickHighestDamageGun()

    if KillGun then
        KillGunConnection = KillGun.AncestryChanged:Connect(function()
            if not KillGun or not KillGun:IsDescendantOf(game) then
                clearKillGun()
                updateKillGunLabel()
            end
        end)
    end

    updateKillGunLabel()
end

rescanKillGun()

local function KillPlayer(Player)
    if not DamageRemote or not secretkey then
        return
    end

    if not KillGun or not KillGunSettings or not KillGun:IsDescendantOf(game) then
        rescanKillGun()
        if not KillGun then
            return
        end
    end

    local TargetCharacter = Player and Player.Character
    if not TargetCharacter then
        return
    end

    local TargetHumanoid = TargetCharacter:FindFirstChildOfClass('Humanoid')
    if not TargetHumanoid then
        return
    end

    DamageRemote:InvokeServer(
        KillGun,
        TargetHumanoid,
        0,
        1,
        KillGunSettings,
        KillGunMod,
        false,
        0,
        secretkey
    )
end

local BULLET_INTERVAL = 0
local WHIZZ_INTERVAL = 0

local FX = {
    lastBullet = 0,
    lastWhizz = 0,
    whizzIndex = 0,
    connections = {},
}

local KillAllEnabled = false

local function isRemoteEvent(obj)
    return obj and obj:IsA('RemoteEvent')
end

local SUPPORTED_ACS_VERSION = 'ACS 2.0.1 - R6'

local function readACSVersion()
    local gameRules = ACSEngine and ACSEngine:FindFirstChild('GameRules')
    local config = gameRules and gameRules:FindFirstChild('Config')
    if not config then
        return nil
    end

    local ok, result = pcall(require, config)
    if ok and type(result) == 'table' then
        return result.Version
    end
end

local acsVersion = readACSVersion()
local versionSupported = acsVersion == SUPPORTED_ACS_VERSION
local versionText = acsVersion
    and ('ACS Version: %s (%s)'):format(acsVersion, versionSupported and 'Supported' or 'Unsupported')
    or 'ACS Version: unknown (Unsupported)'

local InfoGroup = Main:AddLeftGroupbox('Info')
InfoGroup:AddLabel(versionText)

local KillAllGroup = Main:AddLeftGroupbox('Kill Player')

KillAllGroup:AddToggle('MyToggle', {
    Text = 'Toggle kill all',
    Default = false,
    Tooltip = 'Ignores the dropdown option',
    Callback = function(Value)
        KillAllEnabled = Value
    end,
})

KillAllGroup:AddDropdown('KillPlayerDropdown', {
    SpecialType = 'Player',
    Text = 'Select player(s)',
    Multi = true,
})

KillGunLabel = KillAllGroup:AddLabel(killGunLabelText())

KillAllGroup:AddButton({
    Text = 'Kill',
    Func = function()
        if KillAllEnabled then
            for _, Plr in Players:GetPlayers() do
                if Plr ~= LocalPlayer then
                    KillPlayer(Plr)
                end
            end
        else
            for key, value in Options.KillPlayerDropdown.Value do
                if value == true then
                    KillPlayer(Players:FindFirstChild(key))
                end
            end
        end
    end,
    Tooltip = 'annihilate ' .. string.lower(word),
}):AddButton({
    Text = 'Rescan guns',
    Func = rescanKillGun,
})

local CARJACK_SCAN_INTERVAL = 2

local Carjacking = {
    vehicles = {},
    highlights = {},
}

local CarjackingGroup = Main:AddLeftGroupbox('Carjacking')

CarjackingGroup:AddToggle('Carjack_Highlight', {
    Text = 'Highlight',
    Default = false,
    Tooltip = 'Add a Highlight instance to each detected vehicle.',
})

CarjackingGroup:AddDropdown('Carjack_Target', {
    Values = {},
    Multi = false,
    AllowNull = true,
    Text = 'Vehicle',
})

local function removeCarjackHighlight(model)
    local hl = Carjacking.highlights[model]
    if hl then
        pcall(function()
            hl:Destroy()
        end)
    end
    Carjacking.highlights[model] = nil
end

local function addCarjackHighlight(model)
    if Carjacking.highlights[model] or not model.Parent then
        return
    end

    local hl = Instance.new('Highlight')
    hl.Name = 'CarjackHighlight'
    hl.Adornee = model
    hl.Parent = model
    Carjacking.highlights[model] = hl
end

local function clearAllCarjackHighlights()
    for model in pairs(Carjacking.highlights) do
        removeCarjackHighlight(model)
    end
end

local function scanCarjackVehicles()
    local models = {}
    local seats = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA('VehicleSeat') then
            local model = obj:FindFirstAncestorOfClass('Model')
            if model and not seats[model] then
                seats[model] = obj
                table.insert(models, model)
            end
        end
    end

    table.sort(models, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    local counts = {}
    for _, model in ipairs(models) do
        counts[model.Name] = (counts[model.Name] or 0) + 1
    end

    local labels, map, seen = {}, {}, {}
    for _, model in ipairs(models) do
        local label
        if counts[model.Name] == 1 then
            label = model.Name
        else
            seen[model.Name] = (seen[model.Name] or 0) + 1
            label = ('%s (%d)'):format(model.Name, seen[model.Name])
        end

        table.insert(labels, label)
        map[label] = { model = model, seat = seats[model] }
    end

    local dropdown = Options.Carjack_Target
    local current = dropdown.Value
    dropdown:SetValues(labels)
    dropdown:SetValue(map[current] and current or labels[1])

    Carjacking.vehicles = map

    if Toggles.Carjack_Highlight.Value then
        local wanted = {}

        for _, entry in pairs(map) do
            wanted[entry.model] = true
            addCarjackHighlight(entry.model)
        end

        for model in pairs(Carjacking.highlights) do
            if not wanted[model] then
                removeCarjackHighlight(model)
            end
        end
    end
end

Toggles.Carjack_Highlight:OnChanged(function(enabled)
    if enabled then
        for _, entry in pairs(Carjacking.vehicles) do
            addCarjackHighlight(entry.model)
        end
    else
        clearAllCarjackHighlights()
    end
end)

CarjackingGroup:AddButton('Carjack', function()
    local entry = Carjacking.vehicles[Options.Carjack_Target.Value]
    if not entry then
        Library:Notify('No vehicle selected.')
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass('Humanoid')

    if not humanoid then
        Library:Notify('No humanoid found.')
        return
    end

    if not entry.seat or not entry.seat.Parent then
        Library:Notify('Vehicle is no longer available.')
        return
    end

    pcall(function()
        entry.seat:Sit(humanoid)
    end)
end)

task.spawn(function()
    while not Library.Unloaded do
        scanCarjackVehicles()
        task.wait(CARJACK_SCAN_INTERVAL)
    end
end)

local EffectsGroup = Main:AddRightGroupbox('Bullet + Whizz')

EffectsGroup:AddToggle('FX_BulletEnabled', {
    Text = 'Bullet effect',
    Default = false,
    Tooltip = 'Continually produces a capped bullet effect from a random other player position.',
})

EffectsGroup:AddToggle('FX_WhizzEnabled', {
    Text = 'Whizz sound',
    Default = false,
    Tooltip = 'Enable or disable the whizz sound effect.',
})

EffectsGroup:AddToggle('FX_WhizzEveryone', {
    Text = 'Everyone',
    Default = true,
    Tooltip = 'Whizz plays for every other player; uncheck to choose specific players.',
})

local WhizzTargetsBox = EffectsGroup:AddDependencyBox()

WhizzTargetsBox:AddDropdown('FX_WhizzTargets', {
    SpecialType = 'Player',
    Text = 'Whizz players',
    Multi = true,
    AllowNull = true,
    Tooltip = 'Select multiple players who should hear the whizz sound.',
})

WhizzTargetsBox:SetupDependencies({ { Toggles.FX_WhizzEveryone, false } })

EffectsGroup:AddButton('Ear Ring', function()
    if not isRemoteEvent(SuppressionRemote) then
        Library:Notify('ACS Suppression remote is unavailable.')
        return
    end

    for _ = 1, 100 do
        for _, victim in ipairs(Players:GetPlayers()) do
            SuppressionRemote:FireServer(victim, 2, 999, 999999)
        end
    end
end)

local function getRandomPlayerRoot()
    local roots = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local root = character and character:FindFirstChild('HumanoidRootPart')

            if root and root:IsA('BasePart') and root:IsDescendantOf(workspace) then
                roots[#roots + 1] = root
            end
        end
    end

    if #roots == 0 then
        return nil
    end

    return roots[math.random(1, #roots)]
end

local function sendBulletEffect()
    if not isRemoteEvent(ServerBulletRemote) then
        return
    end

    local root = getRandomPlayerRoot()
    if not root then
        return
    end

    local direction = (root.CFrame * CFrame.Angles(
        math.rad(math.random(-180, 180)),
        math.rad(math.random(-180, 180)),
        math.rad(math.random(-180, 180))
    )).LookVector

    pcall(function()
        ServerBulletRemote:FireServer(
            root.Position,
            direction,
            {
                Tracer = true,
                BulletFlare = true,
                RainbowMode = true,
                BulletDrop = -1,
                WalkMult = 1,
                MuzzleVelocity = 150,
            },
            { WalkMult = 1, MuzzleVelocity = 0.5 }
        )
    end)
end

local function sendNextWhizz()
    if not isRemoteEvent(WhizzRemote) then
        return
    end

    local everyone = Toggles.FX_WhizzEveryone.Value
    local selected = Options.FX_WhizzTargets.Value or {}

    for _, player in ipairs(Players:GetPlayers()) do
        if everyone or selected[player.Name] == true then
            WhizzRemote:FireServer(player)
        end
    end
end

Toggles.FX_BulletEnabled:OnChanged(function(enabled)
    if enabled then
        if not isRemoteEvent(ServerBulletRemote) then
            Library:Notify('ACS ServerBullet remote is unavailable.')
            Toggles.FX_BulletEnabled:SetValue(false)
            return
        end

        FX.lastBullet = os.clock() - BULLET_INTERVAL
    end
end)

Toggles.FX_WhizzEnabled:OnChanged(function(enabled)
    if enabled then
        if not isRemoteEvent(WhizzRemote) then
            Library:Notify('ACS Whizz remote is unavailable.')
            Toggles.FX_WhizzEnabled:SetValue(false)
            return
        end

        FX.whizzIndex = 0
        FX.lastWhizz = os.clock() - WHIZZ_INTERVAL
    end
end)

table.insert(FX.connections, RunService.RenderStepped:Connect(function()
    if Library.Unloaded then
        return
    end

    if Toggles.FX_BulletEnabled.Value then
        sendBulletEffect()
        sendBulletEffect()
    end

    if Toggles.FX_WhizzEnabled.Value then
        sendNextWhizz()
    end
end))

local DestroyMapGroup = Main:AddRightGroupbox('Destroy map')

local function pickBreachDestroyable()
    if math.random() < 0.5 then
        local characters = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                table.insert(characters, p.Character)
            end
        end
        if #characters > 0 then
            return characters[math.random(1, #characters)]
        end
    end

    local models = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA('Model') then
            table.insert(models, obj)
        end
    end
    if #models > 0 then
        return models[math.random(1, #models)]
    end

    return workspace
end

DestroyMapGroup:AddButton('Destroy map', function()
    if not BreachRemote then
        Library:Notify('ACS Breach remote is unavailable.')
        return
    end

    local partSize = { X = 1499, Y = 1499, Z = 1499 }
    local spacing = 1499

    for i = 0, 9 do
        local Position = Vector3.new(0, i * spacing + 0.5, 0)

        pcall(function()
            BreachRemote:InvokeServer(
                3,
                { Fortified = {}, Destroyable = pickBreachDestroyable() },
                CFrame.new(),
                CFrame.new(),
                { CFrame = CFrame.new(Position), Size = partSize }
            )
        end)
    end
end)


local SOUND_GROUPS = {
    Weapons = { 'Fire', 'Echo', 'Magazine', 'Slide', 'Click', 'Safety', 'Handling', 'Any Weapon' },
    Vehicles = { 'Airhorn', 'Wail', 'Yelp', 'Priority', 'Radio' },
}

local REFRESH_INTERVAL = 4
local LAYER_TICK = 0.1

local SB = {
    owner = {},
    originalVolumes = {},
    worldSounds = {},
    connections = {},
    boards = {},
}

local function normalize(name)
    return (name:lower():gsub('[^%w]', ''))
end

local function hasSoundId(sound)
    return sound.SoundId:match('%d+') ~= nil
end

local FIRE_NAMES = {
    fire = true,
    firing = true,
    gunfire = true,
    firesound = true,
    shoot = true,
    shot = true,
    bang = true,
}

local function classifySound(name)
    local n = normalize(name)

    if n:find('echo') then
        return 'Echo'
    end

    if n:find('safety') or n:find('fireselect') or n:find('selector') then
        return 'Safety'
    end

    if
        FIRE_NAMES[n]
        or n:match('^fire%d+$')
        or n:match('^shot%d+$')
        or n:find('gunshot')
        or n:find('muzzleblast')
    then
        return 'Fire'
    end

    if n:find('reload') or n:find('mag') or n:find('pouch') then
        return 'Magazine'
    end

    if n:find('slide') or n:find('bolt') or n:find('rack') then
        return 'Slide'
    end

    if n:find('click') then
        return 'Click'
    end

    if n:find('equip') or n:find('aim') or n:find('charge') or n:find('shell') then
        return 'Handling'
    end

    return nil
end

local function inspectAncestors(sound, character)
    local holstered, score = false, 0
    local node = sound.Parent

    while node and node ~= character do
        local name = node.Name:lower()

        if node:IsA('Tool') then
            score += 100
        end

        if name == 'muzzle' then
            score += 30
        end

        if name == 'fakeg' then
            score -= 70
            holstered = true
        elseif name:match('^belt%d*') or name:match('^vest%d*') then
            holstered = true
        end

        node = node.Parent
    end

    return holstered, score
end

local function holsterPriority(record)
    local n = normalize(record.sound.Name)

    if n == 'slidepull' then
        return 100
    end

    if n == 'sliderelease' then
        return 90
    end

    if record.kind == 'Slide' then
        return 80
    end

    if record.kind == 'Click' then
        return 70
    end

    return 10
end

local function scanPlayer(player, wanted, allowFallback)
    local char = player.Character
    if not char or not char:IsDescendantOf(workspace) then
        return {}
    end

    local matches, holstered = {}, {}

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA('Sound') and hasSoundId(obj) then
            local kind = classifySound(obj.Name)

            if kind then
                local isHolstered, score = inspectAncestors(obj, char)
                local record = { sound = obj, kind = kind, score = score, fallback = false }

                if wanted == 'Any Weapon' or kind == wanted then
                    table.insert(matches, record)
                elseif isHolstered then
                    table.insert(holstered, record)
                end
            end
        end
    end

    if #matches > 0 then
        table.sort(matches, function(a, b)
            if a.score ~= b.score then
                return a.score > b.score
            end
            return a.sound.Name < b.sound.Name
        end)

        return matches
    end

    if allowFallback and #holstered > 0 then
        table.sort(holstered, function(a, b)
            return holsterPriority(a) > holsterPriority(b)
        end)

        holstered[1].fallback = true
        return { holstered[1] }
    end

    return {}
end

local VEHICLE_SUFFIXES = { 'car$', 'truck$', 'vehicle$', 'suv$', 'van$' }

local function findVehicle(sound)
    local node = sound.Parent

    while node and node ~= workspace do
        if node:IsA('Model') then
            if node:FindFirstChildOfClass('VehicleSeat') then
                return node
            end

            local name = node.Name:lower()

            for _, suffix in ipairs(VEHICLE_SUFFIXES) do
                if name:match(suffix) then
                    return node
                end
            end
        end

        node = node.Parent
    end

    return nil
end

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA('Sound') then
        SB.worldSounds[obj] = true
    end
end

table.insert(SB.connections, workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA('Sound') then
        SB.worldSounds[obj] = true
    end
end))

table.insert(SB.connections, workspace.DescendantRemoving:Connect(function(obj)
    SB.worldSounds[obj] = nil
end))

local function scanVehicles(wanted)
    local key = normalize(wanted)
    local found = {}

    for sound in pairs(SB.worldSounds) do
        if normalize(sound.Name) == key and hasSoundId(sound) then
            local vehicle = findVehicle(sound)

            if vehicle then
                table.insert(found, { sound = sound, kind = wanted, vehicle = vehicle, fallback = false })
            end
        end
    end

    table.sort(found, function(a, b)
        return a.sound:GetFullName() < b.sound:GetFullName()
    end)

    return found
end

local function buildEntries(mode, category, allowFallback)
    local entries = {}

    if mode == 'Weapons' then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(entries, {
                    label = player.Name,
                    key = player,
                    records = scanPlayer(player, category, allowFallback),
                })
            end
        end

        table.sort(entries, function(a, b)
            return a.label:lower() < b.label:lower()
        end)
    else
        local byVehicle, nameCount = {}, {}

        for _, record in ipairs(scanVehicles(category)) do
            local vehicle = record.vehicle
            local entry = byVehicle[vehicle]

            if not entry then
                nameCount[vehicle.Name] = (nameCount[vehicle.Name] or 0) + 1
                local n = nameCount[vehicle.Name]

                entry = {
                    label = n == 1 and vehicle.Name or ('%s (%d)'):format(vehicle.Name, n),
                    key = vehicle,
                    records = {},
                }

                byVehicle[vehicle] = entry
                table.insert(entries, entry)
            end

            table.insert(entry.records, record)
        end
    end

    return entries
end

local function playable(sound)
    return sound
        and sound:IsA('Sound')
        and sound:IsDescendantOf(workspace)
        and hasSoundId(sound)
end

local function ownerBoard(sound)
    return SB.owner[sound]
end

local function createSoundboard(tab, fixedMode, prefix, headings)
    local board = {
        mode = fixedMode,
        prefix = prefix,
        layers = {},
        uiTargets = {},
        nextLayerId = 0,
    }

    SB.boards[#SB.boards + 1] = board

    local categories = SOUND_GROUPS[fixedMode]

    local SourceGroup = tab:AddLeftGroupbox(headings.sourceTitle)

    SourceGroup:AddDropdown(prefix .. 'Category', {
        Values = categories,
        Default = 1,
        Multi = false,
        Text = 'Sound',
    })

    SourceGroup:AddDropdown(prefix .. 'Target', {
        Values = {},
        Multi = false,
        AllowNull = true,
        Text = 'Target',
    })

    SourceGroup:AddToggle(prefix .. 'All', {
        Text = 'Target everyone',
        Default = false,
        Tooltip = 'Play from every ' .. headings.subject .. ' instead of the selected one',
    })

    if fixedMode == 'Weapons' then
        SourceGroup:AddToggle(prefix .. 'Fallback', {
            Text = 'Holster fallback',
            Default = true,
            Tooltip = 'If the gun is not equipped, use a sound from the holstered model',
        })
    end

    SourceGroup:AddToggle(prefix .. 'Loop', {
        Text = 'Loop',
        Default = false,
        Tooltip = 'Applies to the next Play: keeps replaying and follows target changes',
    })

    local InfoLabel = SourceGroup:AddLabel('Scanning...', true)

    local PlaybackGroup = tab:AddRightGroupbox(headings.playbackTitle)

    local replicationOk, respectsFiltering = pcall(function()
        return SoundService.RespectFilteringEnabled
    end)

    PlaybackGroup:AddLabel(
        (replicationOk and respectsFiltering == false)
            and 'Others can hear playback (distance still applies).'
            or 'Others hearing playback: unverified.',
        true
    )

    PlaybackGroup:AddSlider(prefix .. 'Volume', {
        Text = 'Local volume',
        Default = 100,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = '%',
        Tooltip = "Only changes what YOU hear. 100% = the sound's normal volume.",
    })

    local StatusLabel

    local function getCategory()
        return Options[prefix .. 'Category'].Value
    end

    local function getTarget()
        return Options[prefix .. 'Target'].Value
    end

    local function getEveryone()
        return Toggles[prefix .. 'All'].Value
    end

    local function getFallback()
        if fixedMode == 'Weapons' then
            return Toggles[prefix .. 'Fallback'].Value
        end
        return false
    end

    local function getLoop()
        return Toggles[prefix .. 'Loop'].Value
    end

    local function setStatus(message)
        StatusLabel:SetText(message)
    end

    local function sameList(a, b)
        if #a ~= #b then
            return false
        end

        for i = 1, #a do
            if a[i] ~= b[i] then
                return false
            end
        end

        return true
    end

    local function applyVolume(sound)
        local factor = Options[prefix .. 'Volume'].Value / 100
        local original = SB.originalVolumes[sound]

        if original == nil then
            if factor == 1 then
                return
            end

            original = sound.Volume
            SB.originalVolumes[sound] = original
        end

        pcall(function()
            sound.Volume = original * factor
        end)
    end

    local function releaseSound(sound)
        local layer = SB.owner[sound]
        if layer then
            layer.sounds[sound] = nil
        end

        local original = SB.originalVolumes[sound]
        SB.owner[sound] = nil
        SB.originalVolumes[sound] = nil

        if sound.Parent then
            pcall(function()
                sound:Stop()

                if original then
                    sound.Volume = original
                end
            end)
        end
    end

    local function claimAndPlay(layer, record)
        local sound = record.sound

        if not playable(sound) or ownerBoard(sound) or sound.IsPlaying then
            return false
        end

        applyVolume(sound)

        local ok = pcall(function()
            sound:Play()
        end)

        if ok then
            SB.owner[sound] = layer
            layer.sounds[sound] = true
        end

        return ok
    end

    local function resolveLayer(layer)
        local records = {}

        for _, entry in ipairs(buildEntries(layer.mode, layer.category, layer.fallback)) do
            if layer.key == nil or entry.key == layer.key then
                for _, record in ipairs(entry.records) do
                    table.insert(records, record)
                end
            end
        end

        layer.records = records
    end

    local function refreshLayerList()
        local ids, names = {}, {}

        for id in pairs(board.layers) do
            table.insert(ids, id)
        end

        table.sort(ids)

        for _, id in ipairs(ids) do
            table.insert(names, board.layers[id].name)
        end

        local dropdown = Options[prefix .. 'Layers']
        local current = dropdown.Value

        dropdown:SetValues(names)
        dropdown:SetValue(table.find(names, current) and current or names[#names])
    end

    local function removeLayer(layer)
        if board.layers[layer.id] ~= layer then
            return
        end

        board.layers[layer.id] = nil

        for sound in pairs(layer.sounds) do
            releaseSound(sound)
        end

        refreshLayerList()
    end

    board.removeLayer = removeLayer

    local function stopAll()
        for _, layer in pairs(board.layers) do
            removeLayer(layer)
        end
    end

    board.stopAll = stopAll

    local function runLayer(layer)
        task.spawn(function()
            local nextResolve = os.clock() + REFRESH_INTERVAL

            while not Library.Unloaded and board.layers[layer.id] == layer do
                if layer.loop then
                    if os.clock() >= nextResolve then
                        resolveLayer(layer)
                        nextResolve = os.clock() + REFRESH_INTERVAL
                    end

                    local wanted = {}

                    for _, record in ipairs(layer.records) do
                        wanted[record.sound] = true

                        if not layer.sounds[record.sound] then
                            claimAndPlay(layer, record)
                        end
                    end

                    for sound in pairs(layer.sounds) do
                        if not wanted[sound] or not playable(sound) then
                            releaseSound(sound)
                        elseif not sound.Looped and not sound.IsPlaying then
                            pcall(function()
                                sound:Play()
                            end)
                        end
                    end
                else
                    local busy = false

                    for sound in pairs(layer.sounds) do
                        if playable(sound) and sound.IsPlaying then
                            busy = true
                        else
                            releaseSound(sound)
                        end
                    end

                    if not busy then
                        removeLayer(layer)
                        break
                    end
                end

                task.wait(LAYER_TICK)
            end
        end)
    end

    local function updateInfo()
        local category = getCategory()
        local text

        if getEveryone() then
            local total, withSounds, sources = 0, 0, 0

            for _, entry in pairs(board.uiTargets) do
                total += 1
                sources += #entry.records

                if #entry.records > 0 then
                    withSounds += 1
                end
            end

            text = ('Everyone | %s\n%d of %d %s have sounds\n%d sound sources'):format(
                category,
                withSounds,
                total,
                headings.plural,
                sources
            )
        else
            local name = getTarget()
            local entry = name and board.uiTargets[name]

            if not entry then
                text = headings.empty
            elseif #entry.records == 0 then
                text = name .. '\nNo matching sounds.'
            elseif entry.records[1].fallback then
                text = name .. '\nHolster fallback: ' .. entry.records[1].sound.Name
            else
                text = ('%s\n%d matching sound(s)'):format(name, #entry.records)
            end
        end

        InfoLabel:SetText(text)
    end

    local function refreshTargets()
        local entries = buildEntries(fixedMode, getCategory(), getFallback())
        local labels, map = {}, {}

        for _, entry in ipairs(entries) do
            table.insert(labels, entry.label)
            map[entry.label] = entry
        end

        board.uiTargets = map

        local dropdown = Options[prefix .. 'Target']

        if not sameList(labels, dropdown.Values) then
            local current = dropdown.Value
            dropdown:SetValues(labels)
            dropdown:SetValue(map[current] and current or labels[1])
        end

        updateInfo()
    end

    local function playSelection()
        local everyone = getEveryone()
        local entry = not everyone and board.uiTargets[getTarget()]

        if not everyone and not entry then
            setStatus('Pick a target first.')
            return
        end

        board.nextLayerId += 1

        local layer = {
            id = board.nextLayerId,
            mode = fixedMode,
            category = getCategory(),
            fallback = getFallback(),
            key = entry and entry.key or nil,
            loop = getLoop(),
            sounds = {},
            records = {},
        }

        layer.name = ('#%d %s > %s%s'):format(
            layer.id,
            layer.category,
            everyone and 'Everyone' or entry.label,
            layer.loop and ' [loop]' or ''
        )

        resolveLayer(layer)

        if #layer.records == 0 then
            setStatus('No playable sounds for this selection.')
            return
        end

        local started, fallbacks = 0, 0

        for _, record in ipairs(layer.records) do
            if claimAndPlay(layer, record) then
                started += 1

                if record.fallback then
                    fallbacks += 1
                end
            end
        end

        if started == 0 and not layer.loop then
            setStatus('Those sounds are already playing.')
            return
        end

        board.layers[layer.id] = layer
        refreshLayerList()
        runLayer(layer)

        setStatus(('Layer #%d: started %d | holster %d | busy %d'):format(
            layer.id,
            started,
            fallbacks,
            #layer.records - started
        ))
    end

    PlaybackGroup:AddButton('Play', playSelection):AddButton('Stop all', function()
        stopAll()
        setStatus('Stopped all layers.')
    end)

    PlaybackGroup:AddDropdown(prefix .. 'Layers', {
        Values = {},
        Multi = false,
        AllowNull = true,
        Text = 'Playing',
    })

    PlaybackGroup:AddButton('Stop selected', function()
        local name = Options[prefix .. 'Layers'].Value

        for _, layer in pairs(board.layers) do
            if layer.name == name then
                removeLayer(layer)
                setStatus('Stopped ' .. name .. '.')
                return
            end
        end

        setStatus('Nothing selected.')
    end):AddButton('Rescan', function()
        refreshTargets()
        setStatus('Sources refreshed.')
    end)

    StatusLabel = PlaybackGroup:AddLabel('Ready.', true)

    Options[prefix .. 'Category']:OnChanged(refreshTargets)
    Options[prefix .. 'Target']:OnChanged(updateInfo)
    Toggles[prefix .. 'All']:OnChanged(updateInfo)

    if fixedMode == 'Weapons' then
        Toggles[prefix .. 'Fallback']:OnChanged(refreshTargets)
    end

    Options[prefix .. 'Volume']:OnChanged(function()
        for sound, layer in pairs(SB.owner) do
            if layer == nil then
                continue
            end
            applyVolume(sound)
        end
    end)

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(REFRESH_INTERVAL)

            if Library.Unloaded then
                break
            end

            refreshTargets()
        end
    end)

    return board
end

if isComalCounty then
    createSoundboard(CountyTab, 'Weapons', 'SB_W_', {
        sourceTitle = 'Weapon Sounds',
        playbackTitle = 'Weapon Playback',
        subject = 'player',
        plural = 'players',
        empty = 'No other players found.',
    })


    local ShopSystem = ReplicatedStorage:FindFirstChild('framework')
        and ReplicatedStorage.framework:FindFirstChild('Systems')
        and ReplicatedStorage.framework.Systems:FindFirstChild('Shop System')

    local ShopAssets = ShopSystem and ShopSystem:FindFirstChild('Assets')
    local ShopRemote = ShopSystem
        and ShopSystem:FindFirstChild('Functions')
        and ShopSystem.Functions:FindFirstChild('shopServer')

    local function getItemsFolder(shopName)
        local shop = ShopAssets and shopName and ShopAssets:FindFirstChild(shopName)
        return shop and shop:FindFirstChild('items')
    end

    local function getShopNames()
        local names = {}

        if ShopAssets then
            for _, shop in ipairs(ShopAssets:GetChildren()) do
                if shop:FindFirstChild('items') then
                    table.insert(names, shop.Name)
                end
            end
            table.sort(names)
        end

        return names
    end

    local function getItemNames(shopName)
        local names = {}
        local items = getItemsFolder(shopName)

        if items then
            for _, item in ipairs(items:GetChildren()) do
                table.insert(names, item.Name)
            end
            table.sort(names)
        end

        return names
    end

    local function getItem(shopName, itemName)
        local items = getItemsFolder(shopName)
        return items and itemName and items:FindFirstChild(itemName)
    end

    local function getPrice(item)
        local config = item and item:FindFirstChild('Config')
        if not config then
            return nil
        end

        local ok, result = pcall(require, config)
        if ok and type(result) == 'table' and type(result.itemConfig) == 'table' then
            return result.itemConfig.price
        end
    end

    local ShopGroup = CountyTab:AddLeftGroupbox('Weapon Shop')

    ShopGroup:AddDropdown('ShopSelect', {
        Values = getShopNames(),
        Default = 1,
        Multi = false,
        Text = 'Store',
    })

    ShopGroup:AddDropdown('WeaponSelect', {
        Values = {},
        Multi = false,
        AllowNull = true,
        Text = 'Weapon',
    })

    local PriceLabel = ShopGroup:AddLabel('Price: -')

    ShopGroup:AddButton('Purchase', function()
        if not ShopRemote then
            Library:Notify('Shop remote is unavailable.')
            return
        end

        local item = getItem(Options.ShopSelect.Value, Options.WeaponSelect.Value)
        if not item then
            Library:Notify('Select a weapon first.')
            return
        end

        local price = getPrice(item)
        if not price then
            Library:Notify('Could not read the price for ' .. item.Name .. '.')
            return
        end

        local ok, result = pcall(function()
            return ShopRemote:InvokeServer(item, price, 'wallet')
        end)

        if ok then
            Library:Notify(('Bought %s for $%s.'):format(item.Name, tostring(price)))
        else
            Library:Notify('Purchase failed: ' .. tostring(result))
        end
    end)

    Options.WeaponSelect:OnChanged(function(itemName)
        local price = getPrice(getItem(Options.ShopSelect.Value, itemName))
        PriceLabel:SetText(price and ('Price: $' .. tostring(price)) or 'Price: -')
    end)

    Options.ShopSelect:OnChanged(function(shopName)
        local items = getItemNames(shopName)
        Options.WeaponSelect:SetValues(items)
        Options.WeaponSelect:SetValue(items[1])
    end)

    local VehicleToolsGroup = CountyTab:AddRightGroupbox('Vehicle Tools')

    VehicleToolsGroup:AddButton('Drain Fuel', function()
        local fired = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == 'GasEvent' and obj:IsA('RemoteEvent') then
                pcall(function()
                    obj:FireServer(math.huge)
                end)
                fired += 1
            end
        end

        Library:Notify(('Drained %d GasEvent(s).'):format(fired))
    end)

    createSoundboard(CountyTab, 'Vehicles', 'SB_V_', {
        sourceTitle = 'Vehicle Sounds',
        playbackTitle = 'Vehicle Playback',
        subject = 'vehicle',
        plural = 'vehicles',
        empty = 'No matching vehicles found.',
    })
else
    CountyTab:AddLeftGroupbox('Comal County only'):AddLabel(
        'These features (Weapon Shop, Weapon Sounds, Vehicle Sounds) only work in Comal County.',
        true
    )
end

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60

local WatermarkConnection = RunService.RenderStepped:Connect(function()
    FrameCounter += 1

    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end

    Library:SetWatermark((word .. ' County | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ))
end)

Library:OnUnload(function()
    WatermarkConnection:Disconnect()

    if KillGunConnection then
        KillGunConnection:Disconnect()
        KillGunConnection = nil
    end

    clearAllCarjackHighlights()

    for _, board in ipairs(SB.boards) do
        board.stopAll()
    end

    for _, connection in ipairs(FX.connections) do
        connection:Disconnect()
    end

    for _, connection in ipairs(SB.connections) do
        connection:Disconnect()
    end

    Library.Unloaded = true
end)

local MenuGroup = UISettings:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function()
    Library:Unload()
end)

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'LeftAlt',
    NoUI = true,
    Text = 'Menu keybind',
})

Library.ToggleKeybind = Options.MenuKeybind
