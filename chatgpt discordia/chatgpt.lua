local discordia = require('discordia')
local discordia = require("discordia")
local client = discordia.Client()

local http = require('coro-http1')
local json = require('json')
local fs = require("fs")

local openai_api_key = 'put api key here'
local openai_endpoint = 'https://api.openai.com/v1/'

local channelID = 'channel id here'
local messages = {}

local function loadMessages()
    local data = fs.readFileSync("messages.json")
    local sucess, result = pcall(json.decode, data)
    if sucess and type(result) == "table" then
        messages = result
    end
end

local function saveMessages()
    fs.writeFileSync("messages.json", json.encode(messages))
end

loadMessages()

client:on('messageCreate', function(message)
    if message.author.bot then return end
    if message.channel.id == channelID then
        local content = message.content
        table.insert(messages, { role = "user", content = content })
        local payload = {
            model = "gpt-3.5-turbo",
            messages = messages
        }

        local req_body = json.encode(payload)

        local headers = {
            ['Content-Type'] = 'application/json',
            ['Content-Length'] = #req_body,
            ['Authorization'] = 'Bearer ' .. openai_api_key
        }

        local url = openai_endpoint .. 'chat/completions'
        local _, body = http.request("POST", url, headers, req_body)
        print("DEBUG: " .. body)

        local data = json.decode(body)
        local response = nil
        local remember = false
        if data["error"] then
            response = data.error.message
        elseif data["choices"] then
            response = data.choices[1].message.content
            remember = true
        end
        if remember then
            table.insert(messages, { role = "assistant", content = response })
            saveMessages()
        end

        message.channel:send(response)
    end
end)

client:run('Bot token here')
