#!/bin/bash 
PASS="tecnobit"

TARGET_PORT="$1" # Optional: specific USB port # Start pcscd 
echo "$PASS" | sudo -S systemctl start pcscd >/dev/null 2>&1 
sleep 1 # Get readers detected by opensc-tool 
READERS_RAW=$(echo "$PASS" | sudo -S opensc-tool -l 2>/dev/null | grep -E '^[0-9]+') 
# Get Omnikey USB devices via lsusb 
OMNIKEY_LINES=($(lsusb | grep "076b:3031")) 
DETECTED_COUNT=${#OMNIKEY_LINES[@]} 
EXPECTED_READERS=2 # Update if you expect more 
RESULTS=() 
ALL_DISCONNECTED=true 
INDEX=0 
while read -r line; do 
	CARD_STATUS=$(echo "$line" | awk '{print $2}') 
	OMNI_LINE=$(lsusb | grep "076b:3031" | sed -n "$((INDEX + 1))p") 
	BUS=$(echo "$OMNI_LINE" | awk '{print $2}') 
	DEV=$(echo "$OMNI_LINE" | awk '{print $4}' | sed 's/://') 
	USB_PATH=$(udevadm info --name=/dev/bus/usb/$BUS/$DEV --query=property 2>/dev/null | grep DEVPATH= | cut -d/ -f6-) 
	PORT=$(echo "$USB_PATH" | grep -oP 'usb[0-9]/\K[0-9-]+') 
	[ -z "$PORT" ] && PORT="unknown" 
	if [ "$CARD_STATUS" == "Yes" ]; then 
		STATUS_CODE=0 
	else STATUS_CODE=1 
	fi 
	RESULTS+=("$PORT:$STATUS_CODE") 
	# Check if there are any connected readers 
	if [ "$STATUS_CODE" != "2" ] && [ "$PORT" != "unknown" ]; then 
		ALL_DISCONNECTED=false 
	fi 
	((INDEX++)) 
	done <<< "$READERS_RAW" 
	# Add "not connected" readers if needed 
	if [ "$DETECTED_COUNT" -lt "$EXPECTED_READERS" ]; then 
	MISSING=$((EXPECTED_READERS - DETECTED_COUNT))
	for ((i=0; i<MISSING; i++)); do 
	RESULTS+=("unknown:2") 
	done 
fi 
# If no card readers are connected, print the message 
if [ "$ALL_DISCONNECTED" = true ]; then 
	echo "No card readers connected" 
	exit 0 
fi # If specific port requested 
if [ -n "$TARGET_PORT" ]; then 
	for entry in "${RESULTS[@]}"; do 
		PORT=${entry%%:*} 
		STATUS=${entry##*:} 
		if [ "$PORT" == "$TARGET_PORT" ]; then 
			echo "$STATUS" 
			exit 0 
		fi
	done 
	echo "2" 
	exit 0 
fi 
# Otherwise, print all reader states 
for entry in "${RESULTS[@]}"; do 
	PORT=${entry%%:*} 
	STATUS=${entry##*:} 
	echo "$STATUS - port $PORT" 
done