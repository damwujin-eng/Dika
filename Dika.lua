local id = 2488
local count = 200

function Find()
    SendPacket(2, "action|dialog_return\ndialog_name|nupirkti\nname|Roulette Wheel\npirkti_id|" .. id .. "\ncount|" .. count .. "\n")
end

function Drop()
    SendPacket(2, "action|dialog_return\ndialog_name|drop_item\nitemID|" .. id .. "\ncount|" .. count .. "\n")
end

while true do
    Drop()
    sleep(300)
    Find()
    sleep(300)
end
