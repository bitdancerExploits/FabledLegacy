-- ============================================
-- FABLED LEGACY HUB v5.1 (STABILITY & LAST DUNGEON FIX)
-- Rock-Solid Hover Anchor | Universal Boss & Mob Scanner
-- Unlimited Range Scan | Multi-Part Target Tracking
-- Auto Next Room | Auto Claims | Solo Lobby
-- ============================================

-----------------------------------------------
-- UI SELECTION (Vanta / Luna UI Fallback)
-----------------------------------------------
local Vanta
pcall(function()
    Vanta = loadstring(game:HttpGet("https://vanta.my/ui"))()
end)

local Window
if Vanta then
    Window = Vanta:CreateWindow({
        Name = "Fabled Legacy Hub v5.1",
        Subtitle = "Last Dungeon Fix | Onyx",
        Glow = true,
        GlowSpread = 43
    })
else
    print("[FL Hub v5.1] Using standard interface fallback.")
end

-----------------------------------------------
-- SERVICES & LOCAL PLAYER
-----------------------------------------------
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")

local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

plr.CharacterAdded:Connect(function(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
    hum = c:WaitForChild("Humanoid")
    task.wait(0.5)
    if Config and Config.Noclip then enableNoclip() end
end)

-----------------------------------------------
-- LOCATE REMOTES
-----------------------------------------------
local Remotes = {}
local function findRemote(name)
    return RS:FindFirstChild(name, true)
end

Remotes.Swing = findRemote("Swing")
Remotes.useSpell = findRemote("useSpell")
Remotes.NextRoom = findRemote("NextRoom")
Remotes.EquipBest = findRemote("EquipBest")
Remotes.SellJunk = findRemote("SellJunk")
Remotes.UpgradeItem = findRemote("UpgradeItem")
Remotes.M1Success = findRemote("M1Success")
Remotes.StartDungeon = findRemote("StartDungeon")
Remotes.PlaySolo = findRemote("PlaySolo")
Remotes.ToggleHardcore = findRemote("ToggleHardcore")
Remotes.ToggleCalamity = findRemote("ToggleCalamity")

-- Reward Remotes
Remotes.ClaimDaily = findRemote("ClaimDaily")
Remotes.CompleteQuest = findRemote("CompleteQuest")
Remotes.ClaimBattlepass = findRemote("ClaimBattlepass")
Remotes.ClaimPlaytimeReward = findRemote("ClaimPlaytimeReward")
Remotes.ClaimLevelMilestone = findRemote("ClaimLevelMilestone")
Remotes.ClaimAchievement = findRemote("ClaimAchievement")
Remotes.ClaimIndex = findRemote("ClaimIndex")
Remotes.ClaimIndexEnemy = findRemote("ClaimIndexEnemy")
Remotes.ClaimCode = findRemote("ClaimCode")
Remotes.PurchaseSkillNode = findRemote("PurchaseSkillNode")
Remotes.AllocateAttribute = findRemote("AllocateAttribute")

-----------------------------------------------
-- CONFIG STATE
-----------------------------------------------
local Config = {
    AutoFarm = false,
    AttackSpeed = 0.05,
    FarmHeight = 16,
    FarmRange = 10000, -- Expanded range for large multi-stage last dungeon
    AutoSpell = true,
    SpellCooldown = 0.8,
    
    AutoNextRoom = true,
    AutoRequeueDungeon = false,
    AutoPlaySolo = true,
    AutoHardcore = false,
    AutoCalamity = false,
    
    AutoEquipBest = true,
    AutoSellJunk = true,
    AutoUpgradeWeapon = true,
    
    AutoClaimRewards = true,
    AutoBuySkillNodes = false,
    AutoAllocateStats = false,
    StatFocus = "Spell Power",
    
    BossDodge = true,
    DodgeHeightExtra = 20,
    
    Noclip = true,
    SpeedBoost = false,
    SpeedValue = 32,
    JumpBoost = false,
    JumpValue = 100,
    BossESP = true
}

-----------------------------------------------
-- RECURSIVE DEEP SCANNER FOR ALL DUNGEON STAGES & BOSSES
-----------------------------------------------
local function getEnemies()
    local enemies = {}
    local searchedModels = {}

    local function scan(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Model") and child ~= char and not searchedModels[child] then
                searchedModels[child] = true
                local eHum = child:FindFirstChildOfClass("Humanoid")
                local targetPart = child:FindFirstChild("HumanoidRootPart") 
                    or child:FindFirstChild("Head") 
                    or child:FindFirstChild("Torso") 
                    or child:FindFirstChild("LowerTorso")
                    or child:FindFirstChildOfClass("BasePart")

                if targetPart then
                    local isEnemy = false
                    -- If it has humanoid with health > 0
                    if eHum and eHum.Health > 0 then
                        isEnemy = true
                    -- Fallback for last dungeon bosses that don't use standard Humanoid health
                    elseif child:FindFirstChild("Health") or child:FindFirstChild("Stats") or child.Name:lower():find("boss") or child.Name:lower():find("stage") or child.Parent.Name:lower():find("dungeon") then
                        isEnemy = true
                    end

                    if isEnemy then
                        local isBoss = child.Name:lower():find("boss") or (eHum and eHum.MaxHealth > 5000) or child:FindFirstChild("Boss") ~= nil
                        table.insert(enemies, {Model = child, Humanoid = eHum, TargetPart = targetPart, IsBoss = isBoss})
                    end
                end
            end

            -- Recursively check subfolders (e.g. Stage1, Stage2, RoomParts, BossRoom)
            if child:IsA("Folder") or child:IsA("Model") then
                if child ~= char and not child:IsDescendantOf(char) then
                    scan(child)
                end
            end
        end
    end

    -- Priority containers
    local priorityFolders = {
        WS:FindFirstChild("DungeonEnemies"),
        WS:FindFirstChild("Enemies"),
        WS:FindFirstChild("Mobs"),
        WS:FindFirstChild("Dungeon"),
        WS:FindFirstChild("Map")
    }

    for _, folder in ipairs(priorityFolders) do
        if folder then scan(folder) end
    end
    scan(WS) -- Deep fallback scan across entire Workspace

    return enemies
end

local function getClosestEnemy()
    if not hrp or not hrp.Parent then return nil end
    local best, bestDist = nil, Config.FarmRange
    for _, enemy in ipairs(getEnemies()) do
        local dist = (enemy.TargetPart.Position - hrp.Position).Magnitude
        if dist < bestDist then
            bestDist = dist
            best = enemy
        end
    end
    return best
end

-----------------------------------------------
-- ROCK-SOLID HOVER ANCHOR & NOCLIP ENGINE
-----------------------------------------------
local bodyVelocity, bodyGyro

local function ensureAnchor()
    if not hrp then return end
    
    if not bodyVelocity or bodyVelocity.Parent ~= hrp then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = hrp
    end
    
    if not bodyGyro or bodyGyro.Parent ~= hrp then
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        bodyGyro.P = 30000
        bodyGyro.Parent = hrp
    end
end

local function removeAnchor()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
end

local noclipConn = nil
function enableNoclip()
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Stepped:Connect(function()
        if Config.AutoFarm or Config.Noclip then
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end
enableNoclip()

-----------------------------------------------
-- AUTOMATED ATTACK & HOVER LOOP
-----------------------------------------------
local farmRunning = false
local lastSpellCast = 0

local function startFloatFarm()
    if farmRunning then return end
    farmRunning = true

    while Config.AutoFarm do
        pcall(function()
            if not hrp or not hrp.Parent then
                char = plr.Character
                if char then hrp = char:FindFirstChild("HumanoidRootPart") end
                if not hrp then task.wait(1); return end
            end

            local enemy = getClosestEnemy()
            if enemy and enemy.TargetPart then
                ensureAnchor()
                
                local targetPos = enemy.TargetPart.Position
                local currentHeight = Config.FarmHeight

                -- Boss AOE Dodge Check
                if Config.BossDodge and enemy.IsBoss then
                    local castingAOE = enemy.Model:FindFirstChild("Casting") or enemy.Model:FindFirstChild("AOE") or enemy.Model:FindFirstChild("Attacking")
                    if castingAOE then
                        currentHeight = currentHeight + Config.DodgeHeightExtra
                    end
                end

                -- Lock position solidly above target
                local floatPos = targetPos + Vector3.new(0, currentHeight, 0)
                hrp.CFrame = CFrame.new(floatPos, targetPos)
                
                if bodyVelocity then bodyVelocity.Velocity = Vector3.zero end
                if bodyGyro then bodyGyro.CFrame = CFrame.new(floatPos, targetPos) end

                -- Fire attack remotes continuously
                if Remotes.Swing then Remotes.Swing:FireServer() end
                if Remotes.M1Success then 
                    pcall(function() Remotes.M1Success:FireServer(enemy.Model) end)
                    pcall(function() Remotes.M1Success:FireServer(enemy.TargetPart) end)
                end

                if Config.AutoSpell and (tick() - lastSpellCast) > Config.SpellCooldown then
                    if Remotes.useSpell then
                        pcall(function() Remotes.useSpell:FireServer("spell1", enemy.Model) end)
                        pcall(function() Remotes.useSpell:FireServer("spell2", enemy.Model) end)
                        pcall(function() Remotes.useSpell:FireServer("spell3", enemy.Model) end)
                        pcall(function() Remotes.useSpell:FireServer("spell4", enemy.Model) end)
                    end
                    lastSpellCast = tick()
                end
            else
                removeAnchor()
            end
        end)

        task.wait(Config.AttackSpeed)
    end

    removeAnchor()
    farmRunning = false
end

-----------------------------------------------
-- AUTOMATION & DUNGEON STAGE RE-QUEUE
-----------------------------------------------
local function checkDungeonLogic()
    pcall(function()
        local started = WS:FindFirstChild("dungeonStarted")
        local finished = WS:FindFirstChild("dungeonFinished")
        local enemies = getEnemies()

        -- Advanced stage progression check
        if Config.AutoNextRoom then
            if (started and started.Value and #enemies == 0) or (#enemies == 0) then
                if Remotes.NextRoom then Remotes.NextRoom:FireServer() end
            end
        end

        if Config.AutoRequeueDungeon and finished and finished.Value == true then
            if Config.AutoPlaySolo and Remotes.PlaySolo then
                Remotes.PlaySolo:FireServer()
            end
            if Config.AutoHardcore and Remotes.ToggleHardcore then
                Remotes.ToggleHardcore:FireServer()
            end
            if Config.AutoCalamity and Remotes.ToggleCalamity then
                Remotes.ToggleCalamity:FireServer()
            end
            if Remotes.StartDungeon then
                Remotes.StartDungeon:FireServer()
            end
        end
    end)
end

-----------------------------------------------
-- AUTO CLAIMS & REWARDS LOOP
-----------------------------------------------
local lastClaimCheck = 0
local function autoClaimEverything()
    if (tick() - lastClaimCheck) < 5 then return end
    lastClaimCheck = tick()

    pcall(function()
        if not Config.AutoClaimRewards then return end

        if Remotes.ClaimDaily then Remotes.ClaimDaily:FireServer() end
        if Remotes.CompleteQuest then Remotes.CompleteQuest:FireServer() end
        if Remotes.ClaimBattlepass then Remotes.ClaimBattlepass:FireServer() end
        if Remotes.ClaimPlaytimeReward then Remotes.ClaimPlaytimeReward:FireServer() end
        if Remotes.ClaimLevelMilestone then Remotes.ClaimLevelMilestone:FireServer() end
        if Remotes.ClaimAchievement then Remotes.ClaimAchievement:FireServer() end
        if Remotes.ClaimIndex then Remotes.ClaimIndex:FireServer() end
        if Remotes.ClaimIndexEnemy then Remotes.ClaimIndexEnemy:FireServer() end

        if Config.AutoEquipBest and Remotes.EquipBest then Remotes.EquipBest:FireServer() end
        if Config.AutoSellJunk and Remotes.SellJunk then Remotes.SellJunk:FireServer("Common") Remotes.SellJunk:FireServer("Uncommon") end
        if Config.AutoUpgradeWeapon and Remotes.UpgradeItem then Remotes.UpgradeItem:FireServer("Weapon") end

        if Config.AutoBuySkillNodes and Remotes.PurchaseSkillNode then Remotes.PurchaseSkillNode:FireServer("AutoNode") end
        if Config.AutoAllocateStats and Remotes.AllocateAttribute then Remotes.AllocateAttribute:FireServer(Config.StatFocus, 1) end
    end)
end

-----------------------------------------------
-- SPEED & JUMP BOOST LOOP
-----------------------------------------------
RunService.Heartbeat:Connect(function()
    pcall(function()
        if hum and hum.Health > 0 then
            if Config.SpeedBoost then hum.WalkSpeed = Config.SpeedValue end
            if Config.JumpBoost then hum.JumpPower = Config.JumpValue end
        end
    end)
end)

-----------------------------------------------
-- ESP VISUALS
-----------------------------------------------
local espCache = {}
local function clearESP()
    for _, obj in pairs(espCache) do pcall(function() obj:Destroy() end) end
    espCache = {}
end

local function updateESP()
    clearESP()
    if not Config.BossESP then return end

    for _, enemy in ipairs(getEnemies()) do
        local hl = Instance.new("Highlight")
        hl.FillColor = enemy.IsBoss and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 60, 60)
        hl.FillTransparency = 0.5
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.Adornee = enemy.Model
        hl.Parent = enemy.Model
        table.insert(espCache, hl)

        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 140, 0, 50)
        bb.StudsOffset = Vector3.new(0, 4, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = enemy.TargetPart
        bb.Parent = enemy.TargetPart

        local nm = Instance.new("TextLabel", bb)
        nm.Size = UDim2.new(1, 0, 0.5, 0)
        nm.BackgroundTransparency = 1
        nm.Text = (enemy.IsBoss and "[BOSS] " or "") .. enemy.Model.Name
        nm.TextColor3 = enemy.IsBoss and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(255, 100, 100)
        nm.TextSize = 12
        nm.Font = Enum.Font.GothamBold

        local dist = hrp and math.floor((enemy.TargetPart.Position - hrp.Position).Magnitude) or 0
        local dl = Instance.new("TextLabel", bb)
        dl.Size = UDim2.new(1, 0, 0.4, 0)
        dl.Position = UDim2.new(0, 0, 0.5, 0)
        dl.BackgroundTransparency = 1
        dl.Text = dist .. " studs"
        dl.TextColor3 = Color3.fromRGB(200, 200, 255)
        dl.TextSize = 10
        dl.Font = Enum.Font.Gotham

        table.insert(espCache, bb)
    end
end

-----------------------------------------------
-- BACKGROUND LOOPS
-----------------------------------------------
task.spawn(function()
    while task.wait(1) do
        pcall(updateESP)
        pcall(checkDungeonLogic)
        pcall(autoClaimEverything)
    end
end)

task.spawn(function()
    while task.wait(0.3) do
        if Config.AutoFarm and not farmRunning then
            task.spawn(startFloatFarm)
        end
    end
end)

print("[Fabled Legacy Hub v5.1] Last Dungeon Fix Loaded Successfully!")
