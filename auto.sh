#!/bin/bash
COUNTER=1
while(true) do
./guard.sh
curl "https://api.telegram.org/botAAEJco7woYEiG6Ty1B0h5VzZfmXE9/sendmessage" -F "chat_id=127952353" -F "text=#NEWCRASH-#GardPCT-Reloaded-${COUNTER}-times"
let COUNTER=COUNTER+1 
done
