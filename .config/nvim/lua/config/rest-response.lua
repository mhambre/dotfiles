local M = {}

local function response_value(response, kind, path)
	if kind == "headers" then
		local values = response.headers[path:lower()]
		return values and values[1]
	end

	if kind == "body" and vim.startswith(path, "$.") then
		local value = response.body
		for key in path:sub(3):gmatch("[^.]+") do
			if type(value) ~= "table" then
				return nil
			end
			value = value[key]
		end
		if type(value) == "string" then
			return value
		elseif type(value) == "number" or type(value) == "boolean" or value == vim.NIL then
			return vim.json.encode(value)
		end
	end
end

function M.setup()
	local parser = require("rest-nvim.parser")
	local Context = require("rest-nvim.context").Context
	local parse = parser.parse
	local responses_by_file = {}
	local unresolved = {}

	parser.parse = function(node, source, context)
		if type(source) ~= "number" then
			return parse(node, source, context)
		end

		local buf = source == 0 and vim.api.nvim_get_current_buf() or source
		local file = vim.api.nvim_buf_get_name(buf)
		local key = file ~= "" and file or buf
		responses_by_file[key] = responses_by_file[key] or {}
		local responses = responses_by_file[key]
		context = context or Context:new()
		local resolve = context.resolve
		local missing

		-- Resolve before rest.nvim expands the URL, headers, and body.
		context.resolve = function(self, variable)
			local name, kind, path = variable:match("^([%w_-]+)%.response%.(%a+)%.(.+)$")
			if not name or (kind ~= "body" and kind ~= "headers") then
				return resolve(self, variable)
			end
			local response = responses[name]
			local value = response and response_value(response, kind, path)
			if value ~= nil then
				return value
			end
			missing = variable
			error(unresolved, 0)
		end

		local ok, request = pcall(parse, node, source, context)
		context.resolve = resolve
		if not ok then
			if request ~= unresolved then
				error(request, 0)
			end
			vim.notify("Unresolved HTTP variable: " .. missing, vim.log.levels.ERROR, { title = "rest.nvim" })
			return nil
		end

		if request and request.name and request.name:match("^[%w_-]+$") then
			table.insert(request.handlers, function(response)
				local decoded, body = pcall(vim.json.decode, response.body or "")
				responses[request.name] = {
					body = decoded and body or nil,
					headers = response.headers,
				}
			end)
		end
		return request
	end
end

return M
