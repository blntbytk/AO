------------------- Global variables,colors-----------------------
LatestGameState = {}
InAction = false

colors = {
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  magenta = "\27[35m",
  reset = "\27[0m",
  gray = "\27[90m"
}

----------------- FUNCTIONS ------------------------
---- Function for calculating range of two points , distance 
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

---- Function for decide next actions through  map positions , distance , health , distance , etc.
function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false
  local bestTarget = nil
  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id and inRange(player.x, player.y, state.x, state.y, 1) then
      targetInRange = true
      if not bestTarget or state.health < bestTarget.health or (state.health == bestTarget.health and inRange(player.x, player.y, state.x, state.y, 1) < inRange(player.x, player.y, bestTarget.x, bestTarget.y, 1)) then
        bestTarget = state
      end
    end
  end

  if player.energy > 5 and targetInRange then
    print(colors.red .. "Attacking , target's energy low and in range  ." .. colors.reset)
    ao.send({  
      Target = Game,
      Action = "PlayerAttack",
      Player = ao.id,
      AttackEnergy = tostring(player.energy),
    })
    print(colors.yellow .. "Moving randomly..." .. colors.reset)
 
  
	local directionRandom = {"Up", "Down", "Left", "Right"}
    local randomIndex = math.random(#directionRandom)
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionRandom[randomIndex]})
  end
  InAction = false 
end

------------------ HANDLERS ---------------------
----Handler for announcement
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    if msg.Event == "Started-Waiting-Period" then
      ao.send({Target = ao.id, Action = "AutoPay"})
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true 
      ao.send({Target = Game, Action = "GetGameState"})
    elseif InAction then
      print("Previous action still in progress. Skipping.")
    elseif msg.Event == "Player-Moved:" then print(colors.blue .. msg.Event .. ": " .. msg.Data .. colors.reset)
    end print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
  end
)

---- Handler for game states-------
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
    if not InAction then 
      InAction = true 
      print(colors.gray .. "Getting game state..." .. colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

---- Handler for payment while waiting
Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function (msg)
    print(colors.yellow .. "Auto-paying confirmation fees." .. colors.reset)
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)

---- Handler for warning of state changes.
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Game state updated. Print \'LatestGameState\' for detailed view.")
  end
)

---- Handler for  next action.
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then
      InAction = false
      return
    end
    print(colors.blue .. "Deciding next action." .. colors.reset)
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

---- Handler for attacking one .
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    if not InAction then
      InAction = true
      local playerEnergy = LatestGameState.Players[ao.id].energy
      if playerEnergy == undefined then
        print(colors.magenta .. "couldnt  read energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Couldnt read energy."})
      elseif playerEnergy == 0 then
        print(colors.yellow .. "Player, insufficient energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
      else
        print(colors.red .. "Returning attack." .. colors.reset)
        ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
      end
      InAction = false
      ao.send({Target = ao.id, Action = "Tick"})
    else
      print("Previous action still in progress. Waiting...")
    end
  end
)
