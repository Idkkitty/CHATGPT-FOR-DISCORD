local discordia = require("discordia")
local client = discordia.Client()

local http = require('coro-http1') -- Do not rename to "coro-http" because this is a custom version and use the existing luvit in the github or it won't work
local json = require('json')
local fs = require("fs")

local openai_api_key = 'api key here'
local bot_token = 'bot token here'
local channelID = 'channel id here' -- The ID of the channel the bot should respond to

local messages = {}
local APIUrl = 'https://api.openai.com/v1/chat/completions'

local function loadMessages()
    local data = fs.readFileSync("messages.json")   -- reads messages.json file
    local sucess, result = pcall(json.decode, data) -- Attempts to decode json
    if sucess and type(result) == "table" then      -- Checks if the json decoding ran without problem and checks if the given result is a table
        messages = result                           -- Attemptes to set the messages table to the messages table from the messages.json
    end
end

local function saveMessages()
    fs.writeFileSync("messages.json", json.encode(messages)) -- Encodes the table into json then saves the data to message.json
end

local function Request()
    local payload = {
        model = "gpt-3.5-turbo",
        messages = messages
    }
    local req_body = json.encode(payload) -- encodes the table into json

    local headers = {
        ['Content-Type'] = 'application/json',
        ['Content-Length'] = #req_body,
        ['Authorization'] = 'Bearer ' .. openai_api_key
    }

    local res, body = http.request("POST", APIUrl, headers, req_body) -- POSTs the headers and the body
    print("DEBUG: " .. body)                                          -- For debuging other errors

    return res, body
end

loadMessages() -- Attempts to load from the save.
client:on('messageCreate', function(message)
    if message.author.bot then return end
    if message.channel.id == channelID then
        local content = message.content
        table.insert(messages, { role = "user", content = content }) -- Adds the message to the messages table

        local _, body = Request()
        local data = json.decode(body) -- decodes the json back into a table format
        local response = nil
        local remember = false
        if data["error"] then -- Simple error handler
            remember = data.error.message
        elseif data["choices"] then
            response = data.choices[1].message.content
            local tokensUsed = tonumber(data.usage.total_tokens)
            if tokensUsed >= 4204 then
                messages = {}
                message.channel:send("Bot cleared, Reason: Total Tokens is higher than the max limit of 4204 tokens")
            end
            remember = true
        end
        if remember then
            table.insert(messages, { role = "assistant", content = response }) -- Saves message to messages table (for the bot to remember)
            saveMessages()                                                     -- Saves the messages table.
        end

        if response then                                -- checks if the response exists
            fs.writeFileSync("message1.txt", response)
            message.channel:send(response:sub(1, 2000)) -- limits the response by 2000 then sends it to the channel
        end
    end
end)

client:run('Bot ' .. bot_token)
