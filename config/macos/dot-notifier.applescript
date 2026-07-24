-- Dot.app — the dotfiles notifier applet.
-- Post mode:  open -na Dot.app --args "<title>" "<message>"
-- Click mode: macOS activates the applet with no args when its banner is
--             clicked -> focus the last-notified session's terminal.
on run argv
	if (count of argv) ≥ 2 then
		set t to item 1 of argv
		set m to item 2 of argv
		display notification m with title t sound name "Morse"
		-- stay alive long enough for Notification Center to register the app:
		-- the FIRST-ever post races the TCC permission prompt, and if the
		-- applet exits early the prompt never appears and Dot never shows up
		-- in System Settings -> Notifications
		delay 3
	else
		try
			set sess to do shell script "cat \"$HOME/.local/share/dotfiles/last-notify\" 2>/dev/null"
			if sess is not "" then
				do shell script "\"$HOME/.local/bin/dotfiles-focus\" " & quoted form of sess
			end if
		end try
	end if
end run
