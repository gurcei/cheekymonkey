all: main.s
	python conv.py
	xa main.s -o cheekymonkey.prg

run:
	# /Applications/Vice/xvic.app/Contents/MacOS/xvic cheekymonkey.prg &
	/c/Users/GurceI/Downloads/WinVICE-3.2-x86/xvic.exe cheekymonkey.prg &
