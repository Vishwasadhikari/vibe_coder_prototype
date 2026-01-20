class LuaGenerator {
  String generateFromPrompt(String prompt) {
    final p = prompt.trim();
    if (p.isEmpty) {
      return 'error("Please enter a game description")';
    }

    final lower = p.toLowerCase();

    if (lower.contains('zombie') ||
        (lower.contains('chase') &&
            (lower.contains('npc') || lower.contains('enemy')))) {
      return _zombieChaseTemplate(p);
    }

    if (lower.contains('door') &&
        (lower.contains('touch') ||
            lower.contains('open') ||
            lower.contains('proximity'))) {
      return _doorOnTouchTemplate(p);
    }

    if ((lower.contains('spin') || lower.contains('rotate')) &&
        (lower.contains('block') ||
            lower.contains('part') ||
            lower.contains('cube') ||
            lower.contains('touched') ||
            lower.contains('touch'))) {
      return _spinningBlockTemplate(p);
    }

    if (lower.contains('leaderboard') || lower.contains('leaderstats')) {
      return _leaderstatsTemplate(p);
    }

    if (lower.contains('coin') || lower.contains('collect')) {
      return _coinCollectorTemplate(p);
    }

    return _genericTemplate(p);
  }

  String _zombieChaseTemplate(String prompt) {
    return '''-- Generated Roblox Lua
-- Prompt: ${_escapeLuaComment(prompt)}

-- Simple "zombie chases player" loop.
-- Setup:
-- 1) Put an NPC Model named "Zombie" in Workspace.
-- 2) The model should have a Humanoid + HumanoidRootPart.
-- 3) This script makes the zombie path toward the nearest player.
-- 4) If the zombie touches a player's character, it damages/kills them.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local zombie = workspace:WaitForChild("Zombie")
local humanoid = zombie:WaitForChild("Humanoid")
local root = zombie:WaitForChild("HumanoidRootPart")

local ATTACK_DAMAGE = 100
local ATTACK_COOLDOWN = 1.0
local chaseTick = 0
local lastAttackAt = 0

local function getNearestCharacter()
  local nearestCharacter = nil
  local nearestDist = math.huge

  for _, player in ipairs(Players:GetPlayers()) do
    local character = player.Character
    if character and character.Parent then
      local hrp = character:FindFirstChild("HumanoidRootPart")
      local hum = character:FindFirstChildOfClass("Humanoid")
      if hrp and hum and hum.Health > 0 then
        local dist = (hrp.Position - root.Position).Magnitude
        if dist < nearestDist then
          nearestDist = dist
          nearestCharacter = character
        end
      end
    end
  end

  return nearestCharacter, nearestDist
end

local function followPathTo(position)
  local path = PathfindingService:CreatePath({
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
  })

  path:ComputeAsync(root.Position, position)
  if path.Status ~= Enum.PathStatus.Success then
    humanoid:MoveTo(position)
    return
  end

  for _, waypoint in ipairs(path:GetWaypoints()) do
    humanoid:MoveTo(waypoint.Position)
    if waypoint.Action == Enum.PathWaypointAction.Jump then
      humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    local reached = humanoid.MoveToFinished:Wait()
    if not reached then
      break
    end
  end
end

root.Touched:Connect(function(hit)
  local character = hit.Parent
  if not character then return end

  local hum = character:FindFirstChildOfClass("Humanoid")
  if not hum then return end

  local now = os.clock()
  if now - lastAttackAt < ATTACK_COOLDOWN then return end
  lastAttackAt = now

  hum:TakeDamage(ATTACK_DAMAGE)
end)

RunService.Heartbeat:Connect(function(dt)
  chaseTick += dt
  if chaseTick < 0.4 then return end
  chaseTick = 0

  local character = getNearestCharacter()
  if not character then return end
  local hrp = character:FindFirstChild("HumanoidRootPart")
  if not hrp then return end

  followPathTo(hrp.Position)
end)
''';
  }

  String _doorOnTouchTemplate(String prompt) {
    return '''-- Generated Roblox Lua
-- Prompt: ${_escapeLuaComment(prompt)}

-- Setup:
-- 1) Create a Part named "Door" in Workspace.
-- 2) (Optional) Create a Part named "TouchPad" in Workspace.
-- If TouchPad doesn't exist, the door itself is used as the trigger.

local TweenService = game:GetService("TweenService")

local door = workspace:WaitForChild("Door")
local trigger = workspace:FindFirstChild("TouchPad") or door

local isOpen = false
local originalCFrame = door.CFrame
local openCFrame = originalCFrame * CFrame.new(0, door.Size.Y + 0.2, 0)

local function setDoor(open)
  if open == isOpen then return end
  isOpen = open

  local goal = {}
  goal.CFrame = open and openCFrame or originalCFrame

  local tween = TweenService:Create(
    door,
    TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    goal
  )
  tween:Play()
end

trigger.Touched:Connect(function(hit)
  local character = hit.Parent
  if not character then return end
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if not humanoid then return end

  setDoor(true)
  task.delay(2.0, function()
    setDoor(false)
  end)
end)
''';
  }

  String _spinningBlockTemplate(String prompt) {
    return '''-- Generated Roblox Lua
-- Prompt: ${_escapeLuaComment(prompt)}

-- Setup:
-- Create a Part named "SpinBlock" in Workspace.

local RunService = game:GetService("RunService")

local block = workspace:WaitForChild("SpinBlock")

local spinning = false
local speed = math.rad(180) -- degrees/sec

block.Touched:Connect(function(hit)
  local character = hit.Parent
  if not character then return end
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if not humanoid then return end
  spinning = true
  task.delay(2.0, function()
    spinning = false
  end)
end)

RunService.Heartbeat:Connect(function(dt)
  if not spinning then return end
  block.CFrame = block.CFrame * CFrame.Angles(0, speed * dt, 0)
end)
''';
  }

  String _leaderstatsTemplate(String prompt) {
    return '''-- Generated Roblox Lua
-- Prompt: ${_escapeLuaComment(prompt)}

-- Creates a simple leaderboard (leaderstats) with Coins.

local Players = game:GetService("Players")

local function onPlayerAdded(player)
  local leaderstats = Instance.new("Folder")
  leaderstats.Name = "leaderstats"
  leaderstats.Parent = player

  local coins = Instance.new("IntValue")
  coins.Name = "Coins"
  coins.Value = 0
  coins.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)
''';
  }

  String _coinCollectorTemplate(String prompt) {
    return '''-- Generated Roblox Lua
-- Prompt: ${_escapeLuaComment(prompt)}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoinFolder = Instance.new("Folder")
CoinFolder.Name = "Coins"
CoinFolder.Parent = ReplicatedStorage

local CoinTemplate = Instance.new("Part")
CoinTemplate.Name = "Coin"
CoinTemplate.Anchored = true
CoinTemplate.CanCollide = false
CoinTemplate.Transparency = 0.5
CoinTemplate.BrickColor = BrickColor.new("Gold")
CoinTemplate.Shape = Enum.PartType.Ball
CoinTemplate.Size = Vector3.new(0.5, 0.5, 0.5)

local function createCoin(position)
  local coin = CoinTemplate:Clone()
  coin.Parent = CoinFolder
  coin.Position = position
  return coin
end

local function ensureLeaderstats(player)
  local leaderstats = player:FindFirstChild("leaderstats")
  if not leaderstats then
    leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
  end

  local coins = leaderstats:FindFirstChild("Coins")
  if not coins then
    coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = 0
    coins.Parent = leaderstats
  end

  return coins
end

local function collectCoin(player, coin)
  local coinsValue = ensureLeaderstats(player)
  coinsValue.Value += 1
  coin:Destroy()
end

local function onCoinTouched(coin, hit)
  local character = hit.Parent
  if not character then return end

  local player = Players:GetPlayerFromCharacter(character)
  if not player then return end

  collectCoin(player, coin)
end

local function spawnCoins()
  for i = 1, 20 do
    local x = math.random(-40, 40)
    local z = math.random(-40, 40)
    local coin = createCoin(Vector3.new(x, 3, z))
    coin.Touched:Connect(function(hit)
      onCoinTouched(coin, hit)
    end)
  end
end

spawnCoins()

-- Optional: respawn coins when all collected
RunService.Heartbeat:Connect(function()
  if #CoinFolder:GetChildren() == 0 then
    spawnCoins()
  end
end)
''';
  }

  String _genericTemplate(String prompt) {
    return '''-- Generated Roblox Lua
-- Prompt: ${_escapeLuaComment(prompt)}

-- This is a starter game script scaffold derived from your prompt.
-- Next steps:
-- 1) Decide: is it an NPC game, coin collection, obby, shooter, etc.
-- 2) Create the required Parts/Models in Workspace (names referenced below).
-- 3) Fill in TODO sections.

local Players = game:GetService("Players")

-- TODO: rename these to match your game objects in Workspace
local MainPartName = "MainPart" -- e.g. "Door", "SpinBlock", "StartZone"

local function onPlayerAdded(player)
  print("Player joined:", player.Name)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- TODO: implement the main loop / events based on prompt
-- Prompt summary: ${_escapeLuaComment(prompt)}

print("Game script loaded")
''';
  }

  String _escapeLuaComment(String input) {
    return input.replaceAll('\n', ' ').replaceAll('\r', ' ');
  }
}
