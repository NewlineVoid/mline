local plugin = plugin
local Selection = game:GetService("Selection")
local ScriptEditorService = game:GetService("ScriptEditorService")

local toolbar = plugin:CreateToolbar("mline")
local pluginButton = toolbar:CreateButton(
	"Placeholder (MLine)",
	"Work in progress | We'll see you soon",
	"rbxassetid://104329129506170"
)

local macroGroups = {
	new = {
		description = "Creates an Instance and assigns properties using |key:value syntax",
		examples = {
			'new:Part|Name:"MlineTest"|Parent:workspace|Color:Color3.fromHex("141414")=mlineInstance'
		},
		callback = function(mainArg, props, var)
			local lines = {}
			local varName = var or "_inst"
			table.insert(lines, `local {varName} = Instance.new("{mainArg}")`)
			for _, prop in ipairs(props) do
				local k, v = prop[1], prop[2]
				table.insert(lines, `{varName}.{k} = {v}`)
			end
			return table.concat(lines, "\n")
		end
	},

	gs = {
		description = "Gets a service via game:GetService(); Can be routed to a variable via gs:service=variableName",
		examples = {
			"gs:rs",
			"gs:https=https"
		},
		callback = function(mainArg, _, var)
			local services = {
				["rs"]   = "RunService",
				["ts"]   = "TweenService",
				["uis"]  = "UserInputService",
				["cas"]  = "ContextActionService",
				["plrs"] = "Players",
				["https"]= "HttpService",
				["ms"]   = "MarketplaceService"
			}
			local call = services[mainArg] and `game:GetService("{services[mainArg]}")` or `game:GetService("{mainArg}")`
			if var and var ~= "" then
				return `local {var} = {call}`
			end
			return call
		end
	},

	itr = {
		description = "A generic i / iteration loop.",
		examples = {
			"itr:5=i",
			"itr:50|start:5|step:5=i"
		},
		callback = function(mainArg, props, var)
			local iVar = var or "i"
			local start, stop, step = "1", mainArg, "1"
			for _, pair in ipairs(props) do
				if pair[1] == "start" then start = pair[2] end
				if pair[1] == "step" then step = pair[2] end
			end
			return `for {iVar} = {start}, {stop}, {step} do\n\t\nend`
		end
	},

	forin = {
		description = "A generic for-in loop.",
		examples = {
			"forin:randomObject"
		},
		callback = function(mainArg, props, _) -- <-- props dont work, dont know why, and im too lazy.
			local varString = ""
			local isFirst = true
			for entry in props do
				local i = entry[1];
				local v = entry[2];
				
				if isFirst then varString ..= `{i}:{v}`;isFirst=false else varString ..= `, {i}:{v}` end
			end
			if varString == "" then varString = "i,v" end;
			return `for {varString} in {mainArg} do\n\t\nend`
		end
	},

	foreach = {
		description = "A generic for each loop utilizing pairs.",
		examples = {
			"foreach:randomObject",
			"foreach:randomObject|key:id|value:object"
		},
		callback = function(mainArg, props, var)
			local kVar, vVar = "k", "v"
			for _, p in ipairs(props) do
				if p[1] == "key" then kVar = p[2] end
				if p[1] == "value" then vVar = p[2] end
			end
			return `for {kVar}, {vVar} in pairs({mainArg}) do\n\t\nend`
		end
	},

	rq = {
		description = "requires the given module; Can be routed to a variable via rq:path.to.module=variableName ",
		examples = {
			"rq:game.ReplicatedStorage:FindFirstChild('Module')",
			"rq:game.ReplicatedStorage:FindFirstChild('Module')=module"
		},
		callback = function(mainArg, _, var)
			if var and var ~= "" then
				return `local {var} = require({mainArg})`
			end
			return `require({mainArg})`
		end
	},

	on = {
		description = "generic event connector.",
		examples = {
			"on:part.Touched|callback:touchedFunction",
			"on:part.Touched|partTouching:Part"
		},
		callback = function(mainArg, props, _)
			local callbackFunc = nil
			local hooks = {}
			for _, pair in ipairs(props) do
				local key, value = pair[1], pair[2]
				if key == "callback" then
					callbackFunc = value
				else
					hooks[key] = value
				end
			end
			local hooksString = ""
			local isFirst = true
			for param, ptype in pairs(hooks) do
				local typed = `{param}:{ptype}`
				if isFirst then
					hooksString = typed
					isFirst = false
				else
					hooksString ..= `, {typed}`
				end
			end
			if callbackFunc then
				return `{mainArg}:Connect({callbackFunc}({hooksString}))`
			else
				return `{mainArg}:Connect(function({hooksString})\n\t\nend)`
			end
		end
	},


	tagged = {
		description = "retrieve tags via collection service",
		examples = {
			"tagged:enemy=enemies"
		},
		callback = function(mainArg, _, var)
			local varName = var or "objects"
			return `local {varName} = game:GetService("CollectionService"):GetTagged("{mainArg}")`
		end
	},

	fn = {
		description = "local function declaration",
		examples = {
			"fn:functionName|param1:string|param2:number"
		},
		callback = function(mainArg, props, _)
			local hooks = {}
			for _, pair in ipairs(props) do
				local key, value = pair[1], pair[2]
				hooks[key] = value
			end
			local paramString = ""
			local isFirst = true
			for param, ptype in pairs(hooks) do
				local typed = `{param}:{ptype}`
				if isFirst then
					paramString = typed
					isFirst = false
				else
					paramString ..= `, {typed}`
				end
			end
			return `local function {mainArg}({paramString})\n\t\nend`
		end
	},

	iferr = {
		description = "try catch via pcall",
		examples = {
			'iferr:error("a random error")'
		},
		callback = function(mainArg, _, _)
			return `local success, err = pcall(function()\n\treturn {mainArg}\nend)\nif not success then\n\twarn(err)\nend`
		end
	}
}
macroGroups["debugmline"] = {
	description = "mline debugging utility used to prepare a script with all macro examples. if true, will also show the macro's code.",
	examples = {
		"debugmline:false",
		"debugmline:true"
	},
	callback = function(mainArg,_,_)
		local returnScript = "";

		for macro, macroInfo in pairs(macroGroups) do
			returnScript ..= `-- [[{macro}]] => {macroInfo.description} \n`
      if mainArg == "true" then
				local cb = macroInfo.callback
				if type(cb) == "function" then
					local memoryAddress = tostring(cb)
					returnScript ..= `--   [Callback] = exists ({memoryAddress})\n`
				else
					returnScript ..= "--   [Callback] = Does not exist or is invalid\n"
				end
			end
			for _, example in ipairs(macroInfo.examples) do
				returnScript ..= `{example}\n`
			end
			returnScript ..= "\n\n"
		end
		return returnScript
	end,
}

function parseMacro(line: string): (string | nil)
	local left, var = line:match("^([^=]+)=?(%w*)$")
	if not left then return nil end

	local segments = left:split("|")
	if #segments < 1 then return nil end

	local group, mainArg = segments[1]:match("^(%w+):(.+)$")
	if not group or not mainArg then return nil end

	local props = {}
	for i = 2, #segments do
		local key, value = segments[i]:match("^(.-):(.+)$")
		if key and value then
			table.insert(props, { key, value })
		end
	end

	local handler = macroGroups[group]
	if handler then
		local ok, result = pcall(handler, mainArg, props, var)
		if ok then return result end
	end
	return nil
end

local function GetWordFromTypedText(currentLine: string, cursorPos: number): string
	local i = cursorPos
	local inQuote = nil
	local wordChars = {}

	while i > 0 do
		local char = currentLine:sub(i, i)

		if char == '"' or char == "'" then
			if inQuote == nil then
				inQuote = char
			elseif inQuote == char then
				inQuote = nil
			end
			table.insert(wordChars, 1, char)
		elseif char == " " or char == "\t" then
			if inQuote then
				table.insert(wordChars, 1, char)
			else
				break
			end
		else
			table.insert(wordChars, 1, char)
		end

		i -= 1
	end

	return table.concat(wordChars)
end

pcall(function()
	ScriptEditorService:DeregisterAutocompleteCallback("mline")
end)

local success, err = pcall(function()
	return ScriptEditorService:RegisterAutocompleteCallback("mline", 5, function(req, res)
		local doc = req.textDocument and req.textDocument.document
		if not doc then return res end

		local lineNum = req.position.line
		local charPos = req.position.character
		local currentLine = doc:GetLine(lineNum)

		local currentWord = GetWordFromTypedText(currentLine, charPos)
		if currentWord == "" then return res end

		local expression, var = currentWord:match("^([^=]+)=?(%w*)$")
		if not expression then return res end

		local segments = expression:split("|")
		if #segments == 0 then return res end

		local group, mainArg = segments[1]:match("^(%w+):(.+)$")
		if not group or not mainArg then return res end

		local macro = macroGroups[group]
		if macro and type(macro.callback) == "function" then
			local props = {}
			for i = 2, #segments do
				local k, v = segments[i]:match("^(.-):(.+)$")
				if k and v then
					table.insert(props, { k, v })
				end
			end

			local success, result = pcall(macro.callback, mainArg, props, var)
			if success and result then
				local replacement = {
					start = { line = req.position.line, character = charPos - #currentWord },
					["end"] = { line = req.position.line, character = charPos }
				}

				table.insert(res.items, {
					label = currentWord .. " -> " .. (result:split("\n")[1] or "..."),
					kind = Enum.CompletionItemKind.Snippet,
					documentation = { value = macro.description },
					detail = result,
					preselect = true,
					textEdit = {
						newText = result,
						replace = replacement
					}
				})
			end
		end

		return res
	end)
end)
if not success then
	warn(err)
	error("[ MLINE ] This plugins requires permission to manage scripts. If you've denied the permission, the plugin will not function properly. You may enable it from Manage Plugins.")
end
if success then
	warn("[ MLINE ] The plugin has loaded successfully. Current version: 0.1.0;")
end
