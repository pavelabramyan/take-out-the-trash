tell application "Terminal"
	activate
	set cmd to "cd \"/Users/polzovatel/Desktop/Claude-projects/Игры Steam/Вынеси мусор\" && ./tools/launch_mac.sh; echo EXIT:$?; read -p 'Enter...'"
	do script cmd
end tell
