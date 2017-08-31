serpent = require('serpent')
serp = require 'serpent'.block
http = require("socket.http")
https = require("ssl.https")
http.TIMEOUT = 10
lgi = require ('lgi')
TSHAKE=dofile('utils.lua')
json=dofile('json.lua')
JSON = (loadfile  "./libs/dkjson.lua")()
redis = (loadfile "./libs/JSON.lua")()
redis = (loadfile "./libs/redis.lua")()
database = Redis.connect('127.0.0.1', 6379)
notify = lgi.require('Notify')
tdcli = dofile('tdcli.lua')
notify.init ("Telegram updates")
sudos = dofile('sudo.lua')
chats = {}
day = 86400
  -----------------------------------------------------------------------------------------------
                                     -- start functions --
  -----------------------------------------------------------------------------------------------
function is_sudo(msg)
  local var = false
  for k,v in pairs(sudo_users) do
    if msg.sender_user_id_ == v then
      var = true
    end
  end
  return var
end
-----------------------------------------------------------------------------------------------
function is_admin(user_id)
    local var = false
	local hashs =  'bot:admins:'
    local admin = database:sismember(hashs, user_id)
	 if admin then
	    var = true
	 end
  for k,v in pairs(sudo_users) do
    if user_id == v then
      var = true
    end
  end
    return var
end
-----------------------------------------------------------------------------------------------
function is_vip_group(gp_id)
    local var = false
	local hashs =  'bot:vipgp:'
    local vip = database:sismember(hashs, gp_id)
	 if vip then
	    var = true
	 end
    return var
end
-----------------------------------------------------------------------------------------------
function is_owner(user_id, chat_id)
    local var = false
    local hash =  'bot:owners:'..chat_id
    local owner = database:sismember(hash, user_id)
	local hashs =  'bot:admins:'
    local admin = database:sismember(hashs, user_id)
	 if owner then
	    var = true
	 end
	 if admin then
	    var = true
	 end
    for k,v in pairs(sudo_users) do
    if user_id == v then
      var = true
    end
	end
    return var
end

-----------------------------------------------------------------------------------------------
function is_mod(user_id, chat_id)
    local var = false
    local hash =  'bot:mods:'..chat_id
    local mod = database:sismember(hash, user_id)
	local hashs =  'bot:admins:'
    local admin = database:sismember(hashs, user_id)
	local hashss =  'bot:owners:'..chat_id
    local owner = database:sismember(hashss, user_id)
	 if mod then
	    var = true
	 end
	 if owner then
	    var = true
	 end
	 if admin then
	    var = true
	 end
    for k,v in pairs(sudo_users) do
    if user_id == v then
      var = true
    end
	end
    return var
end
-----------------------------------------------------------------------------------------------
function is_banned(user_id, chat_id)
    local var = false
	local hash = 'bot:banned:'..chat_id
    local banned = database:sismember(hash, user_id)
	 if banned then
	    var = true
	 end
    return var
end

function is_gbanned(user_id)
  local var = false
  local hash = 'bot:gbanned:'
  local banned = database:sismember(hash, user_id)
  if banned then
    var = true
  end
  return var
end
-----------------------------------------------------------------------------------------------
function is_muted(user_id, chat_id)
    local var = false
	local hash = 'bot:muted:'..chat_id
    local banned = database:sismember(hash, user_id)
	 if banned then
	    var = true
	 end
    return var
end

function is_gmuted(user_id, chat_id)
    local var = false
	local hash = 'bot:gmuted:'..chat_id
    local banned = database:sismember(hash, user_id)
	 if banned then
	    var = true
	 end
    return var
end
-----------------------------------------------------------------------------------------------
function get_info(user_id)
  if database:hget('bot:username',user_id) then
    text = '@'..(string.gsub(database:hget('bot:username',user_id), 'false', '') or '')..''
  end
  get_user(user_id)
  return text
  --db:hrem('bot:username',user_id)
end
function get_user(user_id)
  function dl_username(arg, data)
    username = data.username or ''

    --vardump(data)
    database:hset('bot:username',data.id_,data.username_)
  end
  tdcli_function ({
    ID = "GetUser",
    user_id_ = user_id
  }, dl_username, nil)
end
local function getMessage(chat_id, message_id,cb)
  tdcli_function ({
    ID = "GetMessage",
    chat_id_ = chat_id,
    message_id_ = message_id
  }, cb, nil)
end
-----------------------------------------------------------------------------------------------
local function check_filter_words(msg, value)
  local hash = 'bot:filters:'..msg.chat_id_
  if hash then
    local names = database:hkeys(hash)
    local text = ''
    for i=1, #names do
	   if string.match(value:lower(), names[i]:lower()) and not is_mod(msg.sender_user_id_, msg.chat_id_)then
	     local id = msg.id_
         local msgs = {[0] = id}
         local chat = msg.chat_id_
        delete_msg(chat,msgs)
       end
    end
  end
end
-----------------------------------------------------------------------------------------------
function resolve_username(username,cb)
  tdcli_function ({
    ID = "SearchPublicChat",
    username_ = username
  }, cb, nil)
end
  -----------------------------------------------------------------------------------------------
function changeChatMemberStatus(chat_id, user_id, status)
  tdcli_function ({
    ID = "ChangeChatMemberStatus",
    chat_id_ = chat_id,
    user_id_ = user_id,
    status_ = {
      ID = "ChatMemberStatus" .. status
    },
  }, dl_cb, nil)
end
  -----------------------------------------------------------------------------------------------
function getInputFile(file)
  if file:match('/') then
    infile = {ID = "InputFileLocal", path_ = file}
  elseif file:match('^%d+$') then
    infile = {ID = "InputFileId", id_ = file}
  else
    infile = {ID = "InputFilePersistentId", persistent_id_ = file}
  end

  return infile
end
  -----------------------------------------------------------------------------------------------
function del_all_msgs(chat_id, user_id)
  tdcli_function ({
    ID = "DeleteMessagesFromUser",
    chat_id_ = chat_id,
    user_id_ = user_id
  }, dl_cb, nil)
end

  local function deleteMessagesFromUser(chat_id, user_id, cb, cmd)
    tdcli_function ({
      ID = "DeleteMessagesFromUser",
      chat_id_ = chat_id,
      user_id_ = user_id
    },cb or dl_cb, cmd)
  end
  -----------------------------------------------------------------------------------------------
function getChatId(id)
  local chat = {}
  local id = tostring(id)
  
  if id:match('^-100') then
    local channel_id = id:gsub('-100', '')
    chat = {ID = channel_id, type = 'channel'}
  else
    local group_id = id:gsub('-', '')
    chat = {ID = group_id, type = 'group'}
  end
  
  return chat
end
  -----------------------------------------------------------------------------------------------
function chat_leave(chat_id, user_id)
  changeChatMemberStatus(chat_id, user_id, "Left")
end
  -----------------------------------------------------------------------------------------------
function from_username(msg)
   function gfrom_user(extra,result,success)
   if result.username_ then
   F = result.username_
   else
   F = 'nil'
   end
    return F
   end
  local username = getUser(msg.sender_user_id_,gfrom_user)
  return username
end
  -----------------------------------------------------------------------------------------------
function chat_kick(chat_id, user_id)
  changeChatMemberStatus(chat_id, user_id, "Kicked")
end
  -----------------------------------------------------------------------------------------------
function do_notify (user, msg)
  local n = notify.Notification.new(user, msg)
  n:show ()
end
  -----------------------------------------------------------------------------------------------
local function getParseMode(parse_mode)  
  if parse_mode then
    local mode = parse_mode:lower()
  
    if mode == 'markdown' or mode == 'md' then
      P = {ID = "TextParseModeMarkdown"}
    elseif mode == 'html' then
      P = {ID = "TextParseModeHTML"}
    end
  end
  return P
end
  -----------------------------------------------------------------------------------------------
local function getMessage(chat_id, message_id,cb)
  tdcli_function ({
    ID = "GetMessage",
    chat_id_ = chat_id,
    message_id_ = message_id
  }, cb, nil)
end
-----------------------------------------------------------------------------------------------
function sendContact(chat_id, reply_to_message_id, disable_notification, from_background, reply_markup, phone_number, first_name, last_name, user_id)
  tdcli_function ({
    ID = "SendMessage",
    chat_id_ = chat_id,
    reply_to_message_id_ = reply_to_message_id,
    disable_notification_ = disable_notification,
    from_background_ = from_background,
    reply_markup_ = reply_markup,
    input_message_content_ = {
      ID = "InputMessageContact",
      contact_ = {
        ID = "Contact",
        phone_number_ = phone_number,
        first_name_ = first_name,
        last_name_ = last_name,
        user_id_ = user_id
      },
    },
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function sendPhoto(chat_id, reply_to_message_id, disable_notification, from_background, reply_markup, photo, caption)
  tdcli_function ({
    ID = "SendMessage",
    chat_id_ = chat_id,
    reply_to_message_id_ = reply_to_message_id,
    disable_notification_ = disable_notification,
    from_background_ = from_background,
    reply_markup_ = reply_markup,
    input_message_content_ = {
      ID = "InputMessagePhoto",
      photo_ = getInputFile(photo),
      added_sticker_file_ids_ = {},
      width_ = 0,
      height_ = 0,
      caption_ = caption
    },
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function getUserFull(user_id,cb)
  tdcli_function ({
    ID = "GetUserFull",
    user_id_ = user_id
  }, cb, nil)
end
-----------------------------------------------------------------------------------------------
function vardump(value)
  print(serpent.block(value, {comment=false}))
end
-----------------------------------------------------------------------------------------------
function dl_cb(arg, data)
end
-----------------------------------------------------------------------------------------------
local function send(chat_id, reply_to_message_id, disable_notification, text, disable_web_page_preview, parse_mode)
  local TextParseMode = getParseMode(parse_mode)
  
  tdcli_function ({
    ID = "SendMessage",
    chat_id_ = chat_id,
    reply_to_message_id_ = reply_to_message_id,
    disable_notification_ = disable_notification,
    from_background_ = 1,
    reply_markup_ = nil,
    input_message_content_ = {
      ID = "InputMessageText",
      text_ = text,
      disable_web_page_preview_ = disable_web_page_preview,
      clear_draft_ = 0,
      entities_ = {},
      parse_mode_ = TextParseMode,
    },
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function sendaction(chat_id, action, progress)
  tdcli_function ({
    ID = "SendChatAction",
    chat_id_ = chat_id,
    action_ = {
      ID = "SendMessage" .. action .. "Action",
      progress_ = progress or 100
    }
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function changetitle(chat_id, title)
  tdcli_function ({
    ID = "ChangeChatTitle",
    chat_id_ = chat_id,
    title_ = title
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function edit(chat_id, message_id, reply_markup, text, disable_web_page_preview, parse_mode)
  local TextParseMode = getParseMode(parse_mode)
  tdcli_function ({
    ID = "EditMessageText",
    chat_id_ = chat_id,
    message_id_ = message_id,
    reply_markup_ = reply_markup,
    input_message_content_ = {
      ID = "InputMessageText",
      text_ = text,
      disable_web_page_preview_ = disable_web_page_preview,
      clear_draft_ = 0,
      entities_ = {},
      parse_mode_ = TextParseMode,
    },
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function setphoto(chat_id, photo)
  tdcli_function ({
    ID = "ChangeChatPhoto",
    chat_id_ = chat_id,
    photo_ = getInputFile(photo)
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function add_user(chat_id, user_id, forward_limit)
  tdcli_function ({
    ID = "AddChatMember",
    chat_id_ = chat_id,
    user_id_ = user_id,
    forward_limit_ = forward_limit or 50
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function delmsg(arg,data)
  for k,v in pairs(data.messages_) do
    delete_msg(v.chat_id_,{[0] = v.id_})
  end
end
-----------------------------------------------------------------------------------------------
function unpinmsg(channel_id)
  tdcli_function ({
    ID = "UnpinChannelMessage",
    channel_id_ = getChatId(channel_id).ID
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
local function blockUser(user_id)
  tdcli_function ({
    ID = "BlockUser",
    user_id_ = user_id
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
local function unblockUser(user_id)
  tdcli_function ({
    ID = "UnblockUser",
    user_id_ = user_id
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
local function getBlockedUsers(offset, limit)
  tdcli_function ({
    ID = "GetBlockedUsers",
    offset_ = offset,
    limit_ = limit
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function delete_msg(chatid,mid)
  tdcli_function ({
  ID="DeleteMessages", 
  chat_id_=chatid, 
  message_ids_=mid
  },
  dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function chat_del_user(chat_id, user_id)
  changeChatMemberStatus(chat_id, user_id, 'Editor')
end
-----------------------------------------------------------------------------------------------
function getChannelMembers(channel_id, offset, filter, limit)
  if not limit or limit > 200 then
    limit = 200
  end
  tdcli_function ({
    ID = "GetChannelMembers",
    channel_id_ = getChatId(channel_id).ID,
    filter_ = {
      ID = "ChannelMembers" .. filter
    },
    offset_ = offset,
    limit_ = limit
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function getChannelFull(channel_id)
  tdcli_function ({
    ID = "GetChannelFull",
    channel_id_ = getChatId(channel_id).ID
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
local function channel_get_bots(channel,cb)
local function callback_admins(extra,result,success)
    limit = result.member_count_
    getChannelMembers(channel, 0, 'Bots', limit,cb)
    channel_get_bots(channel,get_bots)
end

  getChannelFull(channel,callback_admins)
end
-----------------------------------------------------------------------------------------------
local function getInputMessageContent(file, filetype, caption)
  if file:match('/') then
    infile = {ID = "InputFileLocal", path_ = file}
  elseif file:match('^%d+$') then
    infile = {ID = "InputFileId", id_ = file}
  else
    infile = {ID = "InputFilePersistentId", persistent_id_ = file}
  end

  local inmsg = {}
  local filetype = filetype:lower()

  if filetype == 'animation' then
    inmsg = {ID = "InputMessageAnimation", animation_ = infile, caption_ = caption}
  elseif filetype == 'audio' then
    inmsg = {ID = "InputMessageAudio", audio_ = infile, caption_ = caption}
  elseif filetype == 'document' then
    inmsg = {ID = "InputMessageDocument", document_ = infile, caption_ = caption}
  elseif filetype == 'photo' then
    inmsg = {ID = "InputMessagePhoto", photo_ = infile, caption_ = caption}
  elseif filetype == 'sticker' then
    inmsg = {ID = "InputMessageSticker", sticker_ = infile, caption_ = caption}
  elseif filetype == 'video' then
    inmsg = {ID = "InputMessageVideo", video_ = infile, caption_ = caption}
  elseif filetype == 'voice' then
    inmsg = {ID = "InputMessageVoice", voice_ = infile, caption_ = caption}
  end

  return inmsg
end

-----------------------------------------------------------------------------------------------
function send_file(chat_id, type, file, caption,wtf)
local mame = (wtf or 0)
  tdcli_function ({
    ID = "SendMessage",
    chat_id_ = chat_id,
    reply_to_message_id_ = mame,
    disable_notification_ = 0,
    from_background_ = 1,
    reply_markup_ = nil,
    input_message_content_ = getInputMessageContent(file, type, caption),
  }, dl_cb, nil)
end
-----------------------------------------------------------------------------------------------
function getUser(user_id, cb)
  tdcli_function ({
    ID = "GetUser",
    user_id_ = user_id
  }, cb, nil)
end
-----------------------------------------------------------------------------------------------
function pin(channel_id, message_id, disable_notification) 
   tdcli_function ({ 
     ID = "PinChannelMessage", 
     channel_id_ = getChatId(channel_id).ID, 
     message_id_ = message_id, 
     disable_notification_ = disable_notification 
   }, dl_cb, nil) 
end 
-----------------------------------------------------------------------------------------------
function tdcli_update_callback(data)
	-------------------------------------------
  if (data.ID == "UpdateNewMessage") then
    local msg = data.message_
    --vardump(data)
    local d = data.disable_notification_
    local chat = chats[msg.chat_id_]
	-------------------------------------------
	if msg.date_ < (os.time() - 30) then
       return false
    end
	-------------------------------------------
	if not database:get("bot:enable:"..msg.chat_id_) and not is_admin(msg.sender_user_id_, msg.chat_id_) then
      return false
    end
    -------------------------------------------
      if msg and msg.send_state_.ID == "MessageIsSuccessfullySent" then
	  --vardump(msg)
	   function get_mymsg_contact(extra, result, success)
             --vardump(result)
       end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,get_mymsg_contact)
         return false 
      end
    -------------* EXPIRE *-----------------
    if not database:get("bot:charge:"..msg.chat_id_) then
     if database:get("bot:enable:"..msg.chat_id_) then
      database:del("bot:enable:"..msg.chat_id_)
      for k,v in pairs(sudo_users) do
        send(v, 0, 1, "link \nLink : "..(database:get("bot:group:link"..msg.chat_id_) or "settings").."\nID : "..msg.chat_id_..'\n\nuse  leave\n\nleave'..msg.chat_id_..'\nuse join:\njoin'..msg.chat_id_..'\n_________________\nuse plan...\n\n*30 days:*\n/plan1'..msg.chat_id_..'\n\n*90 days:*\n/plan2'..msg.chat_id_..'\n\n*No fanil:*\n/plan3'..msg.chat_id_, 1, 'md')
      end
      end
    end
    --------- ANTI FLOOD -------------------
	local hash = 'flood:max:'..msg.chat_id_
    if not database:get(hash) then
        floodMax = 10
    else
        floodMax = tonumber(database:get(hash))
    end

    local hash = 'flood:time:'..msg.chat_id_
    if not database:get(hash) then
        floodTime = 2
    else
        floodTime = tonumber(database:get(hash))
    end
    if not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local hashse = 'anti-flood:'..msg.chat_id_
        if not database:get(hashse) then
                if not is_mod(msg.sender_user_id_, msg.chat_id_) then
                    local hash = 'flood:'..msg.sender_user_id_..':'..msg.chat_id_..':msg-num'
                    local msgs = tonumber(database:get(hash) or 0)
                    if msgs > (floodMax - 1) then
                        local user = msg.sender_user_id_
                        local chat = msg.chat_id_
                        local channel = msg.chat_id_
						 local user_id = msg.sender_user_id_
						 local banned = is_banned(user_id, msg.chat_id_)
                         if banned then
						local id = msg.id_
        				local msgs = {[0] = id}
       					local chat = msg.chat_id_
       						       del_all_msgs(msg.chat_id_, msg.sender_user_id_)
						    else
						 local id = msg.id_
                         local msgs = {[0] = id}
                         local chat = msg.chat_id_
		                chat_kick(msg.chat_id_, msg.sender_user_id_)
						 del_all_msgs(msg.chat_id_, msg.sender_user_id_)
						user_id = msg.sender_user_id_
						local bhash =  'bot:banned:'..msg.chat_id_
                        database:sadd(bhash, user_id)
                           send(msg.chat_id_, msg.id_, 1, '> _ID_  *('..msg.sender_user_id_..')* \n_Spamming Not Allowed Here._\n`Spammer Banned!!`', 1, 'md')
					  end
                    end
                    database:setex(hash, floodTime, msgs+1)
                end
        end
	end
	
	local hash = 'flood:max:warn'..msg.chat_id_
    if not database:get(hash) then
        floodMax = 10
    else
        floodMax = tonumber(database:get(hash))
    end

    local hash = 'flood:time:'..msg.chat_id_
    if not database:get(hash) then
        floodTime = 2
    else
        floodTime = tonumber(database:get(hash))
    end
    if not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local hashse = 'anti-flood:warn'..msg.chat_id_
        if not database:get(hashse) then
                if not is_mod(msg.sender_user_id_, msg.chat_id_) then
                    local hash = 'flood:'..msg.sender_user_id_..':'..msg.chat_id_..':msg-num'
                    local msgs = tonumber(database:get(hash) or 0)
                    if msgs > (floodMax - 1) then
                        local user = msg.sender_user_id_
                        local chat = msg.chat_id_
                        local channel = msg.chat_id_
						 local user_id = msg.sender_user_id_
						 local banned = is_banned(user_id, msg.chat_id_)
                         if banned then
						local id = msg.id_
        				local msgs = {[0] = id}
       					local chat = msg.chat_id_
       						       del_all_msgs(msg.chat_id_, msg.sender_user_id_)
						    else
						 local id = msg.id_
                         local msgs = {[0] = id}
                         local chat = msg.chat_id_
						 del_all_msgs(msg.chat_id_, msg.sender_user_id_)
						user_id = msg.sender_user_id_
						local bhash =  'bot:muted:'..msg.chat_id_
                        database:sadd(bhash, user_id)
                           send(msg.chat_id_, msg.id_, 1, '> _ID_  *('..msg.sender_user_id_..')* \n_Spamming Not Allowed Here._\n`Spammer Muted!!`', 1, 'md')

					  end
                    end
                    database:setex(hash, floodTime, msgs+1)
                end
        end
	end
	-------------------------------------------
	database:incr("bot:allmsgs")
	if msg.chat_id_ then
      local id = tostring(msg.chat_id_)
      if id:match('-100(%d+)') then
        if not database:sismember("bot:groups",msg.chat_id_) then
            database:sadd("bot:groups",msg.chat_id_)
        end
        elseif id:match('^(%d+)') then
        if not database:sismember("bot:userss",msg.chat_id_) then
            database:sadd("bot:userss",msg.chat_id_)
        end
        else
        if not database:sismember("bot:groups",msg.chat_id_) then
            database:sadd("bot:groups",msg.chat_id_)
        end
     end
    end
	-------------------------------------------
    -------------* MSG TYPES *-----------------
   if msg.content_ then
   	if msg.reply_markup_ and  msg.reply_markup_.ID == "ReplyMarkupInlineKeyboard" then
		print("Send INLINE KEYBOARD")
	msg_type = 'MSG:Inline'
	-------------------------
    elseif msg.content_.ID == "MessageText" then
	text = msg.content_.text_
		print("SEND TEXT")
	msg_type = 'MSG:Text'
	-------------------------
	elseif msg.content_.ID == "MessagePhoto" then
	print("SEND PHOTO")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Photo'
	-------------------------
	elseif msg.content_.ID == "MessageChatAddMembers" then
	print("NEW ADD TO GROUP")
	msg_type = 'MSG:NewUserAdd'
	-------------------------
	elseif msg.content_.ID == "MessageChatJoinByLink" then
		print("JOIN TO GROUP")
	msg_type = 'MSG:NewUserLink'
	-------------------------
	elseif msg.content_.ID == "MessageSticker" then
		print("SEND STICKER")
	msg_type = 'MSG:Sticker'
	-------------------------
	elseif msg.content_.ID == "MessageAudio" then
		print("SEND MUSIC")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Audio'
	-------------------------
	elseif msg.content_.ID == "MessageVoice" then
		print("SEND VOICE")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Voice'
	-------------------------
	elseif msg.content_.ID == "MessageVideo" then
		print("SEND VIDEO")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Video'
	-------------------------
	elseif msg.content_.ID == "MessageAnimation" then
		print("SEND GIF")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Gif'
	-------------------------
	elseif msg.content_.ID == "MessageLocation" then
		print("SEND LOCATION")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Location'
	-------------------------
	elseif msg.content_.ID == "MessageChatJoinByLink" or msg.content_.ID == "MessageChatAddMembers" then
	msg_type = 'MSG:NewUser'
	-------------------------
	elseif msg.content_.ID == "MessageContact" then
		print("SEND CONTACT")
	if msg.content_.caption_ then
	caption_text = msg.content_.caption_
	end
	msg_type = 'MSG:Contact'
	-------------------------
	end
   end
    -------------------------------------------
    -------------------------------------------
    if ((not d) and chat) then
      if msg.content_.ID == "MessageText" then
        do_notify (chat.title_, msg.content_.text_)
      else
        do_notify (chat.title_, msg.content_.ID)
      end
    end
  -----------------------------------------------------------------------------------------------
                                     -- end functions --
  -----------------------------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------
                                     -- start code --
  -----------------------------------------------------------------------------------------------
  -------------------------------------- Process mod --------------------------------------------
  -----------------------------------------------------------------------------------------------
  
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
  --------------------------******** START MSG CHECKS ********-------------------------------------------
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
if is_banned(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
		  chat_kick(msg.chat_id_, msg.sender_user_id_)
		  return 
end

if is_gbanned(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
		  chat_kick(msg.chat_id_, msg.sender_user_id_)
		  return 
end

if is_muted(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
          delete_msg(chat,msgs)
		  return 
end
if database:get('bot:muteall'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
        return 
end

if database:get('bot:muteallwarn'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از چت در گروه خودداری کنید_".."\n_تعداد اخطار: 1\n_محدوده اخطار:_ "..setwarn.."*", 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از چت در گروه خودداری کنید_".."\n_شما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید_", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از چت در گروه خودداری کنید_".."\n_تعداد اخطار:_ ".. (warn + 1).."\n_محدوده اخطار:_ *"..setwarn.."*", 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
   end

if database:get('bot:muteallban'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت چت در گروه_\n_اخراج شد_", 1, 'md')
        return 
end
    database:incr('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
	database:incr('group:msgs'..msg.chat_id_)
if msg.content_.ID == "MessagePinMessage" then
  if database:get('pinnedmsg'..msg.chat_id_) and database:get('bot:pin:mute'..msg.chat_id_) then
   unpinmsg(msg.chat_id_)
   local pin_id = database:get('pinnedmsg'..msg.chat_id_)
         pin(msg.chat_id_,pin_id,0)
   end
end
    database:incr('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
	database:incr('group:msgs'..msg.chat_id_)
if msg.content_.ID == "MessagePinMessage" then
  if database:get('pinnedmsg'..msg.chat_id_) and database:get('bot:pin:warn'..msg.chat_id_) then
   send(msg.chat_id_, msg.id_, 1, "*Your ID :* _"..msg.sender_user_id_.."_\n*UserName :* "..get_info(msg.sender_user_id_).."\n*Pin is Locked Group*", 1, 'md')
   unpinmsg(msg.chat_id_)
   local pin_id = database:get('pinnedmsg'..msg.chat_id_)
         pin(msg.chat_id_,pin_id,0)
   end
end
if database:get('bot:viewget'..msg.sender_user_id_) then 
    if not msg.forward_info_ then
		send(msg.chat_id_, msg.id_, 1, '`:/`', 1, 'md')
		database:del('bot:viewget'..msg.sender_user_id_)
	else
		send(msg.chat_id_, msg.id_, 1, '_تعداد مشاهده:_\n> '..msg.views_..'', 1, 'md')
        database:del('bot:viewget'..msg.sender_user_id_)
	end
end
if msg_type == 'MSG:Photo' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
     if database:get('bot:photo:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if database:get('bot:photo:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
		   chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال عکس در گروه_\n_اخراج شد_", 1, 'md')

          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:photo:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال عکس در گروه خودداری کنید_".."\n_تعداد اخطار: 1_\n_محدوده اخطار:_ "..setwarn.."*", 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال عکس در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال عکس در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
  elseif msg_type == 'MSG:Inline' then
   if not is_mod(msg.sender_user_id_, msg.chat_id_) then
    if database:get('bot:inline:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:inline:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال اینلاین در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:inline:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_)  
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال اینلاین در گروه خودداری کنید_".."\nتعداد اخطار: 1\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
		  end
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال اینلاین در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 kick_user(chat,user_id)
          return 
      else
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال اینلاین در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
      end
   end
   end
  elseif msg_type == 'MSG:Sticker' then
   if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:sticker:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:sticker:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال استیکر در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:sticker:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال استیکر در گروه خودداری کنید_".."\nتعداد اخطار: 1\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال استیکر در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال استیکر در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
elseif msg_type == 'MSG:NewUserLink' then
  if database:get('bot:tgservice:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
   function get_welcome(extra,result,success)
    if database:get('welcome:'..msg.chat_id_) then
        text = database:get('welcome:'..msg.chat_id_)
    else
        text = 'Hi {firstname} 😃'
    end
    local text = text:gsub('{firstname}',(result.first_name_ or ''))
    local text = text:gsub('{lastname}',(result.last_name_ or ''))
    local text = text:gsub('{username}',(result.username_ or ''))
         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
	  if database:get("bot:welcome"..msg.chat_id_) then
        getUser(msg.sender_user_id_,get_welcome)
      end
elseif msg_type == 'MSG:NewUserAdd' then
  if database:get('bot:tgservice:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
      --vardump(msg)
   if msg.content_.members_[0].username_ and msg.content_.members_[0].username_:match("[Bb][Oo][Tt]$") then
      if database:get('bot:bots:mute'..msg.chat_id_) and not is_mod(msg.content_.members_[0].id_, msg.chat_id_) then
		 chat_kick(msg.chat_id_, msg.content_.members_[0].id_)
		 return false
	  end
   end
   if is_banned(msg.content_.members_[0].id_, msg.chat_id_) then
		 chat_kick(msg.chat_id_, msg.content_.members_[0].id_)
		 return false
   end
   if database:get("bot:welcome"..msg.chat_id_) then
    if database:get('welcome:'..msg.chat_id_) then
        text = database:get('welcome:'..msg.chat_id_)
    else
        text = 'Hi {firstname} 😃'
    end
    local text = text:gsub('{firstname}',(msg.content_.members_[0].first_name_ or ''))
    local text = text:gsub('{lastname}',(msg.content_.members_[0].last_name_ or ''))
    local text = text:gsub('{username}',('@'..msg.content_.members_[0].username_ or ''))
         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
elseif msg_type == 'MSG:Contact' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:contact:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:contact:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال مخاطبین در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:contact:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال مخاطبین در گروه خودداری کنید_".."\nتعداد اخطار: 1\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال مخاطبین در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال مخاطبین در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
elseif msg_type == 'MSG:Audio' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:music:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return 
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:music:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال اهنگ در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:music:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال اهنگ در گروه خودداری کنید_".."\nتعداد اخطار: 1\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال اهنگ در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال اهنگ در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
elseif msg_type == 'MSG:Voice' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:voice:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return  
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:voice:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال صدا در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:voice:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال صدا در گروه خودداری کنید_".."\nتعداد اخطار: 1\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال صدا در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال صدا در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
elseif msg_type == 'MSG:Location' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:location:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return  
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:location:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال موقعیت مکانی در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:location:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال موقعیت مکانی در گروه خودداری کنید_".."\nتعداد اخطار: 1\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال موقعیت مکانی در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال موقعیت مکانی در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
elseif msg_type == 'MSG:Video' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:video:mute'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return  
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:video:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال ویدیو در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:video:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال ویدیو در گروه خودداری کنید_".."\nتعداد اخطار: 1\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال ویدیو در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال ویدیو در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
elseif msg_type == 'MSG:Gif' then
 if not is_mod(msg.sender_user_id_, msg.chat_id_) then
  if database:get('bot:gifs:mute'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
       delete_msg(chat,msgs)
          return  
   end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:gifs:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال گیف در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:gifs:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال گیف در گروه خودداری کنید_".."\nتعداد اخطار: 1\nمحدوده اخطار: "..setwarn, 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال گیف در گروه خودداری کنید_".."\nشما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال گیف در گروه خودداری کنید_".."\nتعداد اخطار: ".. (warn + 1).."\nمحدوده اخطار: "..setwarn, 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
elseif msg_type == 'MSG:Text' then
 --vardump(msg)
    if database:get("bot:group:link"..msg.chat_id_) == 'Waiting For Link!\nPls Send Group Link' and is_mod(msg.sender_user_id_, msg.chat_id_) then if text:match("(https://telegram.me/joinchat/%S+)") or text:match("(https://t.me/joinchat/%S+)") then 	 local glink = text:match("(https://telegram.me/joinchat/%S+)") or text:match("(https://t.me/joinchat/%S+)") local hash = "bot:group:link"..msg.chat_id_ database:set(hash,glink) 			 send(msg.chat_id_, msg.id_, 1, '*New link Set!*', 1, 'md') send(msg.chat_id_, 0, 1, '*New Group link:*\n'..glink, 1, 'md')
      end
   end
    function check_username(extra,result,success)
	 --vardump(result)
	local username = (result.username_ or '')
	local svuser = 'user:'..result.id_
	if username then
      database:hset(svuser, 'username', username)
    end
	if username and username:match("[Bb][Oo][Tt]$") then
      if database:get('bot:bots:mute'..msg.chat_id_) and not is_mod(result.id_, msg.chat_id_) then
		 chat_kick(msg.chat_id_, result.id_)
		 return false
		 end
	  end
   end
    getUser(msg.sender_user_id_,check_username)
   database:set('bot:editid'.. msg.id_,msg.content_.text_)
   if not is_mod(msg.sender_user_id_, msg.chat_id_) then
    check_filter_words(msg, text)
	if text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Mm][Ee]") or 
text:match("[Tt].[Mm][Ee]") or
text:match("[Tt][Ll][Gg][Rr][Mm].[Mm][Ee]") then
     if database:get('bot:links:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
       if database:get('bot:links:ban'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال لینک در گروه_\n_اخراج شد_", 1, 'md')
  end
       if database:get('bot:links:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال لینک در گروه خودداری کنید_".."\nتعداد اخطار: 1_\n_محدوده اخطار:_ "..setwarn.."*", 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال لینک در گروه خودداری کنید_".."\n_شما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید_", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال لینک در گروه خودداری کنید_".."\n_تعداد اخطار:_ ".. (warn + 1).."\n_محدوده اخطار:_ *"..setwarn.."*", 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end

            if text then
              local _nl, ctrl_chars = string.gsub(text, '%c', '')
              local _nl, real_digits = string.gsub(text, '%d', '')
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              local hash = 'bot:sens:spam'..msg.chat_id_
              if not database:get(hash) then
                sens = 100
              else
                sens = tonumber(database:get(hash))
              end
              if database:get('bot:spam:mute'..msg.chat_id_) and string.len(text) > (sens) or ctrl_chars > (sens) or real_digits > (sens) then
                delete_msg(chat,msgs)
              end
          end 
          
            if text then
              local _nl, ctrl_chars = string.gsub(text, '%c', '')
              local _nl, real_digits = string.gsub(text, '%d', '')
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              local hash = 'bot:sens:spam:warn'..msg.chat_id_
              if not database:get(hash) then
                sens = 100
              else
                sens = tonumber(database:get(hash))
              end
              if database:get('bot:spam:warn'..msg.chat_id_) and string.len(text) > (sens) or ctrl_chars > (sens) or real_digits > (sens) then
                delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از اسپم درگروه خود داری کنید_", 1, 'md')
              end
          end 

	if text then
     if database:get('bot:text:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:text:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال متن در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:text:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال متن در گروه خودداری کنید_".."\n_تعداد اخطار: 1_\n_محدوده اخطار:_ "..setwarn.."*", 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال متن در گروه خودداری کنید_".."\n_شما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید_", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال متن در گروه خودداری کنید_".."\n_تعداد اخطار:_ ".. (warn + 1).."\n_محدوده اخطار:_ *"..setwarn.."*", 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
if msg.forward_info_ then
if database:get('bot:forward:mute'..msg.chat_id_) then
	if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
   end
end
end
if msg.forward_info_ then
if database:get('bot:forward:ban'..msg.chat_id_) then
	if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
		                chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال نقل قول در گروه_\n_اخراج شد_", 1, 'md')
	end
   end

if msg.forward_info_ then
if database:get('bot:forward:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال نقل قول در گروه خودداری کنید_".."\nتعداد اخطار: 1\n_محدوده اخطار:_ "..setwarn.."*", 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال نقل قول در گروه خودداری کنید_".."\n_شما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید_", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال نقل قول در گروه خودداری کنید_".."\n_تعداد اخطار:_ ".. (warn + 1).."\n_محدوده اخطار:_ *"..setwarn.."*", 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
end
elseif msg_type == 'MSG:Text' then
   if text:match("@") or msg.content_.entities_[0] and msg.content_.entities_[0].ID == "MessageEntityMentionName" then
   if database:get('bot:tag:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:tag:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال تگ در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:tag:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال تگ در گروه خودداری کنید_".."\n_تعداد اخطار: 1\n_محدوده اخطار:_ "..setwarn.."*", 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال تگ در گروه خودداری کنید_".."\n_شما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید_", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال تگ در گروه خودداری کنید_".."\n_تعداد اخطار:_ ".. (warn + 1).."\n_محدوده اخطار:_ *"..setwarn.."*", 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
   	if text:match("#") then
      if database:get('bot:hashtag:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:hashtag:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال هشتگ در گروه خودداری کنید_".."\nتعداد اخطار: 1_\n_محدوده اخطار:_ "..setwarn.."*", 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال هشتگ در گروه خودداری کنید_".."\n_شما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید_", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال هشتگ در گروه خودداری کنید_".."\n_تعداد اخطار:_ ".. (warn + 1).."\n_محدوده اخطار:_ *"..setwarn.."*", 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
   	if text:match("/") then
      if database:get('bot:cmd:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end 
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
      if database:get('bot:cmd:ban'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        local user_id = msg.sender_user_id_
        delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت بازی با ربات_\n_اخراج شد_", 1, 'md')
	end 
	      if database:get('bot:cmd:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
    local warn = database:hget('warning:'..user_id, 'gchat'..chat)
    local setwarn = database:hget("setwarn:"..msg.chat_id_, msg.chat_id_) 
    if  not warn then
    database:hset('warning:'..user_id, 'gchat'..chat, '1')
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از بازی باربات در گروه جلوگیر کنید_".."\n_تعداد اخطار: 1\n_محدوده اخطار:_ "..setwarn.."*", 1, 'md')
 
          return 
   else
   if (tonumber(warn) + 1) >= tonumber(setwarn) then
   delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از بازی باربات در گروه جلوگیر کنید_".."\n_شما بیشتوین اخطار را گرفتید و از گروه اخراج میشوید_", 1, 'md')
 chat_kick(msg.chat_id_, msg.sender_user_id_)
 database:hset('warning:'..user_id, 'gchat'..chat, '0')
          return 
      elseif (tonumber(warn) + 1) < tonumber(setwarn) then
      delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از بازی باربات در گروه جلوگیر کنید_".."\n_تعداد اخطار:_ ".. (warn + 1).."\n_محدوده اخطار:_ *"..setwarn.."*", 1, 'md')
 database:hset('warning:'..user_id, 'gchat'..chat, warn + 1)
          return 
      end
   end
end
   end
   	if text:match("[Hh][Tt][Tt][Pp][Ss]://") or text:match("[Hh][Tt][Tt][Pp]://") or text:match(".[Ii][Rr]") or text:match(".[Cc][Oo][Mm]") or text:match(".[Oo][Rr][Gg]") or text:match(".[Ii][Nn][Ff][Oo]") or text:match("[Ww][Ww][Ww].") or text:match(".[Tt][Kk]") then
      if database:get('bot:webpage:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:webpage:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال صفحات اینترنتی در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:webpage:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
	
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از فرستادن صفحات اینرنتی خودداری کنید_", 1, 'md')
          return 
   end
 end
   	if text:match("[\216-\219][\128-\191]") then
      if database:get('bot:arabic:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
        if database:get('bot:arabic:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال کلمات عربی در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:arabic:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال کلمات عربی در گروه خودداری کنید_", 1, 'md')
          return 
   end
 end
   	  if text:match("[ASDFGHJKLQWERTYUIOPZXCVBNMasdfghjklqwertyuiopzxcvbnm]") then
      if database:get('bot:english:mute'..msg.chat_id_) then
     local id = msg.id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
        delete_msg(chat,msgs)
	  end
        if msg.forward_info_ then
          if database:get('bot:forward:mute'..msg.chat_id_) then
            if msg.forward_info_.ID == "MessageForwardedFromUser" or msg.forward_info_.ID == "MessageForwardedPost" then
              local id = msg.id_
              local msgs = {[0] = id}
              local chat = msg.chat_id_
              delete_msg(chat,msgs)
            end
          end
        end
	          if database:get('bot:english:ban'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
       chat_kick(msg.chat_id_, msg.sender_user_id_)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_به علت ارسال کلمات انگلیسی در گروه_\n_اخراج شد_", 1, 'md')
          return 
   end
   
        if database:get('bot:english:warn'..msg.chat_id_) then
    local id = msg.id_
    local msgs = {[0] = id}
    local chat = msg.chat_id_
    local user_id = msg.sender_user_id_
       delete_msg(chat,msgs)
          send(msg.chat_id_, 0, 1, "_کاربر :_ *"..msg.sender_user_id_.."*\n_از ارسال کلمات انگلیسی در گروه خودداری کنید_", 1, 'md')
          return 
   end
     end
    end
   end
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
  ---------------------------******** END MSG CHECKS ********--------------------------------------------
  -------------------------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------------------------
  if database:get('bot:cmds'..msg.chat_id_) and not is_mod(msg.sender_user_id_, msg.chat_id_) then
  return 
  else
    ------------------------------------ With Pattern -------------------------------------------
	if text:match("^ping$") then
	   send(msg.chat_id_, msg.id_, 1, '_Pong_', 1, 'md')
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ll][Ee][Aa][Vv][Ee]") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	     chat_leave(msg.chat_id_, bot_id)
    end
    
	if text:match("^لفت") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	     chat_leave(msg.chat_id_, bot_id)
    end
	-----------------------------------------------------------------------------------------------
        local text = msg.content_.text_:gsub('ارتقا مقام','modset')
	if text:match("^[Mm][Oo][Dd][Ss][Ee][Tt]$")  and is_owner(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function promote_by_reply(extra, result, success)
	local hash = 'bot:mods:'..msg.chat_id_
	if database:sismember(hash, result.sender_user_id_) then
              if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is Already moderator._', 1, 'md')
              else
                send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _هم اکنون مدیر است !_', 1, 'md')
              end
            else
         database:sadd(hash, result.sender_user_id_)
              if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _promoted as moderator._', 1, 'md')
              else
                send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _به مدیریت ارتقا مقام یافت !_', 1, 'md')
              end
	end 
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,promote_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Mm][Oo][Dd][Ss][Ee][Tt] @(.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Mm][Oo][Dd][Ss][Ee][Tt]) @(.*)$")} 
	function promote_by_username(extra, result, success)
	if result.id_ then
	        database:sadd('bot:mods:'..msg.chat_id_, result.id_)
              if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User* _'..result.id_..'_ *promoted as moderator.!*'
          else
            texts = '_کاربر با شناسه :_ *'..result.id_..'* _به مدیریت ارتقا مقام یافت !_'
            end
          else 
              if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User not found!*'
          else
            texts = '_ کاربر یافت نشد !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],promote_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Mm][Oo][Dd][Ss][Ee][Tt] (%d+)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local ap = {string.match(text, "^([Mm][Oo][Dd][Ss][Ee][Tt]) (%d+)$")} 	
	        database:sadd('bot:mods:'..msg.chat_id_, ap[2])
          if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '*User* _'..ap[2]..'_ *promoted as moderator.*', 1, 'md')
          else
        send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..ap[2]..'* _به مدیریت ارتقا مقام یافت_ !', 1, 'md')
          end
    end
	-----------------------------------------------------------------------------------------------
        local text = msg.content_.text_:gsub('عزل مقام','moddem')
        if text:match("^[Mm][Oo][Dd[Dd][Dd][Ee][Mm]$") and is_owner(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ ~= 0 then
          function demote_by_reply(extra, result, success)
            local hash = 'bot:momod:'..msg.chat_id_
            if not database:sismember(hash, result.sender_user_id_) then
              if database:get('lang:gp:'..msg.chat_id_) then
                send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *is not a moderator !*', 1, 'md')
              else
                send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _مدیر نمیباشد !_', 1, 'md')
              end
            else
              database:srem(hash, result.sender_user_id_)
              if database:get('lang:gp:'..msg.chat_id_) then
                send(msg.chat_id_, msg.id_, 1, '*User :* _'..result.sender_user_id_..'_ was *removed* from moderator !', 1, 'md')
              else
                send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* از مدیریت حذف شد !', 1, 'md')
              end
            end
          end
          getMessage(msg.chat_id_, msg.reply_to_message_id_,demote_by_reply)
        end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Mm][Oo][Dd[Dd][Dd][Ee][Mm] @(.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local hash = 'bot:mods:'..msg.chat_id_
	local ap = {string.match(text, "^([Mm][Oo][Dd[Dd][Dd][Ee][Mm]) @(.*)$")} 
	function demote_by_username(extra, result, success)
	if result.id_ then
         database:srem(hash, result.id_)
              if database:get('lang:gp:'..msg.chat_id_) then
                texts = '*User* _'..result.id_..'_ *was demoted*'
              else
                texts = '_کاربر با شناسه :_ *'..result.id_..'* _عزل مقام شد_'
              end
              database:srem(hash, result.id_)
            else
              if not database:get('lang:gp:'..msg.chat_id_) then
                texts = '*User not found !*'
              else
                texts = '_کاربر یافت نشد !_'
              end
            end
            send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
          end
          resolve_username(ap[2],demote_by_username)
        end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Mm][Oo][Dd[Dd][Dd][Ee][Mm] (%d+)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local hash = 'bot:mods:'..msg.chat_id_
	local apba = {string.match(text, "^([[Mm][Oo][Dd[Dd][Dd][Ee][Mm] (%d+)$")} 	
         database:srem(hash, apba[2])
              if database:get('lang:gp:'..msg.chat_id_) then
            send(msg.chat_id_, msg.id_, 1, '*User* _'..ap[2]..'_ *was demoted !*', 1, 'md')
          else
            send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..ap[2]..'* _عزل مقام شد !_', 1, 'md')
          end
          database:srem(hash, ap[2])
        end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('بن','Ban')
	if text:match("^[Bb][Aa][Nn]$") and is_mod(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function ban_by_reply(extra, result, success)
	local hash = 'bot:banned:'..msg.chat_id_
	if is_mod(result.sender_user_id_, result.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد مديران را اخراج کنيد`', 1, 'md')
end
    else
    if database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *is already banned !*', 1, 'md')
else
                    send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه : *'..result.sender_user_id_..'* _هم اکنون مسدود است !_', 1, 'md')
end
		 chat_kick(result.chat_id_, result.sender_user_id_)
	else
         database:sadd(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *has been banned !*', 1, 'md')
       else
                    send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _مسدود گردید !_', 1, 'md')
end
		 chat_kick(result.chat_id_, result.sender_user_id_)
	end
    end
	end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,ban_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Bb][Aa][Nn] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apba = {string.match(text, "^([Bb][Aa][Nn]) @(.*)$")} 
	function ban_by_username(extra, result, success)
	if result.id_ then
	if is_mod(result.id_, msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد مديران را اخراج کنيد`', 1, 'md')
end
    else
	        database:sadd('bot:banned:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
                    texts = '*User* _'..result.id_..'_ *has been banned !*'
else
                    texts = '_کاربر با شناسه :_ *'..result.id_..'* _مسدود گردید !_'
end
		 chat_kick(msg.chat_id_, result.id_)
	end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
                  texts = '*User not found*'
          else
                  texts = '_کاربر یافت نشد !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(apba[2],ban_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Bb][Aa][Nn] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apba = {string.match(text, "^([Bb][Aa][Nn]) (%d+)$")}
	if is_mod(apba[2], msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/Ban] Moderators!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد مديران را اخراج کنيد`', 1, 'md')
end
    else
	        database:sadd('bot:banned:'..msg.chat_id_, apba[2])
		 chat_kick(msg.chat_id_, apba[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
                send(msg.chat_id_, msg.id_, 1, '*User* _'..apba[2]..'_ *has been banned !*', 1, 'md')
else
                send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..apba[2]..'* _مسدود گردید !_', 1, 'md')
  	end
	end
end
  ----------------------------------------------unban--------------------------------------------
          local text = msg.content_.text_:gsub('لغو بن','unban')
  	if text:match("^[Uu][Nn][Bb][Aa][Nn]$") and is_mod(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function unban_by_reply(extra, result, success)
	local hash = 'bot:banned:'..msg.chat_id_
	if not database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '*User * _'..result.sender_user_id_..'_ *is not banned !*', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _مسدود نیست !_', 1, 'md')
end
	else
         database:srem(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *Unbanned.*', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه : '..result.sender_user_id_..' _آزاد شد !_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,unban_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Uu][Nn][Bb][Aa][Nn] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apba = {string.match(text, "^([Uu][Nn][Bb][Aa][Nn]) @(.*)$")} 
	function unban_by_username(extra, result, success)
	if result.id_ then
         database:srem('bot:banned:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '*User* _'..result.id_..'_ *Unbanned.!*'
      else
             text = '_کاربر با شناسه :_ *'..result.id_..'* _آزاد شد !_'
end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '*User not found !*'
                else
                  text = '_کاربر یافت نشد !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	      resolve_username(apba[2],unban_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Uu][Nn][Bb][Aa][Nn] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apba = {string.match(text, "^([Uu][Nn][Bb][Aa][Nn]) (%d+)$")} 	
	        database:srem('bot:banned:'..msg.chat_id_, apba[2])
        if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '*User* _'..apba[2]..'_ *Unbanned.*', 1, 'md')
else
    send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ '..apba[2]..' _آزاد شد !_', 1, 'md')
end
  end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('پاک کردن همه','delall')
	if text:match("^[Dd][Ee][Ll][Aa][Ll][Ll]$") and is_owner(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function delall_by_reply(extra, result, success)
	if is_mod(result.sender_user_id_, result.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t Delete Msgs from Moderators!!*', 1, 'md')
else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد پیام مدیران را پاک کنید`', 1, 'md')
end
else
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*All Msgs from * _'..result.sender_user_id_..'_ _Has been deleted!!_', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '_تمامی پیام های ارسالی کاربر با شناسه :_ *'..result.sender_user_id_..'* _حذف شد !_', 1, 'md')
end
		     del_all_msgs(result.chat_id_, result.sender_user_id_)
    end
	end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,delall_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Dd][Ee][Ll][Aa][Ll][Ll] (%d+)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
		local ass = {string.match(text, "^([Dd][Ee][Ll][Aa][Ll][Ll]) (%d+)$")} 
	if is_mod(ass[2], msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t Delete Msgs from Moderators!!*', 1, 'md')
else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد پیام مدیران را پاک کنید`', 1, 'md')
end
else
	 		     del_all_msgs(msg.chat_id_, ass[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*All Msgs from * _'..ass[2]..'* *Has been deleted!!*', 1, 'md')
       else
                send(msg.chat_id_, msg.id_, 1, '_تمامی پیام های ارسالی کاربر با شناسه :_ *'..ass[2]..'* _حذف شد !_', 1, 'md')
end    end
	end
 -----------------------------------------------------------------------------------------------
	if text:match("^[Dd][Ee][Ll][Aa][Ll][Ll] @(.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local apbll = {string.match(text, "^([Dd][Ee][Ll][Aa][Ll][Ll]) @(.*)$")} 
	function delall_by_username(extra, result, success)
	if result.id_ then
	if is_mod(result.id_, msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t Delete Msgs from Moderators!!*', 1, 'md')
else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد پیام مدیران را پاک کنید`', 1, 'md')
end
return false
    end
		 		     del_all_msgs(msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '*All Msg From user* _'..result.id_..'_ *Deleted!*'
          else 
            text = '_تمامی پیام های ارسالی کاربر با شناسه :_ *'..result.id_..'* _حذف شد !_'
end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '*User not found !*'
                else
                  text = '_کاربر یافت نشد !_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	      resolve_username(apbll[2],delall_by_username)
    end
  -----------------------------------------banall--------------------------------------------------
          local text = msg.content_.text_:gsub('بن ال','banall')
          if text:match("^[Bb][Aa][Nn][Aa][Ll][Ll] @(.*)$") and is_sudo(msg) then
            local apbll = {string.match(text, "^([Bb][Aa][Nn][Aa][Ll][Ll]) @(.*)$")}
            function banall_by_username(extra, result, success)
	if result.id_ then
    if database:sismember('bot:gbanned:', result.id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*User* _'..result.id_..'_ *is Already Banned all.*', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '`کاربر` *'..result.id_..'* _از قبل مسدود بوده_', 1, 'md')
end
                                   chat_kick(msg.chat_id_, result.id_)
	else
         database:sadd('bot:gbanned:', result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*User* _'..result.id_..'_ *Banall Groups*', 1, 'md')
       else
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.id_..'* _از تمام گروه های ربات مسدود شد_', 1, 'md')
end
                                   chat_kick(msg.chat_id_, result.id_)
                                   end
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                  texts = '*User not found !*'
                else 
                                    texts = '_کاربر یافت نشد !_'
end
end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
end
            resolve_username(apbll[2],banall_by_username)
          end

          if text:match("^[Bb][Aa][Nn][Aa][Ll][Ll] (%d+)$") and is_sudo(msg) then
            local apbll = {string.match(text, "^([Bb][Aa][Nn][Aa][Ll][Ll]) (%d+)$")}
            if not database:sismember("botadmins:", apbll[2]) or sudo_users == result.sender_user_id_ then
	         	database:sadd('bot:gbanned:', apbll[2])
              chat_kick(msg.chat_id_, apbll[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
                text = '*User * _'..apbll[2]..'_ *Has been Globally Banned !*'
              else 
                                send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..apbll[2]..'* _از تمام گروه های ربات مسدود شد!_', 1, 'md')
end
          else
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '*User not found !*'
                else
                  text = '_کاربر یافت نشد !_'
end
end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
            end

          if text:match("^[Bb][Aa][Nn][Aa][Ll][Ll]$") and is_sudo(msg) then
            function banall_by_reply(extra, result, success)
                database:sadd('bot:gbanned:', result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '*User * '..get_info(result.sender_user_id_)..' *Has been Globally Banned !*'
                else
                                    text = '_کاربر با شناسه :_ '..get_info(result.sender_user_id_)..' _از تمام گروه ها مسدود شد_'
end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
                chat_kick(result.chat_id_, result.id_)
              end
            tdcli.getMessage(msg.chat_id_, msg.reply_to_message_id_,banall_by_reply)
          end
  -----------------------------------------unbanall------------------------------------------------
          local text = msg.content_.text_:gsub('ان بن ال','unbanall')
          if text:match("^[Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll] @(.*)$") and is_sudo(msg) then
            local apbll = {string.match(text, "^([Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll]) @(.*)$")}
            function unbanall_by_username(extra, result, success)
              if result.id_ then
                database:srem('bot:gbanned:', result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '_User_ '..get_info(result.id_)..' *Has been Globally Unbanned !*'
                else 
                  text = '_کاربر با شناسه :_ '..get_info(result.id_)..' _از تمامی گروه های مسدود شده ازاد شد!_'
end
              else
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '*User not found!*'
                else 
                 text = '_کاربر یافت نشد_'
end
              end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
            end
            resolve_username(apbll[2],unbanall_by_username)
          end

          if text:match("^[Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll] (%d+)$") and is_sudo(msg) then
            local apbll = {string.match(text, "^([Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll]) (%d+)$")}
            if apbll[2] then
                database:srem('bot:gbanned:', apbll[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
              text = '*User * '..(apbll[2])..' *Has been Globally Unbanned !*'
            else 
              text = '_کاربر با شناسه :_  '..(apbll[2])..' _از تمامی گروه های مسدود شده ازاد شد!_'
end
            else
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '*User not found!*'
                else 
                  text = '_کاربر یافت نشد_'
end
              end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
          end

          if text:match("^[Uu][Nn][Bb][Aa][Nn][Aa][Ll][Ll]$") and is_sudo(msg) and msg.reply_to_message_id_ then
            function unbanall_by_reply(extra, result, success)
              if not database:sismember('bot:gbanned:', result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '*User* '..get_info(result.sender_user_id_)..' *is Not Globally Banned !*'
                else
                  text = '_کاربر با شناسه :_ '..get_info(result.sender_user_id_)..' _از تمامی گروه های مسدود نبوده!_'
              end
                  else
             database:srem('bot:gbanned:', result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
                  text = '*User* '..get_info(result.sender_user_id_)..' <b>Has been Globally Unbanned !</b>'
             else
                  text = '_کاربر با شناسه :_ '..get_info(result.sender_user_id_)..' _از تمامی گروه های مسدود شده ازاد شد!_'
            end
                  end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
              end
            getMessage(msg.chat_id_, msg.reply_to_message_id_,unbanall_by_reply)
          end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('سکوت','silent')
	if text:match("^[Ss][Ii][Ll][Ee][Nn][Tt]$") and is_mod(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function mute_by_reply(extra, result, success)
	local hash = 'bot:muted:'..msg.chat_id_
	if is_mod(result.sender_user_id_, result.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/silent] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد مديران را سایلنت کنید`', 1, 'md')
end
    else
    if database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *is Already silent.*', 1, 'md')
else 
          send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _هم اکنون بی صدا است !_', 1, 'md')
end
	else
         database:sadd(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _silent_', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _سایلنت شد_', 1, 'md')
end
	end
    end
	end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,mute_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ii][Ll][Ee][Nn][Tt] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apsi = {string.match(text, "^([Ss][Ii][Ll][Ee][Nn][Tt]) @(.*)$")} 
	function mute_by_username(extra, result, success)
	if result.id_ then
	if is_mod(result.id_, msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/silent] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد مديران را سایلنت کنید`', 1, 'md')
end
    else
	        database:sadd('bot:muted:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User* _'..result.id_..'_ *silent*'
          else 
            texts = '_کاربر با شناسه :_ *'..result.id_..'* _سایلنت شد !_'
end
		 chat_kick(msg.chat_id_, result.id_)
	end
          else 
              if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User not found!*'
          else 
                        texts = '_کاربر یافت نشد_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(apsi[2],mute_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ii][Ll][Ee][Nn][Tt] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apsi = {string.match(text, "^([Ss][Ii][Ll][Ee][Nn][Tt]) (%d+)$")}
	if is_mod(apsi[2], msg.chat_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick/silent] Moderators!!*', 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`شما نميتوانيد مديران را سایلنت کنید`', 1, 'md')
end
    else
	        database:sadd('bot:muted:'..msg.chat_id_, apsi[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '*User* _'..apsi[2]..'_ *silent*', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..apsi[2]..'* _سایلنت شد !_', 1, 'md')
end
	end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('لغو سکوت','unsilent')
	if text:match("^[Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt]$") and is_mod(msg.sender_user_id_, msg.chat_id_) and msg.reply_to_message_id_ then
	function unmute_by_reply(extra, result, success)
	local hash = 'bot:muted:'..msg.chat_id_
	if not database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is not silent._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_  *'..result.sender_user_id_..'* _از قبل در لیست سکوت نبوده_', 1, 'md')
end
	else
         database:srem(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _unsilent_', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_  *'..result.sender_user_id_..'* _از سایلنت خارج شد_ ', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,unmute_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apsi = {string.match(text, "^([Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt]) @(.*)$")} 
	function unmute_by_username(extra, result, success)
	if result.id_ then
         database:srem('bot:muted:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User* _'..result.id_..'_ *unsilent*'
          else 
            text = '_کاربر با شناسه :_ *'..result.id_..'* _از لیست سایلنت خارج شد!_'
end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            text = '*User not found!*'
          else 
                        text = '_کاربر یافت نشد_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	      resolve_username(apsi[2],unmute_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local apsi = {string.match(text, "^([Uu][Nn][Ss][Ii][Ll][Ee][Nn][Tt]) (%d+)$")} 	
	        database:srem('bot:muted:'..msg.chat_id_, apsi[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '*User* _'..apsi[2]..'_ *unsilent*', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..apsi[2]..'* _از لیست سایلنت خارج شد!_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('تنظیم مالک','setowner')
	if text:match("^[Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr]$") and is_admin(msg.sender_user_id_) and msg.reply_to_message_id_ then
	function setowner_by_reply(extra, result, success)
	local hash = 'bot:owners:'..msg.chat_id_
	if database:sismember(hash, result.sender_user_id_) then
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*User* *'..result.sender_user_id_..'* *is Already Owner.*', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _از قبل مالک گروه بوده_', 1, 'md')
end
	else
         database:sadd(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *Promoted as Group Owner.*', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _به مالک گروه ارتقا یافت_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,setowner_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr] @(.*)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local apow = {string.match(text, "^([Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr]) @(.*)$")} 
	function setowner_by_username(extra, result, success)
	if result.id_ then
	        database:sadd('bot:owners:'..msg.chat_id_, result.id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User* _'..result.id_..'_ *Promoted as Group Owner.*'
          else 
                        texts = '_کاربر با شناسه :_ *'..result.id_..'* _به مالک گروه ارتقا یافت_'
end
          else 
                  if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User not found!*'
          else 
                        texts = '_کاربر یافت نشد_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(apowmd[2],setowner_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr] (%d+)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local apow = {string.match(text, "^([Ss][Ee][Tt][Oo][Ww][Nn][Ee][Rr]) (%d+)$")} 	
	        database:sadd('bot:owners:'..msg.chat_id_, apow[2])
                  if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '*User* _'..apow[2]..'_ *Promoted as Group Owner.*', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..apow[2]..'* _به مالک گروه ارتقا یافت_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('حذف مالک','remowner')
	if text:match("^[Rr][Ee][Mm][Oo][Ww][Nn][Ee][Rr]$") and is_admin(msg.sender_user_id_) and msg.reply_to_message_id_ then
	function deowner_by_reply(extra, result, success)
	local hash = 'bot:owners:'..msg.chat_id_
	if not database:sismember(hash, result.sender_user_id_) then
	     if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _is not Owner._', 1, 'md')
    else 
               send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _مالک گروه نیست_', 1, 'md')
end
	else
         database:srem(hash, result.sender_user_id_)
                  if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_User_ *'..result.sender_user_id_..'* _Removed from ownerlist._', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..result.sender_user_id_..'* _عزل مقام شد_', 1, 'md')
end
	end
    end
	      getMessage(msg.chat_id_, msg.reply_to_message_id_,deowner_by_reply)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Mm][Oo][Ww][Nn][Ee][Rr] @(.*)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local apow = {string.match(text, "^([Rr][Ee][Mm][Oo][Ww][Nn][Ee][Rr]) @(.*)$")} 
	local hash = 'bot:owners:'..msg.chat_id_
	function remowner_by_username(extra, result, success)
	if result.id_ then
         database:srem(hash, result.id_)
	     if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User* _'..result.id_..'_ *Removed from ownerlist*'
     else 
                   texts = '_کاربر با شناسه :_ *'..result.id_..'* _عزل مقام شد_'
end
          else 
	     if database:get('lang:gp:'..msg.chat_id_) then
            texts = '*User not found!*'
          else 
                        texts = '_کاربر یافت نشد_'
end
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(apow[2],remowner_by_username)
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Rr][Ee][Mm][Aa][Dd][Mm][Ii][Nn] (%d+)$") and is_sudo(msg) then
	local hash = 'bot:admins:'
	local apow = {string.match(text, "^([Rr][Ee][Mm][Aa][Dd][Mm][Ii][Nn]) (%d+)$")} 	
         database:srem(hash, apow[2])
		     if database:get('lang:gp:'..msg.chat_id_) then
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..apow[2]..'* Removed from Admins!_', 1, 'md')
else 
  	send(msg.chat_id_, msg.id_, 1, '_کاربر با شناسه :_ *'..apow[2]..'* _از ادمینی ربات برکنار شد_', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Mm][Oo][Dd][Ll][Ii][Ss][Tt]$") or text:match("^لیست مدیران") and is_mod(msg.sender_user_id_, msg.chat_id_) then
    local hash =  'bot:mods:'..msg.chat_id_
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "*Mod List :*\n\n"
else 
  text = "_لیست مدیران :_\n\n"
  end
	for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "*Mod List is empty !*"
              else 
                text = "_مدیری برای ربات مشخص نشده_"
end
    end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
  end

	if text:match("^[Ff][Ii][Ll][Tt][Ee][Rr][Ll][Ii][Ss][Tt]$") or text:match("^لیست فیلترها$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local hash = 'bot:filters:'..msg.chat_id_
      if hash then
         local names = database:hkeys(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "*Filter List :*\n\n"
else 
  text = "_لیست فیلتر کلمات  :_\n\n"
  end    for i=1, #names do
      text = text..'> `'..names[i]..'`\n'
    end
	if #names == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "*Filter List is empty !*"
              else 
                text = "_لیست فیلتر مشخص نشده_"
end
    end
		  send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
       end
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ii][Ll][Ee][Nn][Tt][Ll][Ii][Ss][Tt]$") or text:match("^سایلنت لیست") and is_mod(msg.sender_user_id_, msg.chat_id_) then
    local hash =  'bot:muted:'..msg.chat_id_
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "*Silent List:*\n\n"
else 
  text = "_لیست سکوت :_\n\n"
end	
for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "*Mod List is empty !*"
              else 
                text = "_لیست سکوت مشخص نشده_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Oo][Ww][Nn][Ee][Rr][Ss]$") or text:match("^[Oo][Ww][Nn][Ee][Rr][Ll][Ii][Ss][Tt]$") or text:match("^لیست مالکان$") and is_sudo(msg) then
    local hash =  'bot:owners:'..msg.chat_id_
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "*owner List:*\n\n"
else 
  text = "_لیست مالکان :_\n\n"
end	
for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "*owner List is empty !*"
              else 
                text = "_لیست مدیران خالی است_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Bb][Aa][Nn][Ll][Ii][Ss][Tt]$") or text:match("^بن لیست$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
    local hash =  'bot:banned:'..msg.chat_id_
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "*ban List:*\n\n"
else 
  text = "_لیست بن :_\n\n"
end	
for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "*ban List is empty !*"
              else 
                text = "_لیست بن خالی است_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
end

  if msg.content_.text_:match("^[Gg][Bb][Aa][Nn][Ll][Ii][Ss][Tt]$") or msg.content_.text_:match("^بن ال لیست$") and is_sudo(msg) then
    local hash =  'bot:gbanned:'
    local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "*Gban List:*\n\n"
else 
  text = "_بن ال لیست :_\n\n"
end	
for k,v in pairs(list) do
    local user_info = database:hgetall('user:'..v)
    if user_info and user_info.username then
    local username = user_info.username
      text = text..k.." - @"..username.." ["..v.."]\n"
      else
      text = text..k.." - "..v.."\n"
          end
end
            if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "*Gban List is empty !*"
              else 
                text = "_لیست بن ال خالی است_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
          end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Aa][Dd][Mm][Ii][Nn][Ll][Ii][Ss][Tt]$") or text:match("^لیست ادمین$") and is_sudo(msg) then
    local hash =  'bot:admins:'
	local list = database:smembers(hash)
  if database:get('lang:gp:'..msg.chat_id_) then
  text = "*Admin List:*\n\n"
else 
  text = "_ادمین لیست :_\n\n"
end	
for k,v in pairs(list) do
	local user_info = database:hgetall('user:'..v)
		if user_info and user_info.username then
			local username = user_info.username
			text = text..k.." - @"..username.." ["..v.."]\n"
		else
			text = text..k.." - "..v.."\n"
		end
	end
	if #list == 0 then
	   if database:get('lang:gp:'..msg.chat_id_) then
                text = "*Admin List is empty !*"
              else 
                text = "_لیست ادمین خالی است_"
end
end
	send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
    end
	-----------------------------------------------------------------------------------------------
    if text:match("^[Ii][Dd]$") or text:match("^ایدی$") and msg.reply_to_message_id_ ~= 0 then
      function id_by_reply(extra, result, success)
	  local user_msgs = database:get('user:msgs'..result.chat_id_..':'..result.sender_user_id_)
        send(msg.chat_id_, msg.id_, 1, "`"..result.sender_user_id_.."`", 1, 'md')
        end
   getMessage(msg.chat_id_, msg.reply_to_message_id_,id_by_reply)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('ایدی','id')
    if text:match("^[Ii][Dd] @(.*)$") then
	local ap = {string.match(text, "^([Ii][Dd]) @(.*)$")} 
	function id_by_username(extra, result, success)
	if result.id_ then
            texts = '`'..result.id_..'`'
            else 
            texts = '_User not found!_'
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],id_by_username)
    end
    
    if text:match("^[Rr][Ee][Ss] @(.*)$") then
	local ap = {string.match(text, "^([Rr][Ee][Ss]) @(.*)$")} 
	function id_by_username(extra, result, success)
	if result.id_ then 
            texts = '*Username* : @'..ap[2]..'\n*ID* : `'..result.id_..'`'
            else 
            texts = '*User not found!*'
    end
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md')
    end
	      resolve_username(ap[2],id_by_username)
    end
    -----------------------------------------------------------------------------------------------
  if text:match("^[Kk][Ii][Cc][Kk]$") or text:match("^اخراج$") and msg.reply_to_message_id_ and is_mod(msg.sender_user_id_, msg.chat_id_) then
      function kick_reply(extra, result, success)
	if is_mod(result.sender_user_id_, result.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick] Moderators!!*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '_شمانمیتوانید مدیران را اخراج کنید!_', 1, 'md')
end
  else
                if database:get('lang:gp:'..msg.chat_id_) then
        send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *Kicked.*', 1, 'md')
      else 
        send(msg.chat_id_, msg.id_, 1, '_کاربر باشناسه :_ *'..result.sender_user_id_..'* _اخراج شد_', 1, 'md')
end
        chat_kick(result.chat_id_, result.sender_user_id_)
        end
	end
   getMessage(msg.chat_id_,msg.reply_to_message_id_,kick_reply)
  end
    -----------------------------------------------------------------------------------------------
         if text:match("^[Kk][Ii][Cc][Kk] @(.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then 
        	local apki = {string.match(text, "^([Kk][Ii][Cc][Kk]) @(.*)$")}  
          	function kick_by_username(extra, result, success) 
	if result.id_ then 
	if is_mod(result.id_, msg.chat_id_) then 
                  if database:get('lang:gp:'..msg.chat_id_) then 
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick] Moderators!!*', 1, 'md') 
       else 
          send(msg.chat_id_, msg.id_, 1, '_شمانمیتوانید مدیران را اخراج کنید!_', 1, 'md') 
end 
    else 
                  if database:get('lang:gp:'..msg.chat_id_) then 
            texts = '*User* _'..result.id_..'_ *Kicked.!*' 
     else 
                        texts = '_کاربر باشناسه :_ *'..result.id_..'* _اخراج شد_' 
end 
		 chat_kick(msg.chat_id_, result.id_) 
	end 
          else  
                  if database:get('lang:gp:'..msg.chat_id_) then 
            texts = '*User not found!*' 
          else 
                       texts = '_کاربر یافت نشد_' 
             end 
    end 
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'html') 
    end 
	      resolve_username(apki[2],kick_by_username) 
    end 
	----------------------------------------------------------------------------------------------- 
	if text:match("^[Kk][Ii][Cc][Kk] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then 
	local apki = {string.match(text, "^([Kk][Ii][Cc][Kk]) (%d+)$")} 
	if is_mod(apki[2], msg.chat_id_) then 
                  if database:get('lang:gp:'..msg.chat_id_) then 
         send(msg.chat_id_, msg.id_, 1, '*You Can,t [Kick] Moderators!!*', 1, 'md') 
       else 
          send(msg.chat_id_, msg.id_, 1, '_شمانمیتوانید مدیران را اخراج کنید!_', 1, 'md') 
        end 
    else 
		 chat_kick(msg.chat_id_, apki[2]) 
                 if database:get('lang:gp:'..msg.chat_id_) then 
	send(msg.chat_id_, msg.id_, 1, '_User_ *'..apki[2]..'* _Kicked._', 1, 'md') 
else 
    send(msg.chat_id_, msg.id_, 1, '_کاربر باشناسه :_ *'..apki[2]..'* `اخراج شد` ⚠️', 1, 'md') 
  	end 
	end 
end 
          ----------------------------------------------------------------------------------------------- 
          local text = msg.content_.text_:gsub('اضافه','invite') 
         if text:match("^[Ii][Nn][Vv][Ii][Tt][Ee]$") and msg.reply_to_message_id_ ~= 0 and is_sudo(msg) then 
          function inv_reply(extra, result, success) 
   add_user(result.chat_id_, result.sender_user_id_, 5) 
                if database:get('lang:gp:'..msg.chat_id_) then 
        send(msg.chat_id_, msg.id_, 1, '*User* _'..result.sender_user_id_..'_ *Add it.*', 1, 'md') 
      else  
        send(msg.chat_id_, msg.id_, 1, '_کاربر باشناسه :_ '..result.sender_user_id_..' `به گروه اضافه شد`', 1, 'md') 
  end 
   end 
    getMessage(msg.chat_id_, msg.reply_to_message_id_,inv_reply)
end	
          ----------------------------------------------------------------------------------------------- 
   if text:match("^[Ii][Nn][Vv][Ii][Tt][Ee] @(.*)$") and is_sudo(msg) then 
    local apss = {string.match(text, "^([Ii][Nn][Vv][Ii][Tt][Ee]) @(.*)$")} 
    function invite_by_username(extra, result, success) 
    if result.id_ then 
                  if database:get('lang:gp:'..msg.chat_id_) then 
            texts = '*User* _'..result.id_..'_ *Add it!*' 
else 
            texts = '_کاربر باشناسه :_ *'..result.id_..'* _به گروه اضافه شد_' 
end 
    add_user(msg.chat_id_, result.id_, 5) 
         else  
                 if database:get('lang:gp:'..msg.chat_id_) then 
            texts = '*User not found!*' 
         else 
           texts = '_کاربر یافت نشد_'
           end 
    end 
	         send(msg.chat_id_, msg.id_, 1, texts, 1, 'md') 
   end 
   resolve_username(apss[2],invite_by_username) 
          end 
        ----------------------------------------------------------------------------------------------- 
         if text:match("^[Ii][Nn][Vv][Ii][Tt][Ee] (%d+)$") and is_sudo(msg) then 
         local apee = {string.match(text, "^([Ii][Nn][Vv][Ii][Tt][Ee]) (%d+)$")} 
      add_user(msg.chat_id_, ap[2], 5) 
                if database:get('lang:gp:'..msg.chat_id_) then 
      send(msg.chat_id_, msg.id_, 1, '_User_ *'..apee[2]..'* _Add it._', 1, 'md') 
	  
        else 
        send(msg.chat_id_, msg.id_, 1, '_کاربر باشناسه :_ *'..apee[2]..'* _به گروه اضافه شد_', 1, 'md') 
end 
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('عکس پروفایل','getpro')
    if text:match("^getpro (%d+)$") and msg.reply_to_message_id_ == 0  then
		local pronumb = {string.match(text, "^(getpro) (%d+)$")} 
local function gpro(extra, result, success)
--vardump(result)
   if pronumb[2] == '1' then
   if result.photos_[0] then
      sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[0].sizes_[1].photo_.persistent_id_)
   else
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '2' then
                if result.photos_[1] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[1].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have 2 profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 2 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '3' then
                if result.photos_[2] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[2].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have 3 profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 3 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '4' then
                if result.photos_[3] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[3].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have 4 profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 4 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '5' then
                if result.photos_[4] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[4].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't 5 have profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 5 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '6' then
                if result.photos_[5] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[5].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have 6 profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 6 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '7' then
                if result.photos_[6] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[6].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have 7 profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 7 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '8' then
                if result.photos_[7] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[7].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have 8 profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 8 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '9' then
                if result.photos_[8] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[8].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have 9 profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 9 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              elseif pronumb[2] == '10' then
                if result.photos_[9] then
                  sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[9].sizes_[1].photo_.persistent_id_)
                else
                  if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "*You don't have 10 profile photo !*", 1, 'md')
                  else
                    send(msg.chat_id_, msg.id_, 1, "_شما 10 عکس پروفایل ندارید_", 1, 'md')
                  end
                end
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, "*I just can get last 10 profile photos !*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, "_من فقط میتوانم  10 عکس آخر را نمایش دهم !_", 1, 'md')
                end
   end
   end
   tdcli_function ({
    ID = "GetUserProfilePhotos",
    user_id_ = msg.sender_user_id_,
    offset_ = 0,
    limit_ = pronumb[2]
  }, gpro, nil)
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ll][Oo][Cc][Kk] (.*)$") or text:match("^قفل (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local lockpt = {string.match(text, "^([Ll][Oo][Cc][Kk]) (.*)$")} 
	local TSHAKEPT = {string.match(text, "^(قفل) (.*)$")} 
    if lockpt[2] == "edit" or TSHAKEPT[2] == "ویرایش" then
              if not database:get('editmsg'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, "_Edit Has been_ *locked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`ویرایش قفل شد`', 1, 'md')
                end
                database:set('editmsg'..msg.chat_id_,'delmsg')
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Lock edit is already_ *locked*', 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`ویرایش از قبل قفل بوده`', 1, 'md')
                end
              end
            end
   if lockpt[2] == "bots" or TSHAKEPT[2] == "ربات" then
              if not database:get('bot:bots:mute'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, "_Bots Has been_ *locked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`ورود ربات قفل شد`', 1, 'md')
                end
                database:set('bot:bots:mute'..msg.chat_id_,true)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                 send(msg.chat_id_, msg.id_, 1, "_Bots is Already_ *locked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`ورود ربات از قبل قفل بوده`', 1, 'md')
                end
              end
            end
           if lockpt[2] == "flood ban" or TSHAKEPT[2] == "بن فلود" then
                if database:get('lang:gp:'..msg.chat_id_) then
             send(msg.chat_id_, msg.id_, 1, '*Flood Ban* has been *locked*', 1, 'md')
             else
                  send(msg.chat_id_, msg.id_, 1, '`بن فلود فعال شد`', 1, 'md')
                database:del('anti-flood:'..msg.chat_id_)
              end
                end
                   if lockpt[2] == "flood mute" or TSHAKEPT[2] == "اخطار فلود" then
                if database:get('lang:gp:'..msg.chat_id_) then
                send(msg.chat_id_, msg.id_, 1, '*Flood warn* has been *locked*', 1, 'md')
                   else
                  send(msg.chat_id_, msg.id_, 1, '`اخطار فلود فعال شد`', 1, 'md')
                 database:del('anti-flood:warn'..msg.chat_id_)
                 end
              end
        if lockpt[2] == "pin" or TSHAKEPT[2] == "سنجاق" and is_owner(msg.sender_user_id_, msg.chat_id_) then
              if not database:get('bot:pin:mute'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                 send(msg.chat_id_, msg.id_, 1, "_Pin Has been_ *locked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`سنجاق قفل شد`', 1, 'md')
                end
                database:set('bot:pin:mute'..msg.chat_id_,true)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                            send(msg.chat_id_, msg.id_, 1, "_Pin is Already_ *locked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`سنجاق از قبل قفل بوده`', 1, 'md')
                end
              end
            end
        if lockpt[2] == "pin warn" or TSHAKEPT[2] == "اخطار پین" and is_owner(msg.sender_user_id_, msg.chat_id_) then
              if not database:get('bot:pin:warn'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                 send(msg.chat_id_, msg.id_, 1, "_Pin warn Has been_ *locked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`اخطارپین فعال شد`', 1, 'md')
                end
                database:set('bot:pin:warn'..msg.chat_id_,true)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                            send(msg.chat_id_, msg.id_, 1, "_Pin warn is Already_ *locked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`اخطار پین از قبل فعال بوده است`', 1, 'md')
                end
              end
            end
              end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('فلود بن','flood ban')
	if text:match("^[Ff][Ll][Oo][Oo][Dd] [Bb][Aa][Nn] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local floodmax = {string.match(text, "^([Ff][Ll][Oo][Oo][Dd] [Bb][Aa][Nn]) (%d+)$")} 
	if tonumber(floodmax[2]) < 2 then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [2-99999]_', 1, 'md')
else
           send(msg.chat_id_, msg.id_, 1, '`اعدادبین` _[2-99999]_', 1, 'md')
end
	else
    database:set('flood:max:'..msg.chat_id_,floodmax[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Flood has been set to_ *'..floodmax[2]..'*', 1, 'md')
        else
         send(msg.chat_id_, msg.id_, 1, '`فلود بن تنظیم شد روی` *'..floodmax[2]..'*', 1, 'md')
end
	end
end

          local text = msg.content_.text_:gsub('فلود اخطار','flood mute')
	if text:match("^[Ff][Ll][Oo][Oo][Dd] [Mm][Uu][Tt][Ee] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local floodmax = {string.match(text, "^([Ff][Ll][Oo][Oo][Dd] [Mm][Uu][Tt][Ee]) (%d+)$")} 
	if tonumber(floodmax[2]) < 2 then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [2-99999]_', 1, 'md')
       else 
           send(msg.chat_id_, msg.id_, 1, '`اعدادبین` _[2-99999]_', 1, 'md')
end
	else
    database:set('flood:max:warn'..msg.chat_id_,floodmax[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Flood Warn has been set to_ *'..floodmax[2]..'*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`فلود اخطار تنظیم شد روی` *'..floodmax[2]..'*', 1, 'md')
end
	end
end
          local text = msg.content_.text_:gsub('تنظیم اسپم','spam del')
if text:match("^[Ss][Pp][Aa][Mm] [Dd][Ee][Ll] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
local sensspam = {string.match(text, "^([Ss][Pp][Aa][Mm] [Dd][Ee][Ll]) (%d+)$")}
if tonumber(sensspam[2]) < 40 then
                if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [40-99999]_', 1, 'md')
else 
send(msg.chat_id_, msg.id_, 1, '`اعدادبین` _[40-99999]_', 1, 'md')
end
 else
database:set('bot:sens:spam'..msg.chat_id_,sensspam[2])
                if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, '_Spam has been set to_ *'..sensspam[2]..'*', 1, 'md')
else 
send(msg.chat_id_, msg.id_, 1, '`اسپم بن فعال شد روی` *'..sensspam[2]..'*', 1, 'md')
end
end
end
          local text = msg.content_.text_:gsub('اسپم اخطار','spam warn')
if text:match("^[Ss][Pp][Aa][Mm] [Ww][Aa][Rr][Nn] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
local sensspam = {string.match(text, "^([Ss][Pp][Aa][Mm] [Ww][Aa][Rr][Nn]) (%d+)$")}
if tonumber(sensspam[2]) < 40 then
                if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [40-99999]_', 1, 'md')
else 
send(msg.chat_id_, msg.id_, 1, '`اعدادبین` _[40-99999]_', 1, 'md')
end
 else
database:set('bot:sens:spam:warn'..msg.chat_id_,sensspam[2])
                if database:get('lang:gp:'..msg.chat_id_) then
send(msg.chat_id_, msg.id_, 1, '_Spam Warn has been set to_ *'..sensspam[2]..'*', 1, 'md')
else 
send(msg.chat_id_, msg.id_, 1, '`اخطار اسپم روی` *'..sensspam[2]..'* `فعال شد`', 1, 'md')
end
end
end

	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('فلود تایم','flood time')
	if text:match("^[Ff][Ll][Oo][Oo][Dd] [Tt][Ii][Mm][Ee] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local floodt = {string.match(text, "^([Ff][Ll][Oo][Oo][Dd] [Tt][Ii][Mm][Ee]) (%d+)$")} 
	if tonumber(floodt[2]) < 2 then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Wrong number*,_range is  [2-99999]_', 1, 'md')
       else 
           send(msg.chat_id_, msg.id_, 1, '`اعدادبین` _[2-99999]_', 1, 'md')
end
	else
    database:set('flood:time:'..msg.chat_id_,floodt[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> Flood has been set to_ *'..floodt[2]..'*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`فلود تایم تنظیم شد روی` *'..floodt[2]..'*', 1, 'md')
end
	end
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Hh][Oo][Ww] [Ee][Dd][Ii][Tt]$") or text:match("^تشخیص ویرایش$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
         database:set('editmsg'..msg.chat_id_,'didam')
         send(msg.chat_id_, msg.id_, 1, '*Done*\n_Activation detection has been activated_', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '`ویرایش از این به بعد مشخص میشه`', 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Ll][Ii][Nn][Kk]") or text:match("^تنظیم لینک") and is_mod(msg.sender_user_id_, msg.chat_id_) then
         database:set("bot:group:link"..msg.chat_id_, 'Waiting For Link!\nPls Send Group Link')
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Please Send Group Link Now!*', 1, 'md')
else 
         send(msg.chat_id_, msg.id_, 1, '`لطفالینک خود را ارسال کنید`', 1, 'md')
end
	end
	-----------------
	if text:match("^[Ss][Ee][Tt]warn (%d+)$") or text:match("^تنظیم اخطار (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local gettext = {string.match(text, "^([Ss]etwarn) (%d+)$")} 
      local swarn = tonumber(gettext[2])
     if (tonumber(swarn) < 1) or (tonumber(swarn) > 10) then
	 send(msg.chat_id_, msg.id_, 1, 'range is 1 - 10 '..swarn, 1, 'md')
	else
         database:hset("setwarn:"..msg.chat_id_, msg.chat_id_, swarn )
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*warn set to:* '..swarn, 1, 'md')
else 
         send(msg.chat_id_, msg.id_, 1, 'تعداد اخطار: '..swarn, 1, 'md')
end
end
	end
	-------------------
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ll][Ii][Nn][Kk]$") or text:match("^لینک$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local link = database:get("bot:group:link"..msg.chat_id_)
	  if link then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Group link:*\n'..link, 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '_لینک گروه:_\n'..link, 1, 'md')
end
	  else
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*There is not link set yet. Please add one by #setlink .*', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, '`لینک ثبت نشده/ابتدا لینک را با دستورتنظیم لینک ثبت کنید`', 1, 'md')
end
	  end
 	end
		-----------------------------------------------------------------------------------------------

	if is_mod(msg.sender_user_id_, msg.chat_id_) then
          if text:match("^[Ww]elcome on$") or text:match("^خوش امدگویی روشن$") then
            if database:get('lang:gp:'..msg.chat_id_) then
              send(msg.chat_id_, msg.id_, 1, '*Welcome activated !*', 1, 'md')
            else
              send(msg.chat_id_, msg.id_, 1, '_خوش آمد گویی فعال شد !_', 1, 'md')
            end
            database:set("bot:welcome"..msg.chat_id_,true)
          end
          if text:match("^[Ww]elcome off$") or text:match("^خوش امدگویی خاموش") then
            if database:get('lang:gp:'..msg.chat_id_) then
              send(msg.chat_id_, msg.id_, 1, '*Welcome deactivated !*', 1, 'md')
            else
              send(msg.chat_id_, msg.id_, 1, '_خوش آمد گویی غیرفعال شد !_', 1, 'md')
            end
            database:del("bot:welcome"..msg.chat_id_)
          end
          if text:match("^[Ss]et welcome (.*)$") or text:match("^تنظیم متن خوش امدگویی (.*)$") then
            local welcome = {string.match(text, "^([Ss]et welcome) (.*)$")}
            if database:get('lang:gp:'..msg.chat_id_) then
              send(msg.chat_id_, msg.id_, 1, '*Welcome text has been saved !*\n\n_Welcome text :_\n\n'..welcome[2], 1, 'html')
            else
              send(msg.chat_id_, msg.id_, 1, '_پیام خوش آمد گویی ذخیره شد !_\n\n_متن خوش آمد گویی :_\n\n'..welcome[2], 1, 'html')
            end
            database:set('welcome:'..msg.chat_id_,welcome[2])
          end
          if text:match("^[Dd]el welcome$") or text:match("^حذف متن خوش امدگویی$") then
            if database:get('lang:gp:'..msg.chat_id_) then
              send(msg.chat_id_, msg.id_, 1, '*Welcome text has been removed !*', 1, 'md')
            else
              send(msg.chat_id_, msg.id_, 1, '_پیام خوش آمد گویی حذف شد !_', 1, 'md')
            end
            database:del('welcome:'..msg.chat_id_)
          end
          if text:match("^[Gg]et welcome$") or text:match("^دریافت متن خوش امدگویی$") then
            local wel = database:get('welcome:'..msg.chat_id_)
            if wel then
              send(msg.chat_id_, msg.id_, 1, wel, 1, 'md')
            else
              if database:get('lang:gp:'..msg.chat_id_) then
                send(msg.chat_id_, msg.id_, 1, '*Welcome text not found !*', 1, 'md')
              else
                send(msg.chat_id_, msg.id_, 1, '_پیامی در لیست نیست !_', 1, 'md')
              end
            end
          end
        end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('فیلتر','filter')
	if text:match("^[Ff][Ii][Ll][Tt][Ee][Rr] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local filters = {string.match(text, "^([Ff][Ii][Ll][Tt][Ee][Rr]) (.*)$")} 
    local name = string.sub(filters[2], 1, 50)
          database:hset('bot:filters:'..msg.chat_id_, name, 'filtered')
                if database:get('lang:gp:'..msg.chat_id_) then
		  send(msg.chat_id_, msg.id_, 1, "*New Word filtered!*\n--> `"..name.."`", 1, 'md')
else 
  		  send(msg.chat_id_, msg.id_, 1, "`"..name.."` `به لیست کلمات فیلتر اضافه شد`", 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('خروج فیلتر','unfilter')
	if text:match("^[Uu][Nn][Ff][Ii][Ll][Tt][Ee][Rr] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local rws = {string.match(text, "^([Uu][Nn][Ff][Ii][Ll][Tt][Ee][Rr]) (.*)$")} 
    local name = string.sub(rws[2], 1, 50)
          database:hdel('bot:filters:'..msg.chat_id_, rws[2])
                if database:get('lang:gp:'..msg.chat_id_) then
		  send(msg.chat_id_, msg.id_, 1, "`"..rws[2].."` *Removed From filtered List!*", 1, 'md')
else 
  		  send(msg.chat_id_, msg.id_, 1, "`"..rws[2].."` `از لیست کلمات فیلتر حذف شد`", 1, 'md')
end
	end 
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('ارسال به همه','bc')
	if text:match("^[Bb][Cc] (.*)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
    local gps = database:scard("bot:groups") or 0
    local gpss = database:smembers("bot:groups") or 0
	local rws = {string.match(text, "^(bc) (.*)$")} 
	for i=1, #gpss do
		  send(gpss[i], 0, 1, rws[2], 1, 'md')
  end
                if database:get('lang:gp:'..msg.chat_id_) then
                   send(msg.chat_id_, msg.id_, 1, '*Done*\n_Your Msg Send to_ `'..gps..'` _Groups_', 1, 'md')
                   else
                     send(msg.chat_id_, msg.id_, 1, '`ارسال شد متن شما به ` `'..gps..'` `گروه`', 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
	        if text:match("^[Rr][Ee][Ss][Gg][Pp]$") or text:match("^بروزرسانی گروه ها$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
          if database:get('lang:gp:'..msg.chat_id_) then
            send(msg.chat_id_, msg.id_, 1, '*Nubmper of groups bot has been update !*', 1, 'md')
          else
            send(msg.chat_id_, msg.id_, 1, '_تعداد گروه های ربات با موفقیت بروزرسانی گردید !_', 'md')
          end
          database:del("bot:groups")
        end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Gg][Rr][Oo][Uu][Pp][Ss]$") or text:match("^گروه ها$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
    local gps = database:scard("bot:groups")
	local users = database:scard("bot:userss")
    local allmgs = database:get("bot:allmsgs")
                if database:get('lang:gp:'..msg.chat_id_) then
                   send(msg.chat_id_, msg.id_, 1, '*Groups :* `'..gps..'`', 1, 'md')
                 else
                   send(msg.chat_id_, msg.id_, 1, '`تعداد گروه ها :` *'..gps..'*', 1, 'md')
end
	end
	
if  text:match("^[Mm][Ss][Gg]$") or text:match("^پیام ها$") and msg.reply_to_message_id_ == 0  then
local user_msgs = database:get('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "*Msgs : * `"..user_msgs.."`", 1, 'md')
    else 
      send(msg.chat_id_, msg.id_, 1, "`تعداد پیام ها :` *"..user_msgs.."*", 1, 'md')
end
	end
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Uu][Nn][Ll][Oo][Cc][Kk] (.*)$") or text:match("^باز کردن (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local unlockpt = {string.match(text, "^([Uu][Nn][Ll][Oo][Cc][Kk]) (.*)$")} 
	local TSHAKEUN = {string.match(text, "^(باز کردن) (.*)$")} 
                if unlockpt[2] == "edit" or TSHAKEUN[2] == "ویرایش" then
              if database:get('editmsg'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_Edit Has been_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`ویرایش باز شد`', 1, 'md')
                end
                database:del('editmsg'..msg.chat_id_)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Lock edit is already_ *Unlocked*', 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`ویرایش از قبل باز بوده`', 1, 'md')
                end
              end
            end
                if unlockpt[2] == "bots" or TSHAKEUN[2] == "ربات" then
              if database:get('bot:bots:mute'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_Bots Has been_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`ورود ربات باز شد`', 1, 'md')
                end
                database:del('bot:bots:mute'..msg.chat_id_)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_Bots is Already_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, '`ورود ربات از قبل باز بوده`', 1, 'md')
                end
              end
            end
	              if unlockpt[2] == "flood ban" or TSHAKEUN[2] == "بن فلود" then
                if database:get('lang:gp:'..msg.chat_id_) then
                   send(msg.chat_id_, msg.id_, 1, '*Flood Ban* has been *unlocked*', 1, 'md')
                 else
                  send(msg.chat_id_, msg.id_, 1, '`بن فلود باز شد`', 1, 'md')
                   database:set('anti-flood:'..msg.chat_id_,true)
            	  end
            	  end
            	  if unlockpt[2] == "flood mute" or TSHAKEUN[2] == "اخطار فلود" then
                if database:get('lang:gp:'..msg.chat_id_) then
                   send(msg.chat_id_, msg.id_, 1, '*Flood warn* has been *unlocked*', 1, 'md')
                 else
                  send(msg.chat_id_, msg.id_, 1, '`اخطار فلود باز شد`', 1, 'md')
                   database:set('anti-flood:warn'..msg.chat_id_,true)
             	  end
             	  end
                if unlockpt[2] == "pin" or TSHAKEUN[2] == "سنجاق" and is_owner(msg.sender_user_id_, msg.chat_id_) then
              if database:get('bot:pin:mute'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_Pin Has been_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, "`سنجاق باز شد`", 1, 'md')
                end
                database:del('bot:pin:mute'..msg.chat_id_)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_Pin is Already_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, "`سنجاق از قبل باز بوده`", 1, 'md')
                end
              end
            end
                if unlockpt[2] == "pin warn" or TSHAKEUN[2] == "اخطار سنجاق" and is_owner(msg.sender_user_id_, msg.chat_id_) then
              if database:get('bot:pin:warn'..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_Pin warn Has been_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, "`اخطار سنجاق باز شد`", 1, 'md')
                end
                database:del('bot:pin:warn'..msg.chat_id_)
              else
                if database:get('lang:gp:'..msg.chat_id_) then
                    send(msg.chat_id_, msg.id_, 1, "_Pin warn is Already_ *Unlocked*", 1, 'md')
                else
                  send(msg.chat_id_, msg.id_, 1, "`اخطار سنجاق از قبل باز بوده`", 1, 'md')
                end
              end
            end
              end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('قفل همه ثانیه','lock all s')
  	if text:match("^[Ll][Oo][Cc][Kk] [Aa][Ll][Ll] [Ss] (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local mutept = {string.match(text, "^[Ll][Oo][Cc][Kk] [Aa][Ll][Ll] [Ss] (%d+)$")}
	    		database:setex('bot:muteall'..msg.chat_id_, tonumber(mutept[1]), true)
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Group muted for_ *'..mutept[1]..'* _seconds!_', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '` گروه قفل شد به مدت` *'..mutept[1]..'* `ثانيه`', 1, 'md')
end
	end

          local text = msg.content_.text_:gsub('قفل همه ساعت','lock all h')
    if text:match("^[Ll][Oo][Cc][Kk] [Aa][Ll][Ll] [Hh]  (%d+)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
        local mutept = {string.match(text, "^[Ll][Oo][Cc][Kk] [Aa][Ll][Ll] [Hh] (%d+)$")}
        local hour = string.gsub(mutept[1], 'h', '')
        local num1 = tonumber(hour) * 3600
        local num = tonumber(num1)
            database:setex('bot:muteall'..msg.chat_id_, num, true)
                if database:get('lang:gp:'..msg.chat_id_) then
              send(msg.chat_id_, msg.id_, 1, "*Lock all has been enable for* _"..mutept[1].."_ *hours !*", 'md')
       else 
              send(msg.chat_id_, msg.id_, 1, "`گروه قفل شد به مدت` *"..mutept[1].."* `بالساعه`", 'md')
end
     end
		-----------------------------------------------------------------------------------------------
  	if text:match("^[Ll][Oo][Cc][Kk] (.*)$") or text:match("^قفل (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local mutept = {string.match(text, "^([Ll][Oo][Cc][Kk]) (.*)$")} 
	local TSHAKE = {string.match(text, "^(قفل) (.*)$")} 
      if mutept[2] == "all" or TSHAKE[2] == "همه" then
	  if not database:get('bot:muteall'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_mute all has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل همه فعال شد`', 1, 'md')
      end
         database:set('bot:muteall'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_mute all is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل همه از قبل فعال بوده`', 1, 'md')
      end
      end
      end
      if mutept[2] == "all warn" or TSHAKE[2] == "اخطار همه" then
	  if not database:get('bot:muteallwarn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_mute all warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار همه فعال شد`', 1, 'md')
      end
         database:set('bot:muteallwarn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_mute all warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار همه از قبل فعال بوده`', 1, 'md')
      end
      end
      end
      if mutept[2] == "all ban" or TSHAKE[2] == "بن همه" then
	  if not database:get('bot:muteallban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_mute all ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن همه فعال شد`', 1, 'md')
      end
         database:set('bot:muteallban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_mute all ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن همه از قبل فعال بوده`', 1, 'md')
      end
      end
      end
      if mutept[2] == "text" or TSHAKE[2] == "متن" then
	  if not database:get('bot:text:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Text has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `قفل متن فعال شد`', 1, 'md')
      end
         database:set('bot:text:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Text is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `قفل متن از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "text ban" or TSHAKE[2] == "بن متن" then
	  if not database:get('bot:text:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Text ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `بن متن فعال شد`', 1, 'md')
      end
         database:set('bot:text:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Text ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `بن متن از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "text warn" or TSHAKE[2] == "اخطار متن" then
	  if not database:get('bot:text:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Text warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار متن فعال شد`', 1, 'md')
      end
         database:set('bot:text:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Text warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `اخطار متن از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "inline" or TSHAKE[2] == "اینلاین" then
	  if not database:get('bot:inline:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_inline has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `قفل دکمه شیشه ای فعال شد`', 1, 'md')
      end
         database:set('bot:inline:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_inline is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `قفل دکمه شیشه ای از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "inline ban" or TSHAKE[2] == "بن اینلاین" then
	  if not database:get('bot:inline:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_inline ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `بن دکمه شیشه ای فعال شد`', 1, 'md')
      end
         database:set('bot:inline:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_inline ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن دکمه شیشه ای از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "inline warn" or TSHAKE[2] == "اخطار اینلاین" then
	  if not database:get('bot:inline:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_inline warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `اخطار دکمه شیشه ای فعال شد`', 1, 'md')
      end
         database:set('bot:inline:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_inline warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `اخطار دکمه شیشه ای از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "photo" or TSHAKE[2] == "عکس" then
	  if not database:get('bot:photo:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_photo has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `عکس قفل شد`', 1, 'md')
      end
         database:set('bot:photo:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_photo is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `عکس از قبل قفل بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "photo ban" or TSHAKE[2] == "بن عکس" then
	  if not database:get('bot:photo:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_photo ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `بن عکس فعال شد`', 1, 'md')
      end
         database:set('bot:photo:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_photo ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `بن عکس از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "photo warn" or TSHAKE[2] == "اخطار عکس" then
	  if not database:get('bot:photo:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_photo warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `اخطار عکس فعال شد`', 1, 'md')
      end
         database:set('bot:photo:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_photo warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `اخطار عکس از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "video" or TSHAKE[2] == "ویدیو" then
	  if not database:get('bot:video:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_video has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `ویدیو قفل شد`', 1, 'md')
      end
         database:set('bot:video:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_video is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `ویدیو از قبل قفل بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "video ban" or TSHAKE[2] == "بن ویدیو" then
	  if not database:get('bot:video:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_video ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `بن ویدیو فعال شد`', 1, 'md')
      end
         database:set('bot:video:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_video ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `بن ویدیو از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "video warn" or TSHAKE[2] == "اخطار ویدیو" then
	  if not database:get('bot:video:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_video warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `اخطار ویدیو فعال شد`', 1, 'md')
      end
         database:set('bot:video:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_video warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `اخطار ویدیو از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "gif" or TSHAKE[2] == "گیف" then
	  if not database:get('bot:gifs:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_gifs has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `قفل گیف فعال شد`', 1, 'md')
      end
         database:set('bot:gifs:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_gifs is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `قفل گیف از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "gif ban" or TSHAKE[2] == "بن گیف" then
	  if not database:get('bot:gifs:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_gifs ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `بن گیف فعال شد`', 1, 'md')
      end
         database:set('bot:gifs:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_gifs ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `بن گیف از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "gif warn" or TSHAKE[2] == "اخطار گیف" then
	  if not database:get('bot:gifs:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_gifs warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `اخطار گیف فعال شد`', 1, 'md')
      end
         database:set('bot:gifs:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_gifs warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `اخطار گیف از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "music" or TSHAKE[2] == "اهنگ" then
	  if not database:get('bot:music:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_music has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `قفل اهنگ فعال شد`', 1, 'md')
      end
         database:set('bot:music:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_music is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `قفل اهنگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "music ban" or TSHAKE[2] == "بن اهنگ" then
	  if not database:get('bot:music:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_music ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `بن اهنگ فعال شد`', 1, 'md')
      end
         database:set('bot:music:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_music ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `بن اهنگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "music warn" or TSHAKE[2] == "اخطار اهنگ" then
	  if not database:get('bot:music:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Text warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `اخطار اهنگ فعال شد`', 1, 'md')
      end
         database:set('bot:music:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Text warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `اخطار اهنگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "voice" or TSHAKE[2] == "صدا" then
	  if not database:get('bot:voice:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_voice has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل صدا فعال شد`', 1, 'md')
      end
         database:set('bot:voice:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_voice is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل صدا از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "voice ban" or TSHAKE[2] == "بن صدا" then
	  if not database:get('bot:voice:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_voice ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن صدا فعال شد`', 1, 'md')
      end
         database:set('bot:voice:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_voice ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن صدا از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "voice warn" or TSHAKE[2] == "اخطار صدا" then
	  if not database:get('bot:voice:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_voice warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار صدا فعال شد`', 1, 'md')
      end
         database:set('bot:voice:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_voice warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار صدا از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "links" or TSHAKE[2] == "لینک" then
	  if not database:get('bot:links:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_links has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل لینک فعال شد`', 1, 'md')
      end
         database:set('bot:links:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_links is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل لینک از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "links ban" or TSHAKE[2] == "بن لینک" then
	  if not database:get('bot:links:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_links ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن لینک فعال شد`', 1, 'md')
      end
         database:set('bot:links:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_links ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن لینک از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "links warn" or TSHAKE[2] == "اخطار لینک" then
	  if not database:get('bot:links:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_links warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار لینک فعال شد`', 1, 'md')
      end
         database:set('bot:links:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_links warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار لینک از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "location" or TSHAKE[2] == "موقعیت" then
	  if not database:get('bot:location:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_location has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل موقعیت فعال شد`', 1, 'md')
      end
         database:set('bot:location:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_location is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل موقعیت از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "location ban" or TSHAKE[2] == "بن موقعیت" then
	  if not database:get('bot:location:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_location ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن موقعیت فعال شد`', 1, 'md')
      end
         database:set('bot:location:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_location ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن موقعیت از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "location warn" or TSHAKE[2] == "اخطار موقعیت" then
	  if not database:get('bot:location:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_location warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار موقعیت فعال شد`', 1, 'md')
      end
         database:set('bot:location:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_location warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار موقعیت از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "tag" or TSHAKE[2] == "تگ" then
	  if not database:get('bot:tag:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_tag has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل تگ فعال شد`', 1, 'md')
      end
         database:set('bot:tag:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_tag is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل تگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "tag ban" or TSHAKE[2] == "بن تگ" then
	  if not database:get('bot:tag:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_tag ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن تگ فعال شد`', 1, 'md')
      end
         database:set('bot:tag:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_tag ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن تگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "tag warn" or TSHAKE[2] == "اخطار تگ" then
	  if not database:get('bot:tag:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_tag warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار تگ فعال شد`', 1, 'md')
      end
         database:set('bot:tag:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_tag warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار تگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "hashtag" or TSHAKE[2] == "هشتگ" then
	  if not database:get('bot:hashtag:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_hashtag has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل هشتگ فعال شد`', 1, 'md')
	  end
         database:set('bot:hashtag:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_hashtag is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل هشتگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "hashtag ban" or TSHAKE[2] == "بن هشتگ" then
	  if not database:get('bot:hashtag:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_hashtag ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن هشتگ فعال شد`', 1, 'md')
      end
         database:set('bot:hashtag:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_hashtag ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن هشتگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "hashtag warn" or TSHAKE[2] == "اخطار هشتگ" then
	  if not database:get('bot:hashtag:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_hashtag warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار هشتگ فعال شد`', 1, 'md')
      end
         database:set('bot:hashtag:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_hashtag warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار هشتگ از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "contact" or TSHAKE[2] == "مخاطب" then
	  if not database:get('bot:contact:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_contact has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`مخاطب قفل شذ`', 1, 'md')
      end
         database:set('bot:contact:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_contact is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`مخاطب از قبل قفل بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "contact ban" or TSHAKE[2] == "بن مخاطب" then
	  if not database:get('bot:contact:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_contact ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن مخاطب فعال شد`', 1, 'md')
      end
         database:set('bot:contact:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_contact ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن مخاطب از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "contact warn" or TSHAKE[2] == "اخطار مخاطب" then
	  if not database:get('bot:contact:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_contact warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار مخاطب فعال شد`', 1, 'md')
      end
         database:set('bot:contact:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_contact warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار مخاطب از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "webpage" or PCT[2] == "وب" then
	  if not database:get('bot:webpage:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_webpage has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل وب فعال شد`', 1, 'md')
      end
         database:set('bot:webpage:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_webpage is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل وب از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "webpage ban" or PCT[2] == "بن وب" then
	  if not database:get('bot:webpage:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_webpage ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن وب فعال شد`', 1, 'md')
      end
         database:set('bot:webpage:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_webpage ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن وب از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "webpage warn" or PCT[2] == "اخطار وب" then
	  if not database:get('bot:webpage:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_webpage warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار وب فعال شد`', 1, 'md')
      end
         database:set('bot:webpage:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_webpage warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار وب از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "arabic" or PCT[2] == "عربی" then
	  if not database:get('bot:arabic:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_arabic has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل عربی فعال شد`', 1, 'md')
      end
         database:set('bot:arabic:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_arabic is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل عربی از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "arabic ban" or PCT[2] == "بن عربی" then
	  if not database:get('bot:arabic:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_arabic ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن عربی فعال شد`', 1, 'md')
      end
         database:set('bot:arabic:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_arabic ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن عربی از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "arabic warn" or PCT[2] == "اخطار عربی" then
	  if not database:get('bot:arabic:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_arabic warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار عربی فعال شد`', 1, 'md')
      end
         database:set('bot:arabic:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_arabic warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار عربی از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "english" or PCT[2] == "انگلیسی" then
	  if not database:get('bot:english:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_english has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل انگلیسی فعال شد`', 1, 'md')
      end
         database:set('bot:english:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_english is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل انگلیسی از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "english ban" or PCT[2] == "بن انگلیسی" then
	  if not database:get('bot:text:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_english ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن انگلیسی فعال شد`', 1, 'md')
      end
         database:set('bot:english:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_english ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن انگلیسی از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "english warn" or PCT[2] == "اخطار انگلیسی" then
	  if not database:get('bot:english:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_english warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار انگلیسی فعال شد`', 1, 'md')
      end
         database:set('bot:english:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_english warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار انگلیسی از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "spam del" or PCT[2] == "اسپم" then
	  if not database:get('bot:spam:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_spam has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل اسپم فعال شد`', 1, 'md')
      end
         database:set('bot:spam:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_spam is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل اسپم از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "spam warn" or PCT[2] == "اخطار اسپم" then
	  if not database:get('bot:spam:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_spam ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار اسپم فعال شد`', 1, 'md')
      end
         database:set('bot:spam:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_spam warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار اسپم از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "sticker" or PCT[2] == "استیکر" then
	  if not database:get('bot:sticker:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_sticker has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل استیکر فعال شد`', 1, 'md')
      end
         database:set('bot:sticker:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_sticker is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل استیکر از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "sticker ban" or PCT[2] == "بن استیکر" then
	  if not database:get('bot:sticker:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_sticker ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن استیکر فعال شد`', 1, 'md')
      end
         database:set('bot:sticker:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_sticker ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن استیکر از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "sticker warn" or PCT[2] == "اخطار استیکر" then
	  if not database:get('bot:sticker:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_sticker ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار استیکر فعال شد`', 1, 'md')
      end
         database:set('bot:sticker:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_sticker warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار استیکر از قبل فعال بود`', 1, 'md')
      end
      end
      end
	  if mutept[2] == "service" or PCT[2] == "سرویس" then
	  if not database:get('bot:tgservice:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_tgservice has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل سرویس تلگرام فعال شد`', 1, 'md')
      end
         database:set('bot:tgservice:mute'..msg.chat_id_,true)
       else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_tgservice is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل سرویس تلگرام از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "fwd" or PCT[2] == "فوروارد" then
	  if not database:get('bot:forward:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_forward has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `قفل فوروارد فعال شد`', 1, 'md')
      end
         database:set('bot:forward:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_forward is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `قفل فوروارد از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "fwd ban" or PCT[2] == "بن فوروارد" then
	  if not database:get('bot:forward:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_forward ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `بن فوروارد فعال شد`', 1, 'md')
      end
         database:set('bot:forward:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_forward ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `بن فوروارد از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "fwd warn" or PCT[2] == "اخطار فوروارد" then
	  if not database:get('bot:forward:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_forward ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `اخطار فوروارد فعال شد`', 1, 'md')
      end
         database:set('bot:forward:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_forward warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `اخطار فوروارد از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "cmd" or PCT[2] == "دستورات" then
	  if not database:get('bot:cmd:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_cmd has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `قفل دستورات ربات فعال شد`', 1, 'md')
      end
         database:set('bot:cmd:mute'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_cmd is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `قفل دستورات از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "cmd ban" or PCT[2] == "بن دستورات" then
	  if not database:get('bot:cmd:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_cmd ban has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `بن دستورات ربات فعال شد`', 1, 'md')
      end
         database:set('bot:cmd:ban'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_cmd ban is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `بن دستورات ربات از قبل فعال بود`', 1, 'md')
      end
      end
      end
      if mutept[2] == "cmd warn" or PCT[2] == "اخطار دستورات" then
	  if not database:get('bot:cmd:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_cmd warn has been_ *Locked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, ' `اخطار دستورات ربات فعال شد`', 1, 'md')
      end
         database:set('bot:cmd:warn'..msg.chat_id_,true)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_cmd warn is already_ *Locked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, ' `اخطار دستورات ربات از قبل فعال بود`', 1, 'md')
      end
      end
      end
	end 
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Uu][Nn][Ll][Oo][Cc][Kk] (.*)$") or text:match("^باز کردن (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local unmutept = {string.match(text, "^([Uu][Nn][Ll][Oo][Cc][Kk]) (.*)$")} 
	local UNPCT = {string.match(text, "^(باز کردن) (.*)$")} 
      if unmutept[2] == "all" or UNPCT[2] == "همه" then
	  if database:get('bot:muteall'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_mute all has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل همه باز شد`', 1, 'md')
      end
         database:del('bot:muteall'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_mute all is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل همه از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "all warn" or UNPCT[2] == "اخطار همه" then
	  if database:get('bot:muteallwarn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_mute all warn has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار همه غیرفعال شد`', 1, 'md')
      end
         database:del('bot:muteallwarn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_mute all warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار همه از قبل غیرفعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "all ban" or UNPCT[2] == "بن همه" then
	  if database:get('bot:muteallban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_mute all ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن همه غیر فعال شد`', 1, 'md')
      end
         database:del('bot:muteallban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_mute all ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '> ` بن همه غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "text" or UNPCT[2] == "متن" then
	  if database:get('bot:text:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Text has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل متن باز شد`', 1, 'md')
      end
         database:del('bot:text:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Text is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل متن از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "text ban" or UNPCT[2] == "بن متن" then
	  if database:get('bot:text:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Text ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن متن غیرفعال شد`', 1, 'md')
      end
         database:del('bot:text:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_> Text ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '> `بن متن غیرفعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "text warn" or UNPCT[2] == "اخطار متن" then
	  if database:get('bot:text:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Text ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار متن غیرفعال شد`', 1, 'md')
      end
         database:del('bot:text:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Text warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن متن غیرفعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "inline" or UNPCT[2] == "اینلاین" then
	  if database:get('bot:inline:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_inline has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل اینلاین باز شد`', 1, 'md')
      end
         database:del('bot:inline:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_inline is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل اینلاین از قببل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "inline ban" or UNPCT[2] == "بن اینلاین" then
	  if database:get('bot:inline:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_inline ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن اینلاین غیر فعال شد`', 1, 'md')
      end
         database:del('bot:inline:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_inline ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن اینلان از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "inline warn" or UNPCT[2] == "اخطار اینلاین" then
	  if database:get('bot:inline:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_inline ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار اینلاین غیر فعال شد`', 1, 'md')
      end
         database:del('bot:inline:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_inline warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار اینلاین از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "photo" or UNPCT[2] == "عکس" then
	  if database:get('bot:photo:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_photo has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل عکس باز شد`', 1, 'md')
      end
         database:del('bot:photo:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_photo is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل عکس از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "photo ban" or UNPCT[2] == "بن عکس" then
	  if database:get('bot:photo:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_photo ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن عکس غیر فعال شد`', 1, 'md')
      end
         database:del('bot:photo:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_photo ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن عکس از قبل غیر فعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "photo warn" or UNPCT[2] == "اخطار عکس" then
	  if database:get('bot:photo:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_photo ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار عکس غیر فعال شد`', 1, 'md')
      end
         database:del('bot:photo:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_photo warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار عکس از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "video" or UNPCT[2] == "ویدیو" then
	  if database:get('bot:video:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_video has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل ویدیو  باز شد`', 1, 'md')
      end
         database:del('bot:video:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_video is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل ویدیو از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "video ban" or UNPCT[2] == "بن ویدیو" then
	  if database:get('bot:video:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_video ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن ویدیو غیر فعال شد`', 1, 'md')
      end
         database:del('bot:video:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_video ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن ویدیو از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "video warn" or UNPCT[2] == "اخطار ویدیو" then
	  if database:get('bot:video:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_video ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار ویدیو غیر فعال شد`', 1, 'md')
      end
         database:del('bot:video:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_video warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '` اخطار ویدیو از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "gif" or UNPCT[2] == "گیف" then
	  if database:get('bot:gifs:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_gifs has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل گیف باز شد`', 1, 'md')
      end
         database:del('bot:gifs:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_gifs is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل گیف از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "gif ban" or UNPCT[2] == "بن گیف" then
	  if database:get('bot:gifs:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_gifs ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن گیف غییر فعال شد`', 1, 'md')
      end
         database:del('bot:gifs:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_gifs ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن گیف از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "gif warn" or UNPCT[2] == "اخطار گیف" then
	  if database:get('bot:gifs:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_gifs ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار گیف غیر فعال شد`', 1, 'md')
      end
         database:del('bot:gifs:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_gifs warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار گیف از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "music" or UNPCT[2] == "اهنگ" then
	  if database:get('bot:music:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Music has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل اهگ باز شد`', 1, 'md')
      end
         database:del('bot:music:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Music is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل اهنگ از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "music ban" or UNPCT[2] == "بن اهنگ" then
	  if database:get('bot:music:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Music ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن اهنگ غیر فعال شد`', 1, 'md')
      end
         database:del('bot:music:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Music ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن اهنگ ازقبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "music warn" or UNPCT[2] == "اخطار اهنگ" then
	  if database:get('bot:music:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Music ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار اهنگ غیر فعال شد`', 1, 'md')
      end
         database:del('bot:music:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_Music warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار اهنگ ازقبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "voice" or UNPCT[2] == "صدا" then
	  if database:get('bot:voice:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_voice has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل صدا باز شد`', 1, 'md')
      end
         database:del('bot:voice:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_voice is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل صدااز قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "voice ban" or UNPCT[2] == "بن صدا" then
	  if database:get('bot:voice:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_voice ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن صداغیر فعال شد`', 1, 'md')
      end
         database:del('bot:voice:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_voice ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن صدا از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "voice warn" or UNPCT[2] == "اخطار صدا" then
	  if database:get('bot:voice:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_voice ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار صدا غیر فعال شد`', 1, 'md')
      end
         database:del('bot:voice:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_voice warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار صدااز قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "links" or UNPCT[2] == "لینک" then
	  if database:get('bot:links:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_links has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل لینک باز شد`', 1, 'md')
      end
         database:del('bot:links:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_links is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل لینک از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "links ban" or UNPCT[2] == "بن لینک" then
	  if database:get('bot:links:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_links ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن لینک غیر فعال شد`', 1, 'md')
      end
         database:del('bot:links:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_links ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن لینک از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "links warn" or UNPCT[2] == "اخطار لینک" then
	  if database:get('bot:links:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_links ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار لینک غیر فعال شد`', 1, 'md')
      end
         database:del('bot:links:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_links warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار لینک از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "location" or UNPCT[2] == "موقعیت" then
	  if database:get('bot:location:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_location has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل موقعیت مکانی باز شد`', 1, 'md')
      end
         database:del('bot:location:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_location is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '` قفل موقعیت مکانی از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "location ban" or UNPCT[2] == "بن موقعیت" then
	  if database:get('bot:location:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_location ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن موقعیت مکانی غیر فعال شد`', 1, 'md')
      end
         database:del('bot:location:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_location ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن موقعیت مکانی از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "location warn" or UNPCT[2] == "اخطار موقعیت" then
	  if database:get('bot:location:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_location ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار موقعیت مکانی غیر فعال شد`', 1, 'md')
      end
         database:del('bot:location:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_location warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار موقعیت مکانی از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "tag" or UNPCT[2] == "تگ" then
	  if database:get('bot:tag:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_tag has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل تگ باز شد`', 1, 'md')
      end
         database:del('bot:tag:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_tag is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '` قفل تگ از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "tag ban" or UNPCT[2] == "بن تگ" then
	  if database:get('bot:tag:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_> tag ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '> `بن تگ غیر فعال شد`', 1, 'md')
      end
         database:del('bot:tag:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_tag ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن تگ از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "tag warn" or UNPCT[2] == "اخطار تگ" then
	  if database:get('bot:tag:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_tag ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار تگ غیر فعال شد`', 1, 'md')
      end
         database:del('bot:tag:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_tag warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار تگ از قبل غیر فعال بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "hashtag" or UNPCT[2] == "هشتگ" then
	  if database:get('bot:hashtag:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_hashtag has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل هشتگ باز شد`', 1, 'md')
      end
         database:del('bot:hashtag:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_hashtag is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل هشتگ از قبل باز بوده`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "hashtag ban" or UNPCT[2] == "بن هشتگ" then
	  if database:get('bot:hashtag:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_hashtag ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`fبن هشتگ غیرفعال شد`', 1, 'md')
      end
         database:del('bot:hashtag:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_hashtag ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن هشتگ از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "hashtag warn" or UNPCT[2] == "اخطار هشتگ" then
	  if database:get('bot:hashtag:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_hashtag ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار هشتگ غیرفعال شد`', 1, 'md')
      end
         database:del('bot:hashtag:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_hashtag warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار هشتگ از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "contact" or UNPCT[2] == "مخاطب" then
	  if database:get('bot:contact:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_contact has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل مخاطب غیرفعال شد`', 1, 'md')
      end
         database:del('bot:contact:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_contact is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل مخاطب از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "contact ban" or UNPCT[2] == "بن مخاطب" then
	  if database:get('bot:contact:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_contact ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن مخاطب غیرفعال شد`', 1, 'md')
      end
         database:del('bot:contact:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_contact ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن مخاطب از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "contact warn" or UNPCT[2] == "اخطار مخاطب" then
	  if database:get('bot:contact:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_contact ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار مخاطب غیرفعال شد`', 1, 'md')
      end
         database:del('bot:contact:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_contact warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار مخاطب از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "webpage" or UNPCT[2] == "وب" then
	  if database:get('bot:webpage:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_webpage has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل وب غیرفعال شد`', 1, 'md')
      end
         database:del('bot:webpage:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_webpage is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل وب از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "webpage ban" or UNPCT[2] == "بن وب" then
	  if database:get('bot:webpage:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_webpage ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن وب غیرفعال شد`', 1, 'md')
      end
         database:del('bot:webpage:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_webpage ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن وب از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "webpage warn" or UNPCT[2] == "اخطار وب" then
	  if database:get('bot:webpage:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_webpage ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار وب غیرفعال شد`', 1, 'md')
      end
         database:del('bot:webpage:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_webpage warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار وب از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "arabic" or UNPCT[2] == "عربی" then
	  if database:get('bot:arabic:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_arabic has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل عربی غیرفعال شد`', 1, 'md')
      end
         database:del('bot:arabic:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_arabic is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل عربی از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "arabic ban" or UNPCT[2] == "بن عربی" then
	  if database:get('bot:arabic:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_arabic ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن عربی غیرفعال شد`', 1, 'md')
      end
         database:del('bot:arabic:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_arabic ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن عربی از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "arabic warn" or UNPCT[2] == "اخطار عربی" then
	  if database:get('bot:arabic:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_arabic ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار عربی غیرفعال شد`', 1, 'md')
      end
         database:del('bot:arabic:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_arabic warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار عربی از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "english" or UNPCT[2] == "انگلیسی" then
	  if database:get('bot:english:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_english has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل انگلیسی غیرفعال شد`', 1, 'md')
      end
         database:del('bot:english:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_english is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل انگلیسی از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "english ban" or UNPCT[2] == "بن انگلیسی" then
	  if database:get('bot:text:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_english ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن انگلیسی غیرفعال شد`', 1, 'md')
      end
         database:del('bot:english:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_english ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن انگلیسی از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "english warn" or UNPCT[2] == "اخطار انگلیسی" then
	  if database:get('bot:english:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_english ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار انگلیسی غیر فعال شد`', 1, 'md')
      end
         database:del('bot:english:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_english warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار انگلیسی از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "spam del" or UNPCT[2] == "اسپم" then
	  if database:get('bot:spam:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_spam has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل اسپم غیرفعال شد`', 1, 'md')
      end
         database:del('bot:spam:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_spam is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل اسپم از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "spam warn" or UNPCT[2] == "اخطار اسپم" then
	  if database:get('bot:spam:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_spam ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار اسپم غیرفعال شد`', 1, 'md')
      end
         database:del('bot:spam:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_spam warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار اسپم از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "sticker" or UNPCT[2] == "استیکر" then
	  if database:get('bot:sticker:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_sticker has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل استیکر غیرفعال شد`', 1, 'md')
      end
         database:del('bot:sticker:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_sticker is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل استیکر از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "sticker ban" or UNPCT[2] == "بن استیکر" then
	  if database:get('bot:sticker:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_sticker ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن استیکر غیرفعال شد`', 1, 'md')
      end
         database:del('bot:sticker:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_sticker ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن استیکر از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "sticker warn" or UNPCT[2] == "اخطار استیکر" then
	  if database:get('bot:sticker:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_sticker ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار استیکر غیرفعال شد`', 1, 'md')
      end
         database:del('bot:sticker:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_sticker warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار استیکر از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
	  if unmutept[2] == "service" or UNPCT[2] == "سرویس" then
	  if database:get('bot:tgservice:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_tgservice has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل سرویس الگرام غیرفعال شد`', 1, 'md')
      end
         database:del('bot:tgservice:mute'..msg.chat_id_)
       else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_tgservice is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل سرویس تلگرام از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "fwd" or UNPCT[2] == "فوروارد" then
	  if database:get('bot:forward:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_forward has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل فوروارد غیرفعال شد`', 1, 'md')
      end
         database:del('bot:forward:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_forward is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل فوروارد از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "fwd ban" or UNPCT[2] == "بن فوروارد" then
	  if database:get('bot:forward:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_forward ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن فوروارد غیرفعال شد`', 1, 'md')
      end
         database:del('bot:forward:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_forward ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن فوروارد از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "fwd warn" or UNPCT[2] == "اخطار فوروارد" then
	  if database:get('bot:forward:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_forward ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار فوروارد غیرفعال شد`', 1, 'md')
      end
         database:del('bot:forward:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_forward warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار فوروارد از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "cmd" or UNPCT[2] == "دستورات" then
	  if database:get('bot:cmd:mute'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_cmd has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`قفل دستورات ربات غیرفعال شد`', 1, 'md')
      end
         database:del('bot:cmd:mute'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_cmd is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`قفل دستورات ربات از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "cmd ban" or UNPCT[2] == "بن دستورات" then
	  if database:get('bot:cmd:ban'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_cmd ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`بن دستورات ربات غیرفعال شد`', 1, 'md')
      end
         database:del('bot:cmd:ban'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_cmd ban is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`بن دستورات ربات از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
      if unmutept[2] == "cmd warn" or UNPCT[2] == "اخطار دستورات" then
	  if database:get('bot:cmd:warn'..msg.chat_id_) then
    if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_cmd ban has been_ *unLocked*', 1, 'md')
      else
         send(msg.chat_id_, msg.id_, 1, '`اخطار دستورات ربات غیرفعال شد`', 1, 'md')
      end
         database:del('bot:cmd:warn'..msg.chat_id_)
      else
    if database:get('lang:gp:'..msg.chat_id_) then
                  send(msg.chat_id_, msg.id_, 1, '_cmd warn is already_ *unLocked*', 1, 'md')
      else
          send(msg.chat_id_, msg.id_, 1, '`اخطار دستورات ربات از قبل غیرفعال بود`', 1, 'md')
      end
      end
      end
	end 
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('ادیت','edit')
  	if text:match("^[Ee][Dd][Ii][Tt] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local editmsg = {string.match(text, "^([Ee][Dd][Ii][Tt]) (.*)$")} 
		 edit(msg.chat_id_, msg.reply_to_message_id_, nil, editmsg[2], 1, 'md')
    if database:get('lang:gp:'..msg.chat_id_) then
		 	          send(msg.chat_id_, msg.id_, 1, '*Done* _Edit My Msg_', 1, 'md')
else 
		 	          send(msg.chat_id_, msg.id_, 1, '`متن ادیت شد`', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
    if text:match("^[Cc][Ll][Ee][Aa][Nn] [Gg][Bb][Aa][Nn][Ll][Ii][Ss][Tt]$") or text:match("^پاک کردن بن ال لیست$") and is_sudo(msg) then
    if database:get('lang:gp:'..msg.chat_id_) then
      text = '_ Banall has been_ *Cleaned*'
    else
      text = '`لیست بن ال حذف شد`'
end
      database:del('bot:gbanned:')
	    send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
  end

    if text:match("^[Cc][Ll][Ee][Aa][Nn] [Aa][Dd][Mm][Ii][Nn][Ss]$") or text:match("^پاک کردن لیست ادمین$") and is_sudo(msg) then
    if database:get('lang:gp:'..msg.chat_id_) then
      text = '_adminlist has been_ *Cleaned*'
    else 
      text = '`ادمین لیست پاک شد`'
end
      database:del('bot:admins:')
	    send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
  end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('پاک کردن','clean')
  	if text:match("^[Cc][Ll][Ee][Aa][Nn] (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^([Cc][Ll][Ee][Aa][Nn]) (.*)$")} 
       if txt[2] == 'banlist' or txt[2] == 'Banlist' or txt[2] == 'بن لیست' then
	      database:del('bot:banned:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_Banlist has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`لیست بن ال پاک شد`', 1, 'md')
end
       end
	   if txt[2] == 'bots' or txt[2] == 'Bots' or txt[2] == 'ربات' then
	  local function g_bots(extra,result,success)
      local bots = result.members_
      for i=0 , #bots do
          chat_kick(msg.chat_id_,bots[i].msg.sender_user_id_)
          end 
      end
    channel_get_bots(msg.chat_id_,g_bots) 
    if database:get('lang:gp:'..msg.chat_id_) then
	          send(msg.chat_id_, msg.id_, 1, '_All bots_ *kicked!*', 1, 'md')
          else 
	          send(msg.chat_id_, msg.id_, 1, '`تمام ربات ها پاک شدن`', 1, 'md')
end
	end
	   if txt[2] == 'modlist' or txt[2] == 'Modlist' or txt[2] == 'لیست مدیران' and is_owner(msg.sender_user_id_, msg.chat_id_) then
	      database:del('bot:mods:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_Modlist has been_ *Cleaned*', 1, 'md')
      else 
          send(msg.chat_id_, msg.id_, 1, '`لیست مدیران گروه پاک شد`', 1, 'md')
end
       end 
	   if txt[2] == 'owners' or txt[2] == 'Owners' or txt[2] == 'لیست مالکان' and is_sudo(msg) then
	      database:del('bot:owners:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_ownerlist has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`لیست مالکان گروه پاک شد`', 1, 'md')
end
       end
	   if txt[2] == 'rules' or txt[2] == 'Rules' or txt[2] == 'قوانین' then
	      database:del('bot:rules'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_rules has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`قوانین پاک شد`', 1, 'md')
end
       end
	   if txt[2] == 'link' or  txt[2] == 'Link' or  txt[2] == 'لینک' then
	      database:del('bot:group:link'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_link has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`لینک پاک شد`', 1, 'md')
end
       end
	   if txt[2] == 'filterlist' or txt[2] == 'Filterlist' or txt[2] == 'فیلتر لیست' then
	      database:del('bot:filters:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_Filterlist has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`لیست کلمات فیلتر پاک شد`', 1, 'md')
end
       end
	   if txt[2] == 'silentlist' or txt[2] == 'Silentlist' or txt[2] == 'سایلنت لیست' then
	      database:del('bot:muted:'..msg.chat_id_)
    if database:get('lang:gp:'..msg.chat_id_) then
          send(msg.chat_id_, msg.id_, 1, '_Silentlist has been_ *Cleaned*', 1, 'md')
        else 
          send(msg.chat_id_, msg.id_, 1, '`لیست سایلنت پاک شد`', 1, 'md')
end
       end
       
    end 
	-----------------------------------------------------------------------------------------------
  	 if text:match("^[Ss][Ee][Tt][Tt][Ii][Nn][Gg] [Dd]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteall'..msg.chat_id_) then
	mute_all = '`|🔐`'
	else
	mute_all = '`|🔓`'
	end
	------------
	if database:get('bot:text:mute'..msg.chat_id_) then
	mute_text = '`|🔐`'
	else
	mute_text = '`|🔓`'
	end
	------------
	if database:get('bot:photo:mute'..msg.chat_id_) then
	mute_photo = '`|🔐`'
	else
	mute_photo = '`|🔓`'
	end
	------------
	if database:get('bot:video:mute'..msg.chat_id_) then
	mute_video = '`|🔐`'
	else
	mute_video = '`|🔓`'
	end
	------------
	if database:get('bot:gifs:mute'..msg.chat_id_) then
	mute_gifs = '`|🔐`'
	else
	mute_gifs = '`|🔓`'
	end
	------------
	if database:get('anti-flood:'..msg.chat_id_) then
	mute_flood = '`|🔓`'
	else  
	mute_flood = '`|🔐`'
	end
	------------
	if not database:get('flood:max:'..msg.chat_id_) then
	flood_m = 10
	else
	flood_m = database:get('flood:max:'..msg.chat_id_)
end
	------------
	if not database:get('flood:time:'..msg.chat_id_) then
	flood_t = 2
	else
	flood_t = database:get('flood:time:'..msg.chat_id_)
	end
	------------
	if database:get('bot:music:mute'..msg.chat_id_) then
	mute_music = '`|🔐`'
	else
	mute_music = '`|🔓`'
	end
	------------
	if database:get('bot:bots:mute'..msg.chat_id_) then
	mute_bots = '`|🔐`'
	else
	mute_bots = '`|🔓`'
	end
	------------
	if database:get('bot:inline:mute'..msg.chat_id_) then
	mute_in = '`|🔐`'
	else
	mute_in = '`|🔓`'
	end
	------------
	if database:get('bot:voice:mute'..msg.chat_id_) then
	mute_voice = '`|🔐`'
	else
	mute_voice = '`|🔓`'
	end
	------------
	if database:get('editmsg'..msg.chat_id_) then
	mute_edit = '`|🔐`'
	else
	mute_edit = '`|🔓`'
	end
    ------------
	if database:get('bot:links:mute'..msg.chat_id_) then
	mute_links = '`|🔐`'
	else
	mute_links = '`|🔓`'
	end
    ------------
	if database:get('bot:pin:mute'..msg.chat_id_) then
	lock_pin = '`|🔐`'
	else
	lock_pin = '`|🔓`'
	end 
    ------------
	if database:get('bot:sticker:mute'..msg.chat_id_) then
	lock_sticker = '`|🔐`'
	else
	lock_sticker = '`|🔓`'
	end
	------------
    if database:get('bot:tgservice:mute'..msg.chat_id_) then
	lock_tgservice = '`|🔐`'
	else
	lock_tgservice = '`|🔓`'
	end
	------------
    if database:get('bot:webpage:mute'..msg.chat_id_) then
	lock_wp = '`|🔐`'
	else
	lock_wp = '`|🔓`'
	end
	------------
    if database:get('bot:hashtag:mute'..msg.chat_id_) then
	lock_htag = '`|🔐`'
	else
	lock_htag = '`|🔓`'
end

   if database:get('bot:cmd:mute'..msg.chat_id_) then
	lock_cmd = '`|🔐`'
	else
	lock_cmd = '`|🔓`'
	end
	------------
    if database:get('bot:tag:mute'..msg.chat_id_) then
	lock_tag = '`|🔐`'
	else
	lock_tag = '`|🔓`'
	end
	------------
    if database:get('bot:location:mute'..msg.chat_id_) then
	lock_location = '`|🔐`'
	else
	lock_location = '`|🔓`'
end
  ------------
if not database:get('bot:sens:spam'..msg.chat_id_) then
spam_c = 250
else
spam_c = database:get('bot:sens:spam'..msg.chat_id_)
end

if not database:get('bot:sens:spam:warn'..msg.chat_id_) then
spam_d = 250
else
spam_d = database:get('bot:sens:spam:warn'..msg.chat_id_)
end

	------------
  if database:get('bot:contact:mute'..msg.chat_id_) then
	lock_contact = '`|🔐`'
	else
	lock_contact = '`|🔓`'
	end
	------------
  if database:get('bot:spam:mute'..msg.chat_id_) then
	mute_spam = '`|🔐`'
	else
	mute_spam = '`|🔓`'
end

	if database:get('anti-flood:warn'..msg.chat_id_) then
	lock_flood = '`|🔓`'
	else 
	lock_flood = '`|🔐`'
	end
	------------
    if database:get('bot:english:mute'..msg.chat_id_) then
	lock_english = '`|🔐`'
	else
	lock_english = '`|🔓`'
	end
	------------
    if database:get('bot:arabic:mute'..msg.chat_id_) then
	lock_arabic = '`|🔐`'
	else
	lock_arabic = '`|🔓`'
	end
	------------
    if database:get('bot:forward:mute'..msg.chat_id_) then
	lock_forward = '`|🔐`'
	else
	lock_forward = '`|🔓`'
	end
	------------
	if database:get("bot:welcome"..msg.chat_id_) then
	send_welcome = '`| ✔`'
	else
	send_welcome = '`| ⭕`'
end
		if not database:get('flood:max:warn'..msg.chat_id_) then
	flood_warn = 10
	else
	flood_warn = database:get('flood:max:warn'..msg.chat_id_)
end
	------------
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = '`NO Fanil`'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "*Group Settings Del*\n======================\n*Del all* : "..mute_all.."\n" .."*Del Links* : "..mute_links.."\n" .."*Del Edit* : "..mute_edit.."\n" .."*Del Bots* : "..mute_bots.."\n" .."*Del Inline* : "..mute_in.."\n" .."*Del English* : "..lock_english.."\n" .."*Del Forward* : "..lock_forward.."\n" .."*Del Pin* : "..lock_pin.."\n" .."*Del Arabic* : "..lock_arabic.."\n" .."*Del Hashtag* : "..lock_htag.."\n".."*Del tag* : "..lock_tag.."\n" .."*Del Webpage* : "..lock_wp.."\n" .."*Del Location* : "..lock_location.."\n" .."*Del Tgservice* : "..lock_tgservice.."\n"
.."*Del Spam* : "..mute_spam.."\n" .."*Del Photo* : "..mute_photo.."\n" .."*Del Text* : "..mute_text.."\n" .."*Del Gifs* : "..mute_gifs.."\n" .."*Del Voice* : "..mute_voice.."\n" .."*Del Music* : "..mute_music.."\n" .."*Del Video* : "..mute_video.."\n*Del Cmd* : "..lock_cmd.."\n" .."*Flood Ban* : "..mute_flood.."\n" .."*Flood Mute* : "..lock_flood.."\n"
.."======================\n*Welcome* : "..send_welcome.."\n*Flood Time*  "..flood_t.."\n" .."*Flood Max* : "..flood_m.."\n" .."*Flood Mute* : "..flood_warn.."\n" .."*Number Spam* : "..spam_c.."\n" .."*Warn Spam* : "..spam_d.."\n"
.."*Expire* : "..exp_dat.."\n======================"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end

          local text = msg.content_.text_:gsub('تنظیمات پاک کردن','تنظیمات پاک کردن')
  	 if text:match("^تنظیمات پاک کردن$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteall'..msg.chat_id_) then
	mute_all = '`|🔐`'
	else
	mute_all = '`|🔓`'
	end
	------------
	if database:get('bot:text:mute'..msg.chat_id_) then
	mute_text = '`|🔐`'
	else
	mute_text = '`|🔓`'
	end
	------------
	if database:get('bot:photo:mute'..msg.chat_id_) then
	mute_photo = '`|🔐`'
	else
	mute_photo = '`|🔓`'
	end
	------------
	if database:get('bot:video:mute'..msg.chat_id_) then
	mute_video = '`|🔐`'
	else
	mute_video = '`|🔓`'
	end
	------------
	if database:get('bot:gifs:mute'..msg.chat_id_) then
	mute_gifs = '`|🔐`'
	else
	mute_gifs = '`|🔓`'
	end
	------------
	if database:get('anti-flood:'..msg.chat_id_) then
	mute_flood = '`|🔓`'
	else  
	mute_flood = '`|🔐`'
	end
	------------
	if not database:get('flood:max:'..msg.chat_id_) then
	flood_m = 10
	else
	flood_m = database:get('flood:max:'..msg.chat_id_)
end
	------------
	if not database:get('flood:time:'..msg.chat_id_) then
	flood_t = 2
	else
	flood_t = database:get('flood:time:'..msg.chat_id_)
	end
	------------
	if database:get('bot:music:mute'..msg.chat_id_) then
	mute_music = '`|🔐`'
	else
	mute_music = '`|🔓`'
	end
	------------
	if database:get('bot:bots:mute'..msg.chat_id_) then
	mute_bots = '`|🔐`'
	else
	mute_bots = '`|🔓`'
	end
	------------
	if database:get('bot:inline:mute'..msg.chat_id_) then
	mute_in = '`|🔐`'
	else
	mute_in = '`|🔓`'
	end
	------------
	if database:get('bot:voice:mute'..msg.chat_id_) then
	mute_voice = '`|🔐`'
	else
	mute_voice = '`|🔓`'
	end
	------------
	if database:get('editmsg'..msg.chat_id_) then
	mute_edit = '`|🔐`'
	else
	mute_edit = '`|🔓`'
	end
    ------------
	if database:get('bot:links:mute'..msg.chat_id_) then
	mute_links = '`|🔐`'
	else
	mute_links = '`|🔓`'
	end
    ------------
	if database:get('bot:pin:mute'..msg.chat_id_) then
	lock_pin = '`|🔐`'
	else
	lock_pin = '`|🔓`'
	end 
    ------------
	if database:get('bot:sticker:mute'..msg.chat_id_) then
	lock_sticker = '`| 🔐`'
	else
	lock_sticker = '`|🔓`'
	end
	------------
    if database:get('bot:tgservice:mute'..msg.chat_id_) then
	lock_tgservice = '`|🔐`'
	else
	lock_tgservice = '`|🔓`'
	end
	------------
    if database:get('bot:webpage:mute'..msg.chat_id_) then
	lock_wp = '`|🔐`'
	else
	lock_wp = '`|🔓`'
	end
	------------
    if database:get('bot:hashtag:mute'..msg.chat_id_) then
	lock_htag = '`|🔐`'
	else
	lock_htag = '`|🔓`'
end

   if database:get('bot:cmd:mute'..msg.chat_id_) then
	lock_cmd = '`|🔐`'
	else
	lock_cmd = '`|🔓`'
	end
	------------
    if database:get('bot:tag:mute'..msg.chat_id_) then
	lock_tag = '`|🔐`'
	else
	lock_tag = '`|🔓`'
	end
	------------
    if database:get('bot:location:mute'..msg.chat_id_) then
	lock_location = '`|🔐`'
	else
	lock_location = '`|🔓`'
end
  ------------
if not database:get('bot:sens:spam'..msg.chat_id_) then
spam_c = 250
else
spam_c = database:get('bot:sens:spam'..msg.chat_id_)
end

if not database:get('bot:sens:spam:warn'..msg.chat_id_) then
spam_d = 250
else
spam_d = database:get('bot:sens:spam:warn'..msg.chat_id_)
end
	------------
  if database:get('bot:contact:mute'..msg.chat_id_) then
	lock_contact = '`|🔐`'
	else
	lock_contact = '`|🔓`'
	end
	------------
  if database:get('bot:spam:mute'..msg.chat_id_) then
	mute_spam = '`|🔐`'
	else
	mute_spam = '`|🔓`'
	end
	------------
    if database:get('bot:english:mute'..msg.chat_id_) then
	lock_english = '`|??`'
	else
	lock_english = '`|🔓`'
	end
	------------
    if database:get('bot:arabic:mute'..msg.chat_id_) then
	lock_arabic = '`|🔐`'
	else
	lock_arabic = '`|🔓`'
end

	if database:get('anti-flood:warn'..msg.chat_id_) then
	lock_flood = '`|🔓`'
	else 
	lock_flood = '`|🔐`'
	end
	------------
    if database:get('bot:forward:mute'..msg.chat_id_) then
	lock_forward = '`|🔐`'
	else
	lock_forward = '`|🔓`'
	end
	------------
	if database:get("bot:welcome"..msg.chat_id_) then
	send_welcome = '`|✔`'
	else
	send_welcome = '`|⭕`'
end
		if not database:get('flood:max:warn'..msg.chat_id_) then
	flood_warn = 10
	else
	flood_warn = database:get('flood:max:warn'..msg.chat_id_)
end
	------------
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = 'تنظیم نشده'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "` تنظیمات پاک کردن : `\n======================\n`پاک کردن کل` : "..mute_all.."\n" .."`پاک کردن لینک` : "..mute_links.."\n" .."`پاک کردن ادیت` : "..mute_edit.."\n" .."`پاک کردن ربات ها` : "..mute_bots.."\n" .."`پاک کردن دکمه شیشه ای` : "..mute_in.."\n" .."`پاک کردن انگلیسی` : "..lock_english.."\n" .."`پاک کردن فوروارد ` : "..lock_forward.."\n" .."`پاک کردن پبن` : "..lock_pin.."\n" .."`پاک کردن عربی` : "..lock_arabic.."\n" .."`پاک کردن هشتگ` : "..lock_htag.."\n".."`پاک کردن تگ` : "..lock_tag.."\n\n" .."`پاک کردن ادرس اینترنتی` : "..lock_wp.."\n" .."`پاک کردن موقعیت مکانی` : "..lock_location.."\n" .."`پاک کردن خدمات تلگرام ` : "..lock_tgservice.."\n"
.."`پاک کردن پیام طولانی` : "..mute_spam.."\n" .."`پاک کردن تصاویر` : "..mute_photo.."\n" .."`پاک کردن متن` : "..mute_text.."\n" .."`پاک کردن گیف ` : "..mute_gifs.."\n" .."`پاک کردن ویس` : "..mute_voice.."\n" .."`پاک کردن اهنگ` : "..mute_music.."\n" .."`پاک کردن فیلم` : "..mute_video.."\n`پاک کردن دستورات` : "..lock_cmd.."\n" .."`پاک کردن پیام مکرر` : "..mute_flood.."\n" .."`قفل کردن پیام مکرر` : "..lock_flood.."\n\n"
.."======================\n`خوشامد گویی` : "..send_welcome.."\n`زمان چک کردن پبام مکرر` : "..flood_t.."\n" .."`محدودیت پیام مکرر` : "..flood_m.."\n" .."`محدودیت اخطار پیام مکرر` : "..flood_warn.."\n\n" .."`تعداد حروف` : "..spam_c.."\n" .."`اخطار برای پیام طولانی` : "..spam_d.."\n"
.."`انقضای گروه` : "..exp_dat.."\n======================"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end
    
  	 if text:match("^[Ss][Ee][Tt][Tt][Ii][Nn][Gg] [Ww]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteallwarn'..msg.chat_id_) then
	mute_all = '`|🔐`'
	else
	mute_all = '`|🔓`'
	end
	------------
	if database:get('bot:text:warn'..msg.chat_id_) then
	mute_text = '`|🔐`'
	else
	mute_text = '`|🔓`'
	end
	------------
	if database:get('bot:photo:warn'..msg.chat_id_) then
	mute_photo = '`|🔐`'
	else
	mute_photo = '`|🔓`'
	end
	------------
	if database:get('bot:video:warn'..msg.chat_id_) then
	mute_video = '`|🔐`'
	else
	mute_video = '`|🔓`'
end

	if database:get('bot:spam:warn'..msg.chat_id_) then
	mute_spam = '`|🔐`'
	else
	mute_spam = '`|🔓`'
	end
	------------
	if database:get('bot:gifs:warn'..msg.chat_id_) then
	mute_gifs = '`|🔐`'
	else
	mute_gifs = '`|🔓`'
end

	------------
	if database:get('bot:music:warn'..msg.chat_id_) then
	mute_music = '`|🔐`'
	else
	mute_music = '`|🔓`'
	end
	------------
	if database:get('bot:inline:warn'..msg.chat_id_) then
	mute_in = '`|🔐`'
	else
	mute_in = '`|🔓`'
	end
	------------
	if database:get('bot:voice:warn'..msg.chat_id_) then
	mute_voice = '`|🔐`'
	else
	mute_voice = '`|🔓`'
	end
    ------------
	if database:get('bot:links:warn'..msg.chat_id_) then
	mute_links = '`|🔐`'
	else
	mute_links = '`|🔓`'
	end
    ------------
	if database:get('bot:sticker:warn'..msg.chat_id_) then
	lock_sticker = '`|🔐`'
	else
	lock_sticker = '`|🔓`'
	end
	------------
   if database:get('bot:cmd:warn'..msg.chat_id_) then
	lock_cmd = '`|🔐`'
	else
	lock_cmd = '`|🔓`'
end

    if database:get('bot:webpage:warn'..msg.chat_id_) then
	lock_wp = '`|🔐`'
	else
	lock_wp = '`|🔓`'
	end
	------------
    if database:get('bot:hashtag:warn'..msg.chat_id_) then
	lock_htag = '`|🔐`'
	else
	lock_htag = '`|🔓`'
end
	if database:get('bot:pin:warn'..msg.chat_id_) then
	lock_pin = '`|🔐`'
	else
	lock_pin = '`|🔓`'
	end 
	------------
    if database:get('bot:tag:warn'..msg.chat_id_) then
	lock_tag = '`|🔐`'
	else
	lock_tag = '`|🔓`'
	end
	------------
    if database:get('bot:location:warn'..msg.chat_id_) then
	lock_location = '`|🔐`'
	else
	lock_location = '`|🔓`'
	end
	------------
    if database:get('bot:contact:warn'..msg.chat_id_) then
	lock_contact = '`|🔐`'
	else
	lock_contact = '`|🔓`'
	end
	------------
	
    if database:get('bot:english:warn'..msg.chat_id_) then
	lock_english = '`|🔐`'
	else
	lock_english = '`|🔓`'
	end
	------------
    if database:get('bot:arabic:warn'..msg.chat_id_) then
	lock_arabic = '`|🔐`'
	else
	lock_arabic = '`|🔓`'
	end
	------------
    if database:get('bot:forward:warn'..msg.chat_id_) then
	lock_forward = '`|🔐`'
	else
	lock_forward = '`|🔓`'
end
	------------
	------------
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = '`NO Fanil`'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "*Group Settings Warn*\n======================\n*Warn all* : "..mute_all.."\n" .."*Warn Links* : "..mute_links.."\n" .."*Warn Inline* : "..mute_in.."\n" .."*Warn Pin* : "..lock_pin.."\n" .."*Warn English* : "..lock_english.."\n" .."*Warn Forward* : "..lock_forward.."\n" .."*Warn Arabic* : "..lock_arabic.."\n" .."*Warn Hashtag* : "..lock_htag.."\n".."*Warn tag* : "..lock_tag.."\n" .."*Warn Webpag* : "..lock_wp.."\n" .."*Warn Location* : "..lock_location.."\n"
.."*Warn Spam* : "..mute_spam.."\n" .."*Warn Photo* : "..mute_photo.."\n" .."*Warn Text* : "..mute_text.."\n" .."*Warn Gifs* : "..mute_gifs.."\n" .."*Warn Voice* : "..mute_voice.."\n" .."*Warn Music* : "..mute_music.."\n" .."*Warn Video* : "..mute_video.."\n*Warn Cmd* : "..lock_cmd.."\n"
.."*Expire* : "..exp_dat.."\n======================"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end


          local text = msg.content_.text_:gsub('تنظیمات اخطار','تنظیمات اخطار')
  	 if text:match("^تنظیمات اخطار$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteallwarn'..msg.chat_id_) then
	mute_all = '`|🔐`'
	else
	mute_all = '`|🔓`'
	end
	------------
	if database:get('bot:text:warn'..msg.chat_id_) then
	mute_text = '`|🔐`'
	else
	mute_text = '`|🔓`'
	end
	------------
	if database:get('bot:photo:warn'..msg.chat_id_) then
	mute_photo = '`|🔐`'
	else
	mute_photo = '`|🔓`'
	end
	------------
	if database:get('bot:video:warn'..msg.chat_id_) then
	mute_video = '`|🔐`'
	else
	mute_video = '`|🔓`'
end

	if database:get('bot:spam:warn'..msg.chat_id_) then
	mute_spam = '`|🔐`'
	else
	mute_spam = '`|🔓`'
	end
	------------
	if database:get('bot:gifs:warn'..msg.chat_id_) then
	mute_gifs = '`|🔐`'
	else
	mute_gifs = '`|🔓`'
end
	------------
	if database:get('bot:music:warn'..msg.chat_id_) then
	mute_music = '`|🔐`'
	else
	mute_music = '`|🔓`'
	end
	------------
	if database:get('bot:inline:warn'..msg.chat_id_) then
	mute_in = '`|🔐`'
	else
	mute_in = '`|🔓`'
	end
	------------
	if database:get('bot:voice:warn'..msg.chat_id_) then
	mute_voice = '`|🔐`'
	else
	mute_voice = '`|🔓`'
	end
    ------------
	if database:get('bot:links:warn'..msg.chat_id_) then
	mute_links = '`|🔐`'
	else
	mute_links = '`|🔓`'
	end
    ------------
	if database:get('bot:sticker:warn'..msg.chat_id_) then
	lock_sticker = '`|🔐`'
	else
	lock_sticker = '`|🔓`'
	end
	------------
   if database:get('bot:cmd:warn'..msg.chat_id_) then
	lock_cmd = '`|🔐`'
	else
	lock_cmd = '`|🔓`'
end

    if database:get('bot:webpage:warn'..msg.chat_id_) then
	lock_wp = '`|🔐`'
	else
	lock_wp = '`|🔓`'
	end
	------------
    if database:get('bot:hashtag:warn'..msg.chat_id_) then
	lock_htag = '`|🔐`'
	else
	lock_htag = '`|🔓`'
end
	if database:get('bot:pin:warn'..msg.chat_id_) then
	lock_pin = '`|🔐`'
	else
	lock_pin = '`|🔓`'
	end 
	------------
    if database:get('bot:tag:warn'..msg.chat_id_) then
	lock_tag = '`|🔐`'
	else
	lock_tag = '`|🔓`'
	end
	------------
    if database:get('bot:location:warn'..msg.chat_id_) then
	lock_location = '`|🔐`'
	else
	lock_location = '`|🔓`'
	end
	------------
    if database:get('bot:contact:warn'..msg.chat_id_) then
	lock_contact = '`|🔐`'
	else
	lock_contact = '`|🔓`'
	end

    if database:get('bot:english:warn'..msg.chat_id_) then
	lock_english = '`|🔐`'
	else
	lock_english = '`|🔓`'
	end
	------------
    if database:get('bot:arabic:warn'..msg.chat_id_) then
	lock_arabic = '`|🔐`'
	else
	lock_arabic = '`|🔓`'
	end
	------------
    if database:get('bot:forward:warn'..msg.chat_id_) then
	lock_forward = '`|🔐`'
	else
	lock_forward = '`|🔓`'
end
	------------
	------------
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = '`بی نهایت`'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "`تنظیمات اخطار گروه`\n======================\n`اخطار همه` : "..mute_all.."\n" .."`اخطار لینک` : "..mute_links.."\n" .."`اخطار دکمه شیشه ای` : "..mute_in.."\n" .."`اخطار پین` : "..lock_pin.."\n" .."`اخطار زبان انگلیسی` : "..lock_english.."\n" .."`اخطار فوروارد` : "..lock_forward.."\n" .."`اخطار زبان عربی` : "..lock_arabic.."\n" .."`اخطار هشتگ` : "..lock_htag.."\n".."`اخطار تگ` : "..lock_tag.."\n" .."`اخطار صفحات اینترنتی` : "..lock_wp.."\n" .."`اخطار موقعیت مکانی` : "..lock_location.."\n" 
.."`اخطار پیام طولانی` : "..mute_spam.."\n" .."`اخطار تصویر` : "..mute_photo.."\n" .."`اخطار متن` : "..mute_text.."\n" .."`اخطار گیف` : "..mute_gifs.."\n" .."`اخطار ویس` : "..mute_voice.."\n" .."`اخطار اهنگ` : "..mute_music.."\n" .."`اخطار ویدیو` : "..mute_video.."\n`اخطار دستورات ربات` : "..lock_cmd.."\n"
.."\n`انقضای گروه` : "..exp_dat.."\n" .."======================"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end
    
  	 if text:match("^[Ss][Ee][Tt][Tt][Ii][Nn][Gg] [Bb]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteallban'..msg.chat_id_) then
	mute_all = '`|🔐`'
	else
	mute_all = '`|🔓`'
	end
	------------
	if database:get('bot:text:ban'..msg.chat_id_) then
	mute_text = '`|🔐`'
	else
	mute_text = '`|🔓`'
	end
	------------
	if database:get('bot:photo:ban'..msg.chat_id_) then
	mute_photo = '`|🔐`'
	else
	mute_photo = '`|🔓`'
	end
	------------
	if database:get('bot:video:ban'..msg.chat_id_) then
	mute_video = '`|🔐`'
	else
	mute_video = '`|🔓`'
end

	------------
	if database:get('bot:gifs:ban'..msg.chat_id_) then
	mute_gifs = '`|🔐`'
	else
	mute_gifs = '`|🔓`'
	end
	------------
	if database:get('bot:music:ban'..msg.chat_id_) then
	mute_music = '`|🔐`'
	else
	mute_music = '`|🔓`'
	end
	------------
	if database:get('bot:inline:ban'..msg.chat_id_) then
	mute_in = '`|🔐`'
	else
	mute_in = '`|🔓`'
	end
	------------
	if database:get('bot:voice:ban'..msg.chat_id_) then
	mute_voice = '`|🔐`'
	else
	mute_voice = '`|🔓`'
	end
    ------------
	if database:get('bot:links:ban'..msg.chat_id_) then
	mute_links = '`|🔐`'
	else
	mute_links = '`|🔓`'
	end
    ------------
	if database:get('bot:sticker:ban'..msg.chat_id_) then
	lock_sticker = '`|🔐`'
	else
	lock_sticker = '`|🔓`'
	end
	------------
   if database:get('bot:cmd:ban'..msg.chat_id_) then
	lock_cmd = '`|🔐`'
	else
	lock_cmd = '`|🔓`'
end

    if database:get('bot:webpage:ban'..msg.chat_id_) then
	lock_wp = '`|🔐`'
	else
	lock_wp = '` | 🔓`'
	end
	------------
    if database:get('bot:hashtag:ban'..msg.chat_id_) then
	lock_htag = '`|🔐`'
	else
	lock_htag = '`|🔓`'
	end
	------------
    if database:get('bot:tag:ban'..msg.chat_id_) then
	lock_tag = '`|🔐`'
	else
	lock_tag = '`|🔓`'
	end
	------------
    if database:get('bot:location:ban'..msg.chat_id_) then
	lock_location = '`|🔐`'
	else
	lock_location = '`|🔓`'
	end
	------------
    if database:get('bot:contact:ban'..msg.chat_id_) then
	lock_contact = '` |🔐`'
	else
	lock_contact = '`|🔓`'
	end
	------------
    if database:get('bot:english:ban'..msg.chat_id_) then
	lock_english = '`|🔐`'
	else
	lock_english = '`|🔓`'
	end
	------------
    if database:get('bot:arabic:ban'..msg.chat_id_) then
	lock_arabic = '`|🔐`'
	else
	lock_arabic = '`|🔓`'
	end
	------------
    if database:get('bot:forward:ban'..msg.chat_id_) then
	lock_forward = '`|🔐`'
	else
	lock_forward = '`|🔓`'
	end
	------------
	------------
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = '`NO Fanil`'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "*Group Settings Ban*\n======================\n*Ban all* : "..mute_all.."\n" .."*Ban Links* : "..mute_links.."\n" .."*Ban Inline* : "..mute_in.."\n" .."*Ban English* : "..lock_english.."\n" .."*Ban Forward* : "..lock_forward.."\n" .."*Ban Arabic* : "..lock_arabic.."\n" .."*Ban Hashtag* : "..lock_htag.."\n".."*Ban tag* : "..lock_tag.."\n" .."*Ban Webpage* : "..lock_wp.."\n" .."*Ban Location* : "..lock_location.."\n"
.."*Ban Photo* : "..mute_photo.."\n" .."*Ban Text* : "..mute_text.."\n" .."*Ban Gifs* : "..mute_gifs.."\n" .."*Ban Voice* : "..mute_voice.."\n" .."*Ban Music* : "..mute_music.."\n" .."*Ban Video* : "..mute_video.."\n*Ban Cmd* : "..lock_cmd.."\n"
.."*Expire* : "..exp_dat.."\n======================"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end
    
          local text = msg.content_.text_:gsub('تنظیمات بن','تنظیمات بن')
  	 if text:match("^تنظیمات بن$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	if database:get('bot:muteallban'..msg.chat_id_) then
	mute_all = '`|🔐`'
	else
	mute_all = '`|🔓`'
	end
	------------
	if database:get('bot:text:ban'..msg.chat_id_) then
	mute_text = '`|🔐`'
	else
	mute_text = '`|🔓`'
	end
	------------
	if database:get('bot:photo:ban'..msg.chat_id_) then
	mute_photo = '`|🔐`'
	else
	mute_photo = '`|🔓`'
	end
	------------
	if database:get('bot:video:ban'..msg.chat_id_) then
	mute_video = '`|🔐`'
	else
	mute_video = '`|🔓`'
end
	------------
	if database:get('bot:gifs:ban'..msg.chat_id_) then
	mute_gifs = '`|🔐`'
	else
	mute_gifs = '`|🔓`'
	end
	------------
	if database:get('bot:music:ban'..msg.chat_id_) then
	mute_music = '`|🔐`'
	else
	mute_music = '`|🔓`'
	end
	------------
	if database:get('bot:inline:ban'..msg.chat_id_) then
	mute_in = '`|🔐`'
	else
	mute_in = '`|🔓`'
	end
	------------
	if database:get('bot:voice:ban'..msg.chat_id_) then
	mute_voice = '`|🔐`'
	else
	mute_voice = '`|🔓`'
	end
    ------------
	if database:get('bot:links:ban'..msg.chat_id_) then
	mute_links = '`|🔐`'
	else
	mute_links = '`|🔓`'
	end
    ------------
	if database:get('bot:sticker:ban'..msg.chat_id_) then
	lock_sticker = '`|🔐`'
	else
	lock_sticker = '`|🔓`'
	end
	------------
   if database:get('bot:cmd:ban'..msg.chat_id_) then
	lock_cmd = '`|🔐`'
	else
	lock_cmd = '`|🔓`'
end

    if database:get('bot:webpage:ban'..msg.chat_id_) then
	lock_wp = '`|🔐`'
	else
	lock_wp = '`|🔓`'
	end
	------------
    if database:get('bot:hashtag:ban'..msg.chat_id_) then
	lock_htag = '`|🔐`'
	else
	lock_htag = '`|🔓`'
	end
	------------
    if database:get('bot:tag:ban'..msg.chat_id_) then
	lock_tag = '` | 🔐`'
	else
	lock_tag = '`|🔓`'
	end
	------------
    if database:get('bot:location:ban'..msg.chat_id_) then
	lock_location = '`|🔐`'
	else
	lock_location = '`|🔓`'
	end
	------------
    if database:get('bot:contact:ban'..msg.chat_id_) then
	lock_contact = '`|🔐`'
	else
	lock_contact = '`|🔓`'
	end
	------------
    if database:get('bot:english:ban'..msg.chat_id_) then
	lock_english = '`|🔐`'
	else
	lock_english = '`|🔓`'
	end
	------------
    if database:get('bot:arabic:ban'..msg.chat_id_) then
	lock_arabic = '`|🔐`'
	else
	lock_arabic = '`|🔓`'
	end
	------------
    if database:get('bot:forward:ban'..msg.chat_id_) then
	lock_forward = '`|🔐`'
	else
	lock_forward = '`|🔓`'
	end
	------------
	------------
	local ex = database:ttl("bot:charge:"..msg.chat_id_)
                if ex == -1 then
				exp_dat = '`بی نهایت`'
				else
				exp_dat = math.floor(ex / 86400) + 1
			    end
 	------------
	 local TXT = "`تنظیمات بن گروه`\n======================\n`بن همه` : "..mute_all.."\n" .."`بن لینک` : "..mute_links.."\n" .."`بن دکمه شیشه ای` : "..mute_in.."\n" .."`بن زبان انگلیسی` : "..lock_english.."\n" .."`بن فوروارد` : "..lock_forward.."\n" .."`بن زبان عربی` : "..lock_arabic.."\n" .."`بن هشتگ` : "..lock_htag.."\n".."`بن تگ` : "..lock_tag.."\n" .."`بن صفحات اینترنتی` : "..lock_wp.."\n" .."`بن موقعیت مکانی` : "..lock_location.."\n"
.."`بن تصویر` : "..mute_photo.."\n" .."`بن متن` : "..mute_text.."\n" .."`بن گیف` : "..mute_gifs.."\n" .."`بن ویس` : "..mute_voice.."\n" .."`بن اهنگ` : "..mute_music.."\n" .."`بن ویدیو` : "..mute_video.."\n`بن دستورات ربات` : "..lock_cmd.."\n"
.."`انقضای گروه` : "..exp_dat.."\n" .."======================"
         send(msg.chat_id_, msg.id_, 1, TXT, 1, 'md')
    end
    
    
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('اکو','echo')
  	if text:match("^echo (.*)$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^(echo) (.*)$")} 
         send(msg.chat_id_, msg.id_, 1, txt[2], 1, 'md')
    end
	-----------------------------------------------------------------------------------------------
        if is_mod(msg.sender_user_id_, msg.chat_id_) then
          if text:match("^[Ss]etrules (.*)$") then
            local txt = {string.match(text, "^([Ss]etrules) (.*)$")}
            database:set('bot:rules'..msg.chat_id_, txt[2])
            if database:get('lang:gp:'..msg.chat_id_) then
              send(msg.chat_id_, msg.id_, 1, '*Group rules has been saved !*', 1, 'md')
            else
              send(msg.chat_id_, msg.id_, 1, '_قوانین گروه تنظیم شد !_', 1, 'md')
            end
          end
          if text:match("^تنظیم قوانین (.*)$") then
            local txt = {string.match(text, "^(تنظیم قوانین) (.*)$")}
            database:set('bot:rules'..msg.chat_id_, txt[2])
            if database:get('lang:gp:'..msg.chat_id_) then
              send(msg.chat_id_, msg.id_, 1, '*Group rules has been saved !*', 1, 'md')
            else
              send(msg.chat_id_, msg.id_, 1, '_قوانین گروه تنظیم شد !_', 1, 'md')
            end
          end
        end
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Rr][Uu][Ll][Ee][Ss]$")or text:match("^قوانین$") then
	local rules = database:get('bot:rules'..msg.chat_id_)
	if rules then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Group Rules :*\n'..rules, 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`قوانین گروه :`\n'..rules, 1, 'md')
end
    else
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*rules msg not saved!*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`قوانین گروه وجود ندارد`', 1, 'md')
end
	end
	end
	-----------------------------------------------------------------------------------------------
  	if text:match("^[Ss][Hh][Aa][Rr][Ee]$") or text:match("^شماره ربات$") and msg.reply_to_message_id_ == 0 then
       sendContact(msg.chat_id_, msg.id_, 0, 1, nil, 12342181973, 'PCTBot', '', bot_id)
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('تنظیم نام','setname')
		if text:match("^[Ss][Ee][Tt][Nn][Aa][Mm][Ee] (.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^([Ss][Ee][Tt][Nn][Aa][Mm][Ee]) (.*)$")}
	     changetitle(msg.chat_id_, txt[2])
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Group name updated!_\n'..txt[2], 1, 'md')
       else
         send(msg.chat_id_, msg.id_, 1, '`اسم گروه تغیر کرد`\n'..txt[2], 1, 'md')
         end
    end
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ss][Ee][Tt][Pp][Hh][Oo][Tt][Oo]$") or text:match("^تنظیم عکس") and is_owner(msg.sender_user_id_, msg.chat_id_) then
          database:set('bot:setphoto'..msg.chat_id_..':'..msg.sender_user_id_,true)
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Please send a photo noew!_', 1, 'md')
else 
         send(msg.chat_id_, msg.id_, 1, '`عکس رو ارسال کنید`', 1, 'md')
end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('شارژ','setexpire')
	if text:match("^[Ss][Ee][Tt][Ee][Xx][Pp][Ii][Rr][Ee] (%d+)$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
		local a = {string.match(text, "^([Ss][Ee][Tt][Ee][Xx][Pp][Ii][Rr][Ee]) (%d+)$")} 
		 local time = a[2] * day
         database:setex("bot:charge:"..msg.chat_id_,time,true)
		 database:set("bot:enable:"..msg.chat_id_,true)
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Group Charged for_ *'..a[2]..'* _Days_', 1, 'md')
else 
         send(msg.chat_id_, msg.id_, 1, '`گروه شارژ شد` *'..a[2]..'* `روز`', 1, 'md')
end
  end
  
	-----------------------------------------------------------------------------------------------
	if text:match("^[Ee][Xx][Pp][Ii][Rr][Ee]$") or text:match("^اعتبار") and is_mod(msg.sender_user_id_, msg.chat_id_) then
    local ex = database:ttl("bot:charge:"..msg.chat_id_)
       if ex == -1 then
                if database:get('lang:gp:'..msg.chat_id_) then
		send(msg.chat_id_, msg.id_, 1, '_No fanil_', 1, 'md')
else 
		send(msg.chat_id_, msg.id_, 1, '`بی نهایت`', 1, 'md')
end
       else
        local d = math.floor(ex / day ) + 1
                if database:get('lang:gp:'..msg.chat_id_) then
	   		send(msg.chat_id_, msg.id_, 1, d.." *Group Days*", 1, 'md')
else 
  	   		send(msg.chat_id_, msg.id_, 1, d.." `روز`", 1, 'md')
end
       end
    end
	-----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('اعتبار گروه','expire gp')
	if text:match("^[Ee][Xx][Pp][Ii][Rr][Ee] [Gg][Pp] (%d+)") and is_admin(msg.sender_user_id_, msg.chat_id_) then
	local txt = {string.match(text, "^([Ee][Xx][Pp][Ii][Rr][Ee] [Gg][Pp]) (%d+)$")} 
    local ex = database:ttl("bot:charge:"..txt[2])
       if ex == -1 then
                if database:get('lang:gp:'..msg.chat_id_) then
		send(msg.chat_id_, msg.id_, 1, '_No fanil_', 1, 'md')
else 
		send(msg.chat_id_, msg.id_, 1, '`بی نهایت`', 1, 'md')
end
       else
        local d = math.floor(ex / day ) + 1
                if database:get('lang:gp:'..msg.chat_id_) then
	   		send(msg.chat_id_, msg.id_, 1, d.." *Group is Days*", 1, 'md')
   		else 
	   		send(msg.chat_id_, msg.id_, 1, d.." `روز`", 1, 'md')
end
       end
    end
	-----------------------------------------------------------------------------------------------
	 if is_sudo(msg) then
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('لفت','leave')
  if text:match("^[Ll][Ee][Aa][Vv][Ee] (-%d+)") and is_admin(msg.sender_user_id_, msg.chat_id_) then
  	local txt = {string.match(text, "^([Ll][Ee][Aa][Vv][Ee]) (-%d+)$")} 
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, '*Group* '..txt[2]..' *remov*', 1, 'md')
   else 
	   send(msg.chat_id_, msg.id_, 1, '`گروه` '..txt[2]..' `ازدسترس ربات خارج شد`', 1, 'md')
end
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(txt[2], 0, 1, '*Error*\n_Group is not my_', 1, 'md')
	else 
	   send(txt[2], 0, 1, '`ربات در لیست گروه های من نیست`', 1, 'md')
end
	   chat_leave(txt[2], bot_id)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('پلن1','plan1')
  if text:match('^[Pp][Ll][Aa][Nn]1 (-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Pp][Ll][Aa][Nn]1) (-%d+)$")} 
       local timeplan1 = 2592000
       database:setex("bot:charge:"..txt[2],timeplan1,true)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, '_Group_ '..txt[2]..' *Done 30 Days Active*', 1, 'md')
   else 
	   send(msg.chat_id_, msg.id_, 1, '`گروه`'..txt[2]..' `به مدت 30 روز شارژ شد`', 1, 'md')
end
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(txt[2], 0, 1, '*Done 30 Days Active*', 1, 'md')
else 
	   send(txt[2], 0, 1, '`گروه با موفقیت 30 روز شارژ شد`', 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*User "..msg.sender_user_id_.." Added bot to new group*" , 1, 'md')
else
	      send(v, 0, 1, "`کاربر` "..msg.sender_user_id_.." `ربات رو به گروه اضافه کرد`" , 1, 'md')
end
       end
	   database:set("bot:enable:"..txt[2],true)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('پلن2','plan2')
  if text:match('^[Pp][Ll][Aa][Nn]2(-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Pp][Ll][Aa][Nn]2)(-%d+)$")} 
       local timeplan2 = 7776000
       database:setex("bot:charge:"..txt[2],timeplan2,true)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, '_Group_ '..txt[2]..' *Done 90 Days Active*', 1, 'md')
	 else 
	   send(msg.chat_id_, msg.id_, 1, '`گروه` '..txt[2]..' `به مدت 90 روز شاژ شد`', 1, 'md')
end
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(txt[2], 0, 1, '*Done 90 Days Active*', 1, 'md')
   else 
	   send(txt[2], 0, 1, '`گروه با موفقیت 90 روز شارژ شد`', 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*User "..msg.sender_user_id_.." Added bot to new group*" , 1, 'md')
else
	      send(v, 0, 1, "`کاربر` "..msg.sender_user_id_.." `ربات رو به گروه اضافه کرد`" , 1, 'md')
end
       end
	   database:set("bot:enable:"..txt[2],true)
  end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('پلن3','plan3')
  if text:match('^[Pp][Ll][Aa][Nn]3(-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Pp][Ll][Aa][Nn]3)(-%d+)$")} 
       database:set("bot:charge:"..txt[2],true)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, '_Group_ '..txt[2]..' *Done Days No Fanil Active*', 1, 'md')
	 else 
	   send(msg.chat_id_, msg.id_, 1, '`گروه` '..txt[2]..' `بی نهایت شارژ شد`', 1, 'md')
end
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(txt[2], 0, 1, '*Done Days No Fanil Active*', 1, 'md')
else 
	   send(txt[2], 0, 1, '`گروه با موفقیت بی نهایت شارژ شد`', 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*User "..msg.sender_user_id_.." Added bot to new group*" , 1, 'md')
else
	      send(v, 0, 1, "`ایدی` "..msg.sender_user_id_.." `گروه جدید به ربات اضافه کرد`" , 1, 'md')
end
       end
	   database:set("bot:enable:"..txt[2],true)
  end
  -----------------------------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('اضافه','add')
  if text:match('^[Aa][Dd][Dd]$') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Aa][Dd][Dd])$")} 
    if database:get("bot:charge:"..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '*Bot is already Added Group*', 1, 'md')
    else
      send(msg.chat_id_, msg.id_, 1, '`گروه از قبل در لیست ربات بوده`', 1, 'md')
end
                  end
       if not database:get("bot:charge:"..msg.chat_id_) then
       database:set("bot:charge:"..msg.chat_id_,true)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, "*Your ID :* _"..msg.sender_user_id_.."_\n*Group Added To Database*", 1, 'md')
   else 
	   send(msg.chat_id_, msg.id_, 1, " `ایدی :` _"..msg.sender_user_id_.."_\n`ربات نصب شد در گروه جدید`", 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*Your ID :* _"..msg.sender_user_id_.."_\n*added bot to new group*" , 1, 'md')
      else 
	      send(v, 0, 1, "`ایدی :` _"..msg.sender_user_id_.."_\n`ربات به گروه جدید اضافه شد`" , 1, 'md')
end
       end
	   database:set("bot:enable:"..msg.chat_id_,true)
  end
end
  -----------------------------------------------------------------------------------------------
          local text = msg.content_.text_:gsub('حذف گروه','rem')
  if text:match('^[Rr][Ee][Mm]$') and is_admin(msg.sender_user_id_, msg.chat_id_) then
       local txt = {string.match(text, "^([Rr][Ee][Mm])$")} 
      if not database:get("bot:charge:"..msg.chat_id_) then
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '*Bot is already remove Group*', 1, 'md')
    else 
      send(msg.chat_id_, msg.id_, 1, '`گروه از قبل در لیست ربات نبوده`', 1, 'md')
end
                  end
      if database:get("bot:charge:"..msg.chat_id_) then
       database:del("bot:charge:"..msg.chat_id_)
                if database:get('lang:gp:'..msg.chat_id_) then
	   send(msg.chat_id_, msg.id_, 1, "*Your ID :* _"..msg.sender_user_id_.."_\n*Group Removed From Database!*", 1, 'md')
   else 
	   send(msg.chat_id_, msg.id_, 1, "`ایدی :` _"..msg.sender_user_id_.."_\n`ربات  حذف شد از گروه`", 1, 'md')
end
	   for k,v in pairs(sudo_users) do
                if database:get('lang:gp:'..msg.chat_id_) then
	      send(v, 0, 1, "*Your ID :* _"..msg.sender_user_id_.."_\n*Removed bot from new group*" , 1, 'md')
      else 
	      send(v, 0, 1, "`ایدی :` _"..msg.sender_user_id_.."_\n`ربات  حذف شد از گروه`" , 1, 'md')
end
       end
  end
  end
              
  -----------------------------------------------------------------------------------------------
       local text = msg.content_.text_:gsub('ورود به','join')
	   if text:match('^[Jj]oin(-%d+)') and is_admin(msg.sender_user_id_, msg.chat_id_) then
          local txt = {string.match(text, "^([Jj]oin)(-%d+)$")}
          send(msg.chat_id_, msg.id_, 1, 'باموفقیت شما را به گروه '..txt[2]..' اضافه کردم !', 1, 'md')
          add_user(txt[2], msg.sender_user_id_, 20)
        end
   -----------------------------------------------------------------------------------------------
  end
	-----------------------------------------------------------------------------------------------
     if text:match("^[Dd][Ee][Ll]") or text:match("^پاک") and msg.reply_to_message_id_ ~= 0 and is_mod(msg.sender_user_id_, msg.chat_id_) then
     delete_msg(msg.chat_id_, {[0] = msg.reply_to_message_id_})
     delete_msg(msg.chat_id_, {[0] = msg.id_})
            end
	----------------------------------------------------------------------------------------------
   if text:match('^پاک کردن(%d+)$') and is_sudo(msg) then
  local matches = {string.match(text, "^(پاک کردن) (%d+)$")}
   if msg.chat_id_:match("^-100") then
    if tonumber(matches[2]) > 100 or tonumber(matches[2]) < 1 then
      pm = '<code>ربات قادر به پاک سازی  کمتر از 1000 پیام در گروه است</code>'
    send(msg.chat_id_, msg.id_, 1, pm, 1, 'md')
                  else
      tdcli_function ({
     ID = "GetChatHistory",
       chat_id_ = msg.chat_id_,
          from_message_id_ = 0,
   offset_ = 0,
          limit_ = tonumber(matches[2])
    }, delmsg, nil)
      pm ='*'..matches[2]..'* _پیام اخیر حذف شد !_'
           send(msg.chat_id_, msg.id_, 1, pm, 1, 'md')
       end
        else pm ='_در گروه معمولی این امکان وجود ندارد !_'
      send(msg.chat_id_, msg.id_, 1, pm, 1, 'md')
              end
            end


   if text:match('^[Dd]el (%d+)$') and is_sudo(msg) then
  local matches = {string.match(text, "^([Dd]el) (%d+)$")}
   if msg.chat_id_:match("^-100") then
    if tonumber(matches[2]) > 100 or tonumber(matches[2]) < 1 then
      pm = '*Error*\n*use /del [1-1000] !*'
    send(msg.chat_id_, msg.id_, 1, pm, 1, 'md')
                  else
      tdcli_function ({
     ID = "GetChatHistory",
       chat_id_ = msg.chat_id_,
          from_message_id_ = 0,
   offset_ = 0,
          limit_ = tonumber(matches[2])
    }, delmsg, nil)
      pm ='_'..matches[2]..'_ *Last Msgs Has Been Removed.*'
           send(msg.chat_id_, msg.id_, 1, pm, 1, 'md')
       end
        else pm ='*This is not possible in the conventional group !*'
      send(msg.chat_id_, msg.id_, 1, pm, 1, 'md')
                end
              end

          local text = msg.content_.text_:gsub('ذخیره یادداشت','note')
    if text:match("^[Nn][Oo][Tt][Ee] (.*)$") and is_sudo(msg) then
    local txt = {string.match(text, "^([Nn][Oo][Tt][Ee]) (.*)$")}
      database:set('owner:note1', txt[2])
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '*save!*', 1, 'md')
    else 
      send(msg.chat_id_, msg.id_, 1, '`ذخیره شد`', 1, 'md')
end
    end

    if text:match("^[Dd][Nn][Oo][Tt][Ee]$") or text:match("^پاک کردن یاداشت$") and is_sudo(msg) then
      database:del('owner:note1',msg.chat_id_)
                if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '*Deleted!*', 1, 'md')
    else 
      send(msg.chat_id_, msg.id_, 1, '`پاک شد`', 1, 'md')
end
      end
  -----------------------------------------------------------------------------------------------
    if text:match("^[Gg][Ee][Tt][Nn][Oo][Tt][Ee]$") or text:match("^ارسال یادداشت$") and is_sudo(msg) then
    local note = database:get('owner:note1')
	if note then
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Note is :-*\n'..note, 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`متن یادداشت:`\n'..note, 1, 'md')
end
    else
                if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '*Note msg not saved!*', 1, 'md')
       else 
         send(msg.chat_id_, msg.id_, 1, '`یادداشت ثبت نشده`', 1, 'md')
end
	end
end

  if text:match("^[Ss][Ee][Tt][Ll][Aa][Nn][Gg] (.*)$") or text:match("^تنظیم زبان (.*)$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
    local langs = {string.match(text, "^(.*) (.*)$")}
  if langs[2] == "fa" or langs[2] == "فارسی" then
  if not database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '_زبان گروه از قبل فارسی بود_', 1, 'md')
    else
      send(msg.chat_id_, msg.id_, 1, '_زبان گروه به فارسی تغییر کرد_', 1, 'md')
       database:del('lang:gp:'..msg.chat_id_)
    end
    end
  if langs[2] == "en" or langs[2] == "انگلیسی" then
  if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, '_Language Bot is already_ *English*', 1, 'md')
    else
      send(msg.chat_id_, msg.id_, 1, '_Language Bot has been changed to_ *English* !', 1, 'md')
        database:set('lang:gp:'..msg.chat_id_,true)
    end
    end
    end
    -----------------------------------------------------------------------------------------------
	        if text:match("^[Dd][Ee][Vv]$") and is_sudo(msg) then
          sendContact(msg.chat_id_, msg.id_, 0, 1, nil,13653000999, 'MrLucas', '|βĐ™|;D', 350727100)
        end
	-----------------------------------------------------------------------------------------------
    if text:match("^[Ii][Dd]$") or text:match("^ایدی$") and msg.reply_to_message_id_ == 0  then
local function getpro(extra, result, success)
local user_msgs = database:get('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
   if result.photos_[0] then
            sendPhoto(msg.chat_id_, msg.id_, 0, 1, nil, result.photos_[0].sizes_[1].photo_.persistent_id_,'> Supergroup ID: '..msg.chat_id_..'\n> Your ID: '..msg.sender_user_id_..'\n> Number of your Msgs: '..user_msgs,msg.id_,msg.id_)
   else
      send(msg.chat_id_, msg.id_, 1, "You Have'nt Profile Photo!!\n\n> *Supergroup ID:* `"..msg.chat_id_.."`\n*> Your ID:* `"..msg.sender_user_id_.."`\n*> Number of your Msgs: *`"..user_msgs.."`", 1, 'md')
   end
   end
   tdcli_function ({
    ID = "GetUserProfilePhotos",
    user_id_ = msg.sender_user_id_,
    offset_ = 0,
    limit_ = 1
  }, getpro, nil)
	end
	-----------------------------------------------------------------------------------------------
		if text:match("^[Ss][Tt][Aa][Tt][Ss]$") and is_admin(msg.sender_user_id_, msg.chat_id_) then
    local gps = database:scard("bot:groups")
	local users = database:scard("bot:userss")
    local allmgs = database:get("bot:allmsgs")
                   send(msg.chat_id_, msg.id_, 1, '_Stats_\n\n*Groups: * `'..gps..'`\n*Users: * `'..users..'`\n*All msgs: * `'..allmgs..'`', 1, 'md')
	end
	-----------------------------------------------------------------------------------------------
if text:match("^[Mm][Ee]$") or text:match("^من$") and msg.reply_to_message_id_ == 0 then
local user_msgs = database:get('user:msgs'..msg.chat_id_..':'..msg.sender_user_id_)
          function get_me(extra,result,success)
      if is_sudo(msg) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Sudo'
      else
      t = 'مدیر ربات'
      end
      elseif is_admin(msg.sender_user_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Global Admin'
      else
      t = 'صاحب گروه'
      end
      elseif is_owner(msg.sender_user_id_, msg.chat_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Group Owner'
      else
      t = 'صاحب گروه'
      end
      elseif is_mod(msg.sender_user_id_, msg.chat_id_) then
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Group Moderator'
      else
      t = 'مدیر گروه'
      end
      else
      if database:get('lang:gp:'..msg.chat_id_) then
      t = 'Group Member'
      else
      t = 'کاربر'
      end
    end
    if result.username_ then
    result.username_ = '@'..result.username_
      else
    result.username_ = 'Not Found'
        end
    if result.last_name_ then
    lastname = result.last_name_
       else
    lastname = 'Not Found'
     end
    if database:get('lang:gp:'..msg.chat_id_) then
      send(msg.chat_id_, msg.id_, 1, "Group ID : "..msg.chat_id_:gsub('-100','').."\nYour ID : "..msg.sender_user_id_.."\nYour Name : "..result.first_name_.."\nUserName : "..result.username_.."\nYour Rank : "..t.."\nMsgs : "..user_msgs.."", 1, 'html')
       else
      send(msg.chat_id_, msg.id_, 1, "ایدی گروه : "..msg.chat_id_:gsub('-100','').."\nشناسه شما : "..msg.sender_user_id_.."\nاسم : "..result.first_name_.."\nیوزرنیم : "..result.username_.."\nمقام : "..t.."\nتعدادپیام : "..user_msgs.."", 1, 'html')
      end
    end
          getUser(msg.sender_user_id_,get_me)
  end

   if text:match('^اطلاعات (%d+)') and is_sudo(msg) then
        local id = text:match('^اطلاعات (%d+)')
        local text = 'برای دیدن کاربر کلیک کنید'
      tdcli_function ({ID="SendMessage", chat_id_=msg.chat_id_, reply_to_message_id_=msg.id_, disable_notification_=0, from_background_=1, reply_markup_=nil, input_message_content_={ID="InputMessageText", text_=text, disable_web_page_preview_=1, clear_draft_=0, entities_={[0] = {ID="MessageEntityMentionName", offset_=0, length_=25, user_id_=id}}}}, dl_cb, nil)
   end 

   if text:match('^[Ww][Hh][Oo][Ii][Ss] (%d+)') and is_sudo(msg) then
        local id = text:match('^[Ww][Hh][Oo][Ii][Ss] (%d+)')
        local text = 'Click to view user!'
      tdcli_function ({ID="SendMessage", chat_id_=msg.chat_id_, reply_to_message_id_=msg.id_, disable_notification_=0, from_background_=1, reply_markup_=nil, input_message_content_={ID="InputMessageText", text_=text, disable_web_page_preview_=1, clear_draft_=0, entities_={[0] = {ID="MessageEntityMentionName", offset_=0, length_=19, user_id_=id}}}}, dl_cb, nil)
   end
   -----------------------------------------------------------------------------------------------
   if text:match("^[Pp][Ii][Nn]$") or text:match("^سنجاق$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
        local id = msg.id_
        local msgs = {[0] = id}
       pin(msg.chat_id_,msg.reply_to_message_id_,0)
	   database:set('pinnedmsg'..msg.chat_id_,msg.reply_to_message_id_)
          if database:get('lang:gp:'..msg.chat_id_) then
	            send(msg.chat_id_, msg.id_, 1, '_Msg han been_ *pinned!*', 1, 'md')
	           else 
                send(msg.chat_id_, msg.id_, 1, '_پیام مورد نظر سنجاق شد !_', 1, 'md')
end
 end

   if text:match("^[Vv][Ii][Ee][Ww]$") or text:match("^میزان بازدید$") then
        database:set('bot:viewget'..msg.sender_user_id_,true)
    if database:get('lang:gp:'..msg.chat_id_) then
        send(msg.chat_id_, msg.id_, 1, '*Please send a post now!*', 1, 'md')
      else 
            send(msg.chat_id_, msg.id_, 1, '_لطفا مطلب خود را فروراد کنید :_', 1, 'md')
end
   end
  end
   -----------------------------------------------------------------------------------------------
   if text:match("^[Uu][Nn][Pp][Ii][Nn]$") or text:match("^حذف سنجاق$") and is_owner(msg.sender_user_id_, msg.chat_id_) then
         unpinmsg(msg.chat_id_)
          if database:get('lang:gp:'..msg.chat_id_) then
         send(msg.chat_id_, msg.id_, 1, '_Pinned Msg han been_ *unpinned!*', 1, 'md')
       else 
                  send(msg.chat_id_, msg.id_, 1, "_پیام سنجاق شده از حالت سنجاق خارج شد !_", 1, 'md')
end
   end
   -----------------------------------------------------------------------------------------------
   if text:match("^[Hh][Ee][Ll][Pp]$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
`There are` * 6 * `orders to display`
*======================*
*h1* `مشاهده دستور حفاظت`
*======================*
*h2* `مشاهده دستورات اخطار`
*======================*
*h3* `مشاهده دستورات مسدود سازی`
*======================*
*h4* `مشاهده دستورات ادمین ها`
*======================*
*h5* `مشاهده دستورات گروه`
*======================*
*h6* `مشاهده دستورات توسعه دهندگان`
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]1$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*lock* 
*unlock* 
*======================*
*| links |* 
*| tag |* 
*| hashtag |* 
*| cmd |* 
*| edit |* 
*| webpage |* 
*======================*
*| flood ban |* 
*| flood mute |* 
*| gif |*
*| photo |* 
*| sticker |* 
*| video |* 
*| inline |* 
*======================*
*| text |* 
*| fwd |* 
*| music |* 
*| voice |* 
*| contact |* 
*| service |* 
*======================*
*| location |* 
*| bots |* 
*| spam |* 
*| arabic |* 
*| english |* 
*| all |* 
*| all |* 
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]2$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*lock* 
*unlock* 
*======================*
*| links warn |* 
*| tag warn |* 
*| hashtag warn |* 
*| cmd warn |* 
*| webpage warn |* 
*======================*
*| gif warn |* 
*| photo warn |*
*| sticker warn |* 
*| video warn |* 
*| inline warn |* 
*======================*
*| text warn |* 
*| fwd warn |* 
*| music warn |* 
*| voice warn |* 
*| contact warn |* 
*======================*
*| location warn |* 
*| spam |* 
*| arabic warn |* 
*| english warn |* 
*| all warn |* 
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]3$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*lock* 
*unlock* 
*======================*
*| links ban |* 
*| tag ban |* 
*| hashtag ban |* 
*| cmd ban |* 
*| webpage ban |* 
*======================*
*| gif ban |* 
*| photo ban |*
*| sticker ban |*
*| video ban |* 
*| inline ban |* 
*======================*
*| text ban |* 
*| fwd ban |* 
*| music ban |*
*| voice ban |* 
*| contact ban |* 
*| location ban |*
*======================*
*| arabic ban |* 
*| english ban |* 
*| all ban |* 
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]4$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
*| modset |* 
*| remmote |*  
*| setlang en |* 
*| setlang fa |*  
*| unsilent |* 
*| silent |* 
*| ban |*  
*| unban |* 
*| id |* 
*| pin |* 
*| unpin |* 
*======================*
*| settings d |*
*| settings w |* 
*| settings b |* 
*| silentlist |* 
*| banlist |*
*| modlist |* 
*| del |* 
*| link |* 
*| rules |* 
*======================*
*| filter [ word ] |*
*| unfilter [word] |*
*| filterlist |*
*| stats |* 
*| del welcome |*
*| set welcome |* 
*| welcome [ on/off ] |* 
*| get welcome |* 
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end

   if text:match("^[Hh]5$") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
*clean* 🔽
*| banlist |*
*| filterlist |* 
*| modlist |* 
*| link |*
*| silentlist |* 
*| bots |*
*| rules |* 
*======================*
*set* 🔽
*| link |* 
*| rules |* 
*| name |*
*| photo |* 
*======================*
*| flood ban [num] |*
*| flood mute [num] |* 
*| flood time [num] |* 
*| spam del [num] |* 
*| spam warn [num] |*
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^[Hh]6$") and is_sudo(msg) then
   
   local text =  [[
*======================*
*| add |* 
*| rem |* 
*| setexpire |* 
*| plan1 + id |*
*| plan2 + id |* 
*| plan3 + id |* 
*| join + id |* 
*| leave + id |*
*| leave |* 
*| view |* 
*| note |* 
*| dnote |* 
*| getnote |* 
*| clean gbanlist |* 
*| clean owners |* 
*| adminlist |* 
*| gbanlist |* 
*| ownerlist |* 
*| setowner |*
*| remowner |* 
*| banall |*
*| unbanall |* 
*| groups |* 
*| bc [text] |* 
*| show edit |*
*| del |* 
*| whois |* 
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   
   
   if text:match("^راهنمای کلی") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
`راهنما شامل` *6* `بخش است`
*======================*
*راهنما1* `مشاهده دستور حفاظت`
*======================*
*راهنما2* `مشاهده دستورات اخطار`
*======================*
* راهنما3 * `مشاهده دستورات مسدود سازی`
*======================*
*راهنما4* `مشاهده دستورات ادمین ها`
*======================*
*راهنما5* `مشاهده دستورات گروه`
*======================*
*راهنما6* `مشاهده دستورات توسعه دهندگان`
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^راهنما1") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
تمامی مقدار های زیر را می توانید با دستور
قفل (قابلیت)
 
 قفل کنید
 
 لینک - تگ - هشتگ - دستور - صفحات اینترنتی - گیف - عکس - ویدیو - استیکر - دکمه شیشه ای - متن - فوروارد - اهنگ - ویس - شماره - موقعیت مکانی - متن طولانی - زبان عربی - زبان انگلیسی - همه
 *======================*
 
تمامی مقدار های زیر را می توانید با دستور
بازکردن (قابلیت)
 
باز کنید
 
 لینک - تگ - هشتگ - دستور - صفحات اینترنتی - گیف - عکس - ویدیو - استیکر - دکمه شیشه ای - متن - فوروارد - اهنگ - ویس - شماره - موقعیت مکانی - متن طولانی - زبان عربی - زبان انگلیسی - همه
 *======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^راهنما2") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
تمامی مقدار های زیر را می توانید با دستور
قفل اخطار (قابلیت)
 
 قفل کنید
 
 لینک - تگ - هشتگ - دستور - صفحات اینترنتی - گیف - عکس - ویدیو - استیکر - دکمه شیشه ای - متن - فوروارد - اهنگ - ویس - شماره - موقعیت مکانی - متن طولانی - زبان عربی - زبان انگلیسی - همه
 *======================*
 
تمامی مقدار های زیر را می توانید با دستور
بازکردن اخطار (قابلیت)
 
باز کنید
 
 لینک - تگ - هشتگ - دستور - صفحات اینترنتی - گیف - عکس - ویدیو - استیکر - دکمه شیشه ای - متن - فوروارد - اهنگ - ویس - شماره - موقعیت مکانی - متن طولانی - زبان عربی - زبان انگلیسی - همه
 *======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^راهنما3") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
تمامی مقدار های زیر را می توانید با دستور
قفل بن (قابلیت)
 
 قفل کنید
 
 لینک - تگ - هشتگ - دستور - صفحات اینترنتی - گیف - عکس - ویدیو - استیکر - دکمه شیشه ای - متن - فوروارد - اهنگ - ویس - شماره - موقعیت مکانی - متن طولانی - زبان عربی - زبان انگلیسی - همه
*======================*
 
تمامی مقدار های زیر را می توانید با دستور
بازکردن بن  (قابلیت)
 
باز کنید
 
 لینک - تگ - هشتگ - دستور - صفحات اینترنتی - گیف - عکس - ویدیو - استیکر - دکمه شیشه ای - متن - فوروارد - اهنگ - ویس - شماره - موقعیت مکانی - متن طولانی - زبان عربی - زبان انگلیسی - همه
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^راهنما4") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
ارتقا مقام [ ایدی ، ریپلای و یوزنیم ]
عزل مقام [ ایدی ، ریپلای و یوزنیم ]
تنظیم زبان [ عربی و انگلیسی ]
سکوت [ ایدی ، ریپلای و یوزنیم ]
لغو سکوت [ ایدی ، ریپلای و یوزنیم ]
بن [ ایدی ، ریپلای و یوزنیم ]
لغو بن [ ایدی ، ریپلای و یوزنیم ]
ایدی 
سنجاق
حذف سنجاق
====================
انواع تنظیمات :
تنظیمات پاک کردن
تنظیمات اخطار
تنظیمات بن
====================
انواع لیست ها : 
سایلنت لیست
بن لیست
بن ال لیست
لیست مدیران
لیست فیلترها
====================
لینک
قوانین
فیلتر [کلمه]
انفیلتر [کلمه]
خوش آمدگویی روشن
خوش آمدگویی خاموش
تنظیم متن خوش امدگویی [متن]
حذف متن خوش امدگویی 
دریافت متن خوش امدگویی
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end

   if text:match("^راهنما5") and is_mod(msg.sender_user_id_, msg.chat_id_) then
   
   local text =  [[
*======================*
شما میتوانید هر کدام از لیست های زیر را با دستور 
پاک کردن (لیست مورد نظر) 
پاک کنید
بن لیست - بن ال لیست - لیست ادمین- ربات - لیست مدیران - قوانین - لینک - فیلتر لیست - سایلنت لیست 
*======================*
شما میتوانید با دستور 
 
تنظیم
 
 هرکدام از این مقدار ها را وضع کنید
 
مالک - لینک - اخطار - قوانین - نام - عکس - زبان 
 
مثال : تنظیم لینک
*======================*
راهنمای پیام های مکرر و متون طولانی :
فلود بن [عدد]
فلود اخطار [عدد]
فلود تایم [عدد]
تنظیم اسپم [عدد]
اسپم اخطار [عدد]
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
   if text:match("^راهنما6") and is_sudo(msg) then
   
   local text =  [[
*======================*
اضافه
حذف گروه
شارژ [عدد]
پلن1-[ایدی گروه]
پلن2-[ایدی گروه]
پلن3-[ایدی گروه]
ورود به-[ایدی گروه]
لفت-[ایدی گروه]
لفت
میزان بازدید
ذخیره یادداشت
پاک کردن یادداشت
ارسال یادداشت
تنظیم مالک [ایدی ، ریپلای و یوزرنیم ]
حذف مالک [ایدی ، ریپلای و یوزرنیم ]
بن ال [ایدی ، ریپلای و یوزرنیم ]
ان بن ال [ایدی ، ریپلای و یوزرنیم ]
ارسال ب همه [متن]
تشخیص ویرایش
پاک [ به صورت ریپلای و پاک کردن یک پیام مشخص ]
*======================*
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'md')
   end
   
if text:match("^pct$") or text:match("^پروتکشن$") then
   
   local text =  [[
<code>An Administration Bot Based On [TD-CLI]</code>
<code>Admins : </code>
<b>Dev | </b>@deve_Telegram
<b>spo | </b>@THENIS
<b>edi | </b>@Recognizer
<b>Tanx | </b>@Toofan
<b>Channel | </b> @ProtectionTeam
]]
                send(msg.chat_id_, msg.id_, 1, text, 1, 'html')
   end
  -----------------------------------------------------------------------------------------------
 end
  -----------------------------------------------------------------------------------------------
                                       -- end code --
  -----------------------------------------------------------------------------------------------
  elseif (data.ID == "UpdateChat") then
    chat = data.chat_
    chats[chat.id_] = chat
  -----------------------------------------------------------------------------------------------
  elseif (data.ID == "UpdateMessageEdited") then
   local msg = data
  -- vardump(msg)
  	function get_msg_contact(extra, result, success)
	local text = (result.content_.text_ or result.content_.caption_)
    --vardump(result)
	if result.id_ and result.content_.text_ then
	database:set('bot:editid'..result.id_,result.content_.text_)
	end
  if not is_mod(result.sender_user_id_, result.chat_id_) then
   check_filter_words(result, text)
   if text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Mm][Ee]") or
text:match("[Tt].[Mm][Ee]") or text:match("[Tt][Ll][Gg][Rr][Mm].[Mm][Ee]") then
   if database:get('bot:links:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end

   if text:match("[Tt][Ee][Ll][Ee][Gg][Rr][Aa][Mm].[Mm][Ee]") or
text:match("[Tt].[Mm][Ee]") or text:match("[Tt][Ll][Gg][Rr][Mm].[Mm][Ee]") then
   if database:get('bot:links:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "لینک قفل است لطفا لینک به گروه نفرستید\n", 1, 'md')
	end
end
end

   	if text:match("[Hh][Tt][Tt][Pp][Ss]://") or text:match("[Hh][Tt][Tt][Pp]://") or text:match(".[Ii][Rr]") or text:match(".[Cc][Oo][Mm]") or text:match(".[Oo][Rr][Gg]") or text:match(".[Ii][Nn][Ff][Oo]") or text:match("[Ww][Ww][Ww].") or text:match(".[Tt][Kk]") then
   if database:get('bot:webpage:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	
   if database:get('bot:webpage:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>صفحات اینترنتی ممنوع</code>\n", 1, 'html')
	end
end
end
   if text:match("@") then
   if database:get('bot:tag:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	   if database:get('bot:tag:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>ارسال تگ ممنوع</code>\n", 1, 'html')
	end
   	if text:match("#") then
   if database:get('bot:hashtag:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	   if database:get('bot:hashtag:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>ارسال هشتگ ممنوع</code>\n", 1, 'html')
	end
   	if text:match("/") then
   if database:get('bot:cmd:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	   if database:get('bot:cmd:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
       send(msg.chat_id_, 0, 1, "<code>استفادها از ربات ممنوع</code>\n", 1, 'html')
	end
end
   	if text:match("[\216-\219][\128-\191]") then
   if database:get('bot:arabic:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	end
	   if database:get('bot:arabic:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
              send(msg.chat_id_, 0, 1, "<code>فرستادن کلمات عربی ممنوع</code>\n", 1, 'html')
	end
   end
   if text:match("[ASDFGHJKLQWERTYUIOPZXCVBNMasdfghjklqwertyuiopzxcvbnm]") then
   if database:get('bot:english:mute'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
	end
	   if database:get('bot:english:warn'..result.chat_id_) then
    local msgs = {[0] = data.message_id_}
       delete_msg(msg.chat_id_,msgs)
              send(msg.chat_id_, 0, 1, "<code>فرستادن کلمات انگلیسی ممنوع</code>\n", 1, 'html')
end
end
    end
	end
	if database:get('editmsg'..msg.chat_id_) == 'delmsg' then
        local id = msg.message_id_
        local msgs = {[0] = id}
        local chat = msg.chat_id_
              delete_msg(chat,msgs)
                            send(msg.chat_id_, 0, 1, "<code>ادیت ممنوع</code>\n", 1, 'html')
	elseif database:get('editmsg'..msg.chat_id_) == 'didam' then
	if database:get('bot:editid'..msg.message_id_) then
		local old_text = database:get('bot:editid'..msg.message_id_)
send(msg.chat_id_, msg.message_id_, 1, '_چرا ادیت میکنی😠\nمن دیدم که گفتی:_\n\n*'..old_text..'*', 1, 'md')
	end
end

    getMessage(msg.chat_id_, msg.message_id_,get_msg_contact)
  -----------------------------------------------------------------------------------------------
  elseif (data.ID == "UpdateOption" and data.name_ == "my_id") then
    tdcli_function ({ID="GetChats", offset_order_="9223372036854775807", offset_chat_id_=0, limit_=20}, dl_cb, nil)    
  end
  -----------------------------------------------------------------------------------------------
end
