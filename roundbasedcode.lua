task.wait(1)

-- SERVICES

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- VARIABLES

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Stand = ReplicatedStorage:WaitForChild("Stand")
local QuestionDatabaseObject = ReplicatedStorage:WaitForChild("QuestionDatabase")
local ObbyFolder = ReplicatedStorage:WaitForChild("Obbies")

local StandsFolder = workspace:WaitForChild("Stands")
local CurrentObbyFolder = workspace:WaitForChild("CurrentObby")

local QuestionModule = require(QuestionDatabaseObject)

-- REMOTE EVENTS

local ClientUICommand = Remotes:WaitForChild("ClientUICommand")
local CameraWork = Remotes:WaitForChild("CameraWork")
local SendToMain = Remotes:WaitForChild("SendToMain")

-- CONSTANTS

local MinimumPlayers = 2
local IntermissionLength = 20
local IsGameDone = false

-- ROUND VARIABLES

local CurrentPlayers = {}
local Answers = {
	
}

-- FUNCTIONS

function Modulo(Num)
	return Num // 2
end 

function Remainder(Num)
	return Num % 2
end

function SelectRandomQuestion()
	local FullDatabase = QuestionModule.Read({"Questions"})

	local TotalNumberOfCategories = 0

	for CategoryName, CategoryContent in FullDatabase do
		TotalNumberOfCategories += 1
	end

	local RandomCategory = math.random(1, TotalNumberOfCategories)

	local SelectedCategoryName = ""
	local Question = ""
	local QuestionData = nil

	local TempRandomCounter = 0
	for CategoryName, CategoryContent in FullDatabase do
		TempRandomCounter += 1

		if TempRandomCounter == RandomCategory then
			SelectedCategoryName = CategoryName

			local NumQuestions = 0

			for QuestionContent, QuestionOptions in CategoryContent do
				NumQuestions += 1
			end

			local RandomQ = math.random(1, NumQuestions)
			local QCounter = 0
			for QuestionContent, QuestionOptions in CategoryContent do
				QCounter += 1

				if QCounter == RandomQ then
					Question = QuestionContent
					QuestionData = QuestionOptions
					break
				end
			end
		end
	end

	return SelectedCategoryName, Question, QuestionData
end

-- MAIN

SendToMain.OnServerEvent:Connect(function(Player, IsCorrect)
	Answers[Player] = IsCorrect
end)

-- CORE LOOP

while true do
	local CurrentNumberOfPlayers = #Players:GetPlayers()
	IsGameDone = false
	
	-- We check here if there are enough players to start the game
	
	if CurrentNumberOfPlayers < MinimumPlayers then
		-- There isn't enough players
		ClientUICommand:FireAllClients("NotEnoughPlayers", MinimumPlayers)
	else
		for Count = IntermissionLength, 0, -1 do
			ClientUICommand:FireAllClients("Intermission", Count)
			task.wait(1)
		end

		ClientUICommand:FireAllClients("Starting")

		-- START ROUND SEQUENCE

		-- Create the stands that the players stand on throughout the round
		-- At this point we also fill out the players who are in the round by adding them to the current players table

		for Num, Player in Players:GetPlayers() do
			table.insert(CurrentPlayers, Player)

			local PlayerStand = Stand:Clone()
			PlayerStand.Parent = StandsFolder
			PlayerStand.Name = Player.Name .. "'s Stand"

			-- Position the stand strategically (by this we have the first 12 stands horizontally positioned about the origin and the other 12 behind)

			local OriginPivotCFrame = PlayerStand:GetPivot()
			local ZOffset = 10 * Modulo(Num)
			local XOffset = 0

			if Remainder(Num) == 1 then
				ZOffset = ZOffset * -1
			end

			if Num > 12 then
				XOffset = 10

				ZOffset = 10 * Modulo(Num - 12)
				if Remainder(Num) == 1 then
					ZOffset = ZOffset * -1
				end
			end

			PlayerStand:PivotTo(OriginPivotCFrame + Vector3.new(XOffset, 0, ZOffset))

			task.wait(0.01)
			
			-- Lock the players in place in their stand

			local Character = Player.Character
			if Character then
				local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
				local Humanoid = Character:FindFirstChild("Humanoid")

				if HumanoidRootPart and Humanoid then
					Humanoid.WalkSpeed = 0
					task.wait(0.01)
					HumanoidRootPart.CFrame = PlayerStand.Teleport.CFrame
				end
			end
		end
		
		-- All of these requests are for UI to be done client side

		task.wait(1)
		
		for _, Player in CurrentPlayers do
			if Player and Players:FindFirstChild(Player.Name) then
				CameraWork:FireClient(Player, "QuestionCam")
			end
		end
		
		task.wait(1)

		for _, Player in CurrentPlayers do
			if Player and Players:FindFirstChild(Player.Name) then
				ClientUICommand:FireClient(Player, "InstructionsScreen")
				ClientUICommand:FireClient(Player, "Started")
			end
		end
		
		task.wait(7.5)
		
		-- This starts the game round sequence

		while not IsGameDone do
			
			-- Select a random question 
			
			local Category, Question, Data = SelectRandomQuestion()
			local TableForm = {Category, Question, Data}
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "QuestionTimeIntermission")
				end
			end

			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "PreviewQuestion", TableForm)
				end
			end

			-- Start round

			task.wait(7)
			
			-- This is a very convoluted piece of code and could possibly be shortened but our goal here is to:
			-- 1) Place the correct option into a random option slot
			-- 2) Fill out the remaining possible options in a random slot, but note that there are a random number (between 3-7) of possible incorrect options which we randomly select and then fill out the remaining optjions with
			-- This is done to increase the replayability, so users cant memorise all the incorrect options
			-- Note that the correct option is always in the number 1 slot
			
			local Options = {
				["Option 1"] = "",
				["Option 2"] = "",
				["Option 3"] = "",
				["Option 4"] = "",
			}

			local CorrectOption = Data["1"]
			local PossibleOptions = {}

			for DataName, DataValue in Data do
				if tonumber(DataName) and DataName ~= "1" then
					-- Inserts every incorrect answer into the possible options table, as the correct answer has name "1"
					table.insert(PossibleOptions, DataValue)
				end
			end
			
			-- We do somehting clever here:
			-- By randomizing instead the fixed order table, we can then just go in order and fill it out which is what we do here
			
			local FixedOrder = {1, 2, 3, 4}
			local SelectionOrder = {}
			-- Randomise the fixed order table and insert this new table in the selection order table
			for Count = 1, 4 do
				local RandomNumber = math.random(1, #FixedOrder)
				local ChosenNum = FixedOrder[RandomNumber]
				
				table.insert(SelectionOrder, ChosenNum)
				table.remove(FixedOrder, RandomNumber)
			end
			
			-- Then the first option in this new random table is where the correct option is placed
			local LocationForCorrectOption = SelectionOrder[1]
			table.remove(SelectionOrder, 1)
			Options["Option " .. tostring(LocationForCorrectOption)] = CorrectOption
			
			for _, Pos in SelectionOrder do
				local RandomNumber = math.random(1, #PossibleOptions)
				local SelectedOption = PossibleOptions[RandomNumber]
				
				-- Choose random option 
				
				Options["Option " .. tostring(Pos)] = SelectedOption
				table.remove(PossibleOptions, RandomNumber)
			end
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "DisplayQuestionBox", TableForm, Options)
				end
			end
			
			-- Gives players 10 second to choose
			
			for Count = 10, 0, -1 do
				for _, Player in CurrentPlayers do
					if Player and Players:FindFirstChild(Player.Name) then
						ClientUICommand:FireClient(Player, "Countdown", Count)
					end
				end
				
				task.wait(1)
			end
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "HideQuestionBox")
				end
			end
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) and not Answers[Player] then
					Answers[Player] = false
				end
			end
			
			local CorrectPlayers = {}
			local IncorrectPlayers = {}
			
			local CorrectText = ""
			local IncorrectText = ""
			
			-- Check the players who are incorrect and add them to the text displayed at the end of each round
			
			for Player, IsCorrect in Answers do
				if Players:FindFirstChild(Player.Name) and Player then
					if IsCorrect then
						table.insert(CorrectPlayers, Player)
						
						if string.len(CorrectText) == 0 then
							CorrectText = Player.Name
						else
							CorrectText = CorrectText .. ", " .. Player.Name
						end
					else
						table.insert(IncorrectPlayers, Player)
						
						if string.len(IncorrectText) == 0 then
							IncorrectText = Player.Name
						else
							IncorrectText = IncorrectText .. ", " .. Player.Name
						end
					end
				end 
			end
			
			if CorrectText ~= "" then
				CorrectText = CorrectText .. " got the answer correct"
			else
				CorrectText = "Nobody got the answer correct"
			end
			
			if IncorrectText ~= "" then
				IncorrectText = IncorrectText .. " got the answer incorrect and will have to complete the obby"
			else
				IncorrectText = "Nobody got the answer incorrect"
			end
			
			-- Simple checks to make sure text doesnt bug out if no incorrect/correct answers
			
			task.wait(1)
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "CorrectPlayers", CorrectText)
				end
			end
			
			task.wait(4)
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "IncorrectPlayers", IncorrectText)
				end
			end
			
			task.wait(4)
			
			-- CONFIGURE OBBIES
			
			-- Select a random obby for those who lost to complete
			
			local CurrentObbies = ObbyFolder:GetChildren()
			
			local RandomObbyNumber = math.random(1, #CurrentObbies)
			local SelectedObby = CurrentObbies[RandomObbyNumber]
			
			local ObbyParticipants = {}
			
			-- UPDATE PLAYER HEALTH LEVELS
			
			for _, Player in IncorrectPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					local IndexedStand = StandsFolder:FindFirstChild(Player.Name .. "'s Stand")
					if IndexedStand then
						local Indicator = IndexedStand.Indicator
					
						if Indicator.Color == Color3.fromRGB(91, 154, 76) then
							Indicator.Color =  Color3.fromRGB(255, 170, 0)
						elseif Indicator.Color == Color3.fromRGB(255, 170, 0) then
							Indicator.Color =  Color3.fromRGB(255, 0, 0)
						elseif Indicator.Color == Color3.fromRGB(255, 0, 0) then
							Indicator.Color =  Color3.fromRGB(0, 0, 0)
							CameraWork:FireClient(Player, "ResetCam")
							
							-- if on last life, kill player
							
							task.delay(1, function()
								local Character = Player.Character
								if Character then
									local Humanoid = Character:FindFirstChild("Humanoid")
									if Humanoid then
										Humanoid:TakeDamage(300)
									end
								end
							end)
						end 
						
						if Indicator.Color == Color3.fromRGB(255, 170, 0) or Indicator.Color == Color3.fromRGB(255, 0, 0) then
							-- Commence obby (evveryone not on their last life that got it incorrect is in the obby table)
							print(Player.Name)
							table.insert(ObbyParticipants, Player)
						end
					end
				end
			end
			
			task.wait(2.5)
			
			-- Check that there are actually people to complete the obby
			
			if #ObbyParticipants > 0 then
				SelectedObby.Parent = CurrentObbyFolder
				local ObbySpawn = SelectedObby:WaitForChild("Spawn")
				local Pad = ObbySpawn:WaitForChild("SpawnPad")
				
				local End = SelectedObby:WaitForChild("End")
				local EndPad = End:WaitForChild("EndPad")

				for _, Player in ObbyParticipants do
					local Character = Player.Character
					if Character then
						local RootPart = Character:FindFirstChild("HumanoidRootPart")
						local Rx = math.random(-4, 4)
						local Rz = math.random(-4, 4)
						RootPart.CFrame = CFrame.new(Pad.Position) + Vector3.new(Rx, 4, Rz)
						
						local Humanoid = Character:WaitForChild("Humanoid")
						if Humanoid then
							Humanoid.WalkSpeed = 16
							Humanoid.Died:Connect(function() OnObbyDeath(Player) end)
						end
						
						CameraWork:FireClient(Player, "ResetCam")
						
						-- Here, we simply teleport every player to the obby pad, to avoid stacking we add a random offset
					end
				end
				
				function OnObbyDeath(DeadPlayer)
					for Index, Player in CurrentPlayers do
						if Player == DeadPlayer then
							print(Player.Name .. " has been removed as they have died")
							table.remove(CurrentPlayers, Index)
							
							local OtherIndex = table.find(ObbyParticipants, Player)

							if OtherIndex then
								table.remove(ObbyParticipants, OtherIndex)
							end
							
							-- To complete when player dies in obby and to remove them from the game
						end
					end
				end
				
				EndPad.Touched:Connect(function(Hit)
					if Hit.Parent:IsA("Model") and Hit.Parent:FindFirstChild("Humanoid") then
						local Character = Hit.Parent
						local RootPart = Character:FindFirstChild("HumanoidRootPart")
						local Humanoid = Character:FindFirstChild("Humanoid")
						
						local Player = Players:GetPlayerFromCharacter(Character)
						local Index = table.find(ObbyParticipants, Player)
						
						-- Find players stand
						
						Humanoid.WalkSpeed = 0
						task.wait(0.01)
						local MyStand = StandsFolder:FindFirstChild(Character.Name .. "'s Stand")
						RootPart.CFrame = MyStand.Teleport.CFrame
						
						-- if player reaches the end, teleport them back to their stand and remove them from the obby table
						
						if Index then
							table.remove(ObbyParticipants, Index)
						end
					end
				end)
				
				for Count = 25, 0, -1 do
					if #ObbyParticipants == 0 then
						break
					end
					
					task.wait(1)
					
					-- Complete obby when time is done
					ClientUICommand:FireAllClients("ObbyComplete", Count)
				end
				
				-- Check if any of the obby participants haven't finished
				
				for Index, Player in ObbyParticipants do
					table.remove(ObbyParticipants, Index)

					local OtherIndex = table.find(CurrentPlayers, Player)
					if OtherIndex then
						table.remove(CurrentPlayers, OtherIndex)
						-- Because some obbies do not have kill parts, we must check the players that havent completed the obbies to have failed aswell
						local Character = Player.Character
						if Character then
							local Humanoid = Character:FindFirstChild("Humanoid")
							if Humanoid then
								Humanoid:TakeDamage(200)
							end
						end
					end
				end
				
				ClientUICommand:FireAllClients("ObbyOver")
			end
			
			task.wait(1)
			
			SelectedObby.Parent = ObbyFolder

			-- REMOVE PLAYERS WHO HAVE LEFT
			
			for X, Player in CurrentPlayers do
				if not Players:FindFirstChild(Player.Name) then
					table.remove(CurrentPlayers, X)
				end
			end
	
			-- COMMENCE NEW ROUND IF APPLICABLE
			
			-- CLEANUP FUNCTION
			
			function RoundCleanup()
				--KILL PLAYERS
				
				for _, Player in Players:GetPlayers() do
					local Character = Player.Character
					if Character then
						local Humanoid = Character:FindFirstChild("Humanoid")
						Humanoid:TakeDamage(1000)
					end
				end
				
				-- REMOVE STANDS
				
				for _, ExistingStand in StandsFolder:GetChildren() do
					ExistingStand:Destroy()
				end
				
				CameraWork:FireAllClients("ResetCam")
			end
			
			local NumPlayersLeft = #CurrentPlayers
			
			if NumPlayersLeft == 0 then
				-- Nobody won
				ClientUICommand:FireAllClients("NoWinner")
				IsGameDone = true
				
				task.wait(4)
				
				RoundCleanup()
			elseif NumPlayersLeft == 1 then
				-- Somebody won
				ClientUICommand:FireAllClients("Winner", CurrentPlayers[1].Name)
				IsGameDone = true
				
				task.wait(4)

				RoundCleanup()
			elseif NumPlayersLeft > 1 then
				-- Begin new round
				ClientUICommand:FireAllClients("NewRound")
				
				for _, Player in CurrentPlayers do
					if Player and Players:FindFirstChild(Player.Name) then
						CameraWork:FireAllClients("QuestionCam")
					end
				end
			end
			--rESET ANSWERS DICTIONARY
			Answers = {
				
			}
			
			task.wait(3)
		end
	end

	task.wait(4)
end

