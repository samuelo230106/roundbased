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
	return Num // 2 -- Returns the modulus of num
end 

function Remainder(Num)
	return Num % 2 -- Returns the remainder of num
end

function SelectRandomQuestion()
	local FullDatabase = QuestionModule.Read({"Questions"}) -- This reads all the questions from our question database which is a module script
	-- For context the question database is a large dictionary with many nested dictionaries

	local TotalNumberOfCategories = 0 

	for CategoryName, CategoryContent in FullDatabase do
		TotalNumberOfCategories += 1 -- We get the number of categories
	end

	local RandomCategory = math.random(1, TotalNumberOfCategories) -- We can then get a random number from the total number of categories

	local SelectedCategoryName = ""
	local Question = ""
	local QuestionData = nil

	local TempRandomCounter = 0 -- This counter lets us index a random category by number, as we are dealing with dictionaries and dictionaries are unordered, we can fashion our own way to add an order by using a counter
	for CategoryName, CategoryContent in FullDatabase do
		TempRandomCounter += 1 -- Add 1

		if TempRandomCounter == RandomCategory then -- If this number is equal to the number of categories
			SelectedCategoryName = CategoryName -- Change the selected category name

			local NumQuestions = 0 -- Now we repeat the EXACT same thing for the question database, so I will not repeat any comments

			for QuestionContent, QuestionOptions in CategoryContent do
				NumQuestions += 1
			end

			local RandomQ = math.random(1, NumQuestions)
			local QCounter = 0
			for QuestionContent, QuestionOptions in CategoryContent do
				QCounter += 1

				if QCounter == RandomQ then
					Question = QuestionContent -- Change the question, which is the name of the dictionary subsection
					QuestionData = QuestionOptions -- This is a dictionary containing the contents of the question including its difficulty, every option for which the correct option is QuestionData[1]
					break
				end
			end
		end
	end

	return SelectedCategoryName, Question, QuestionData -- Return all 3
end

-- MAIN

SendToMain.OnServerEvent:Connect(function(Player, IsCorrect) -- When a client answers a question it is sent here
	Answers[Player] = IsCorrect -- We append the player object and whether they are correct or not to a dictionary
end)

-- CORE LOOP

while true do
	local CurrentNumberOfPlayers = #Players:GetPlayers() -- Get number of players
	IsGameDone = false -- Set this variable to false at the start of a game indicating that the game is not done
	
	-- We check here if there are enough players to start the game
	
	if CurrentNumberOfPlayers < MinimumPlayers then -- If there are too little players go here
		-- There isn't enough players
		ClientUICommand:FireAllClients("NotEnoughPlayers", MinimumPlayers) -- Change the top bar ui to display the number of players required to start
	else
		for Count = IntermissionLength, 0, -1 do -- Count down the duration of the intermission
			ClientUICommand:FireAllClients("Intermission", Count) -- Every second that goes down, display on top bar
			task.wait(1)
		end

		ClientUICommand:FireAllClients("Starting") -- Top bar ui changes to show game is starting

		-- START ROUND SEQUENCE

		-- Create the stands that the players stand on throughout the round
		-- At this point we also fill out the players who are in the round by adding them to the current players table

		for Num, Player in Players:GetPlayers() do -- Loop through every player in the server
			table.insert(CurrentPlayers, Player) -- Insert every player into a current players table which we will use throughout the loop

			local PlayerStand = Stand:Clone() -- Clone a stand, parent it into the stand folder and give it a name according to the players name
			PlayerStand.Parent = StandsFolder
			PlayerStand.Name = Player.Name .. "'s Stand"

			-- Position the stand strategically (by this we have the first 12 stands horizontally positioned about the origin and the other 12 behind)

			local OriginPivotCFrame = PlayerStand:GetPivot() -- Get the CFrame of the pivot
			local ZOffset = 10 * Modulo(Num) -- The Z (horizontal offset) is given by 10 * the modulo of the players number in the Players table. So this means for every 2 numbers the z offset will increase by 10, this becomes important later
			local XOffset = 0 -- The vertical offset is simpler and will remain at 0 for all players unless there are more than 12 players, in which case we move it back

			if Remainder(Num) == 1 then -- Now we check if the number index of the loop is odd or even, if it is odd we make the z offset negative, this is done to swap the positions of the odd and even numbers
				ZOffset = ZOffset * -1
			end

			if Num > 12 then
				XOffset = 10 -- if more than 12 we move them to the back

				ZOffset = 10 * Modulo(Num - 12) -- We then do the same thing as above but this time moving the num down by 12 so it follows the same pattern for players 1-12 as it does for 13-24
				if Remainder(Num) == 1 then
					ZOffset = ZOffset * -1
				end
			end

			PlayerStand:PivotTo(OriginPivotCFrame + Vector3.new(XOffset, 0, ZOffset)) -- Add the offsets by pivoting

			task.wait(0.01)
			
			-- Lock the players in place in their stand

			local Character = Player.Character -- This is a simple teleport to the stands teleport position
			if Character then
				local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
				local Humanoid = Character:FindFirstChild("Humanoid")

				if HumanoidRootPart and Humanoid then
					Humanoid.WalkSpeed = 0 -- Lock the player in place by making them unable to move
					task.wait(0.01)
					HumanoidRootPart.CFrame = PlayerStand.Teleport.CFrame
				end
			end
		end
		
		-- All of these requests are for UI to be done client side

		task.wait(1)
		
		for _, Player in CurrentPlayers do
			if Player and Players:FindFirstChild(Player.Name) then
				CameraWork:FireClient(Player, "QuestionCam") -- Move every player in the rounds cam to the question part
			end
		end
		
		task.wait(1)

		for _, Player in CurrentPlayers do
			if Player and Players:FindFirstChild(Player.Name) then
				ClientUICommand:FireClient(Player, "InstructionsScreen") -- Play instruction screen for every play
				ClientUICommand:FireClient(Player, "Started") -- Change UI to started
			end
		end
		
		task.wait(7.5)
		
		-- This starts the game round sequence

		while not IsGameDone do -- While game isnt done
			
			-- Select a random question 
			
			local Category, Question, Data = SelectRandomQuestion() -- Here we select a random question using our function
			local TableForm = {Category, Question, Data} -- Put in table form
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "QuestionTimeIntermission") -- Change UI to say question
				end
			end

			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "PreviewQuestion", TableForm) -- Previews question
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
				table.remove(FixedOrder, RandomNumber)  -- This is a fisher-yates table shuffle
			end
			
			-- Then the first option in this new random table is where the correct option is placed
			local LocationForCorrectOption = SelectionOrder[1]
			table.remove(SelectionOrder, 1)
			Options["Option " .. tostring(LocationForCorrectOption)] = CorrectOption
			
			for _, Pos in SelectionOrder do -- For the rest of the order we fill this out with random options
				local RandomNumber = math.random(1, #PossibleOptions)
				local SelectedOption = PossibleOptions[RandomNumber]
				
				-- Choose random option 
				
				Options["Option " .. tostring(Pos)] = SelectedOption -- Fill out the rests of the options
				table.remove(PossibleOptions, RandomNumber)
			end
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "DisplayQuestionBox", TableForm, Options) -- Displays the question box, this time with the options
				end
			end
			
			-- Gives players 10 second to choose
			
			for Count = 10, 0, -1 do -- Countdown
				for _, Player in CurrentPlayers do
					if Player and Players:FindFirstChild(Player.Name) then
						ClientUICommand:FireClient(Player, "Countdown", Count) -- Change the UI each second telling the user how long is elft
					end
				end
				
				task.wait(1)
			end
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "HideQuestionBox") -- Hide question box
				end
			end
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) and not Answers[Player] then
					Answers[Player] = false -- If a player is in the current players but is NOT in the answers dictionary, we make it so that the players answer is false by default for not answering the question
				end
			end
			
			local CorrectPlayers = {} -- Declare tables for correct and incorrect players
			local IncorrectPlayers = {}
			
			local CorrectText = ""
			local IncorrectText = ""
			
			-- Check the players who are incorrect and add them to the text displayed at the end of each round
			
			for Player, IsCorrect in Answers do
				if Players:FindFirstChild(Player.Name) and Player then
					if IsCorrect then
						table.insert(CorrectPlayers, Player) -- If player is correct we add it here
						
						if string.len(CorrectText) == 0 then
							CorrectText = Player.Name -- If it is the first player (string length is 0) then we just add the players name with no comma
						else
							CorrectText = CorrectText .. ", " .. Player.Name -- This is a string of each players name with a comma inbetween
						end
					else
						table.insert(IncorrectPlayers, Player) -- Exact same as above
						
						if string.len(IncorrectText) == 0 then
							IncorrectText = Player.Name
						else
							IncorrectText = IncorrectText .. ", " .. Player.Name
						end
					end
				end 
			end
			
			if CorrectText ~= "" then
				CorrectText = CorrectText .. " got the answer correct" -- At the end of the text we add that they got the answer correct so we can display this in the top bar
			else
				CorrectText = "Nobody got the answer correct" -- If string is empty nobody got it correct
			end
			
			if IncorrectText ~= "" then
				IncorrectText = IncorrectText .. " got the answer incorrect and will have to complete the obby" -- EXact same as above
			else
				IncorrectText = "Nobody got the answer incorrect"
			end
			
			-- Simple checks to make sure text doesnt bug out if no incorrect/correct answers
			
			task.wait(1)
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "CorrectPlayers", CorrectText) -- Show which players got it correct by UI
				end
			end
			
			task.wait(4)
			
			for _, Player in CurrentPlayers do
				if Player and Players:FindFirstChild(Player.Name) then
					ClientUICommand:FireClient(Player, "IncorrectPlayers", IncorrectText) -- Show which players got it incorrect by UI
				end
			end
			
			task.wait(4)
			
			-- CONFIGURE OBBIES
			
			-- Select a random obby for those who lost to complete
			
			local CurrentObbies = ObbyFolder:GetChildren()
			
			local RandomObbyNumber = math.random(1, #CurrentObbies)
			local SelectedObby = CurrentObbies[RandomObbyNumber] -- Select a random obby
			
			local ObbyParticipants = {}
			
			-- UPDATE PLAYER HEALTH LEVELS
			
			for _, Player in IncorrectPlayers do -- We go through every [player that got their question incorrect and make them all lose a life and add them to the obby
				if Player and Players:FindFirstChild(Player.Name) then
					local IndexedStand = StandsFolder:FindFirstChild(Player.Name .. "'s Stand") -- Find each players stand using the name format from above
					if IndexedStand then
						local Indicator = IndexedStand.Indicator -- Get the indicator of teh stand, this is a neon part on the players stand that changes colour depending on how many lives they are on
					
						if Indicator.Color == Color3.fromRGB(91, 154, 76) then
							Indicator.Color =  Color3.fromRGB(255, 170, 0)
						elseif Indicator.Color == Color3.fromRGB(255, 170, 0) then
							Indicator.Color =  Color3.fromRGB(255, 0, 0)
						elseif Indicator.Color == Color3.fromRGB(255, 0, 0) then
							-- This indicates that the player has lost their last life, we change their indicator to black and kill them as well as reset their camera
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
			
			if #ObbyParticipants > 0 then -- If there are obby participant we go thorugh this branch
				SelectedObby.Parent = CurrentObbyFolder -- Parent the obby to the current obby folder
				local ObbySpawn = SelectedObby:WaitForChild("Spawn")
				local Pad = ObbySpawn:WaitForChild("SpawnPad")
				
				local End = SelectedObby:WaitForChild("End")
				local EndPad = End:WaitForChild("EndPad")

				for _, Player in ObbyParticipants do -- For every obby participant we need to teleport them to the obbys start
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
						
						-- Here, we simply teleport every player to the obby pad, to avoid stacking we add a random offset, we give them back their speed, and we connect a died function to each player to indicate when they die
					end
				end
				
				function OnObbyDeath(DeadPlayer)
					for Index, Player in CurrentPlayers do
						if Player == DeadPlayer then -- if player dies and they are in the current players table then:
							print(Player.Name .. " has been removed as they have died")
							table.remove(CurrentPlayers, Index) -- Remove them from the current players table
							
							local OtherIndex = table.find(ObbyParticipants, Player)

							if OtherIndex then
								table.remove(ObbyParticipants, OtherIndex) -- Remove from obby participants table
							end
							
							-- To complete when player dies in obby and to remove them from the game
						end
					end
				end
				
				EndPad.Touched:Connect(function(Hit) -- If the end pad is touched 
					if Hit.Parent:IsA("Model") and Hit.Parent:FindFirstChild("Humanoid") then -- If touched by a player
						local Character = Hit.Parent
						local RootPart = Character:FindFirstChild("HumanoidRootPart")
						local Humanoid = Character:FindFirstChild("Humanoid")
						
						local Player = Players:GetPlayerFromCharacter(Character)
						local Index = table.find(ObbyParticipants, Player) -- Finds position in obby aprticipants table
						
						-- Find players stand
						
						Humanoid.WalkSpeed = 0
						task.wait(0.01)
						local MyStand = StandsFolder:FindFirstChild(Character.Name .. "'s Stand")
						RootPart.CFrame = MyStand.Teleport.CFrame -- Teleport them back to the stand and freeze them
						
						-- if player reaches the end, teleport them back to their stand and remove them from the obby table
						
						if Index then
							table.remove(ObbyParticipants, Index) -- Remove them from obby table
						end
					end
				end)
				
				for Count = 25, 0, -1 do -- Count down the obby
					if #ObbyParticipants == 0 then
						break -- if everyone has either died or completed the obby or a combination of both, end the obby
					end
					
					task.wait(1)
					
					-- Complete obby when time is done
					ClientUICommand:FireAllClients("ObbyComplete", Count) -- Tell everyone obby is done
				end
				
				-- Check if any of the obby participants haven't finished
				
				for Index, Player in ObbyParticipants do -- For eveery remaining obby aprticipant we kill them and remove rom current players
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
				
				ClientUICommand:FireAllClients("ObbyOver") -- Tell everyone by UI obby is over
			end
			
			task.wait(1)
			
			SelectedObby.Parent = ObbyFolder -- Reparent the obby

			-- REMOVE PLAYERS WHO HAVE LEFT
			
			for X, Player in CurrentPlayers do
				if not Players:FindFirstChild(Player.Name) then
					table.remove(CurrentPlayers, X)
				end
			end
	
			-- COMMENCE NEW ROUND IF APPLICABLE
			
			-- CLEANUP FUNCTION
			
			function RoundCleanup() -- Fires if round is over
				--KILL PLAYERS
				
				for _, Player in Players:GetPlayers() do
					local Character = Player.Character
					if Character then
						local Humanoid = Character:FindFirstChild("Humanoid")
						Humanoid:TakeDamage(1000) -- We kill everyone to move them abck to spawn
					end
				end
				
				-- REMOVE STANDS
				
				for _, ExistingStand in StandsFolder:GetChildren() do
					ExistingStand:Destroy() -- Remove all the stnads
				end
				
				CameraWork:FireAllClients("ResetCam") -- Reset everyones camera
			end
			
			local NumPlayersLeft = #CurrentPlayers -- Checks number of players left in the game
			
			if NumPlayersLeft == 0 then -- If 0 nobody won the game
				-- Nobody won
				ClientUICommand:FireAllClients("NoWinner")
				IsGameDone = true
				
				task.wait(4)
				
				RoundCleanup()
			elseif NumPlayersLeft == 1 then -- Somebody must have won the game, so we alert the UI that they won and clean up
				-- Somebody won
				ClientUICommand:FireAllClients("Winner", CurrentPlayers[1].Name)
				IsGameDone = true
				
				task.wait(4)

				RoundCleanup()
			elseif NumPlayersLeft > 1 then -- If nobody has won then continue
				-- Begin new round
				ClientUICommand:FireAllClients("NewRound") -- Tell UI new round is commencing
				
				for _, Player in CurrentPlayers do
					if Player and Players:FindFirstChild(Player.Name) then
						CameraWork:FireAllClients("QuestionCam") -- Change back toq uestion cam
					end
				end
			end
			--rESET ANSWERS DICTIONARY
			Answers = {
				
			}
			-- Cleans answers dictionary
			task.wait(3)
		end
	end

	task.wait(4)
end

