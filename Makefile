all: main.s
	xa main.s -o cheekymonkey.prg

run:
	/Applications/Vice/xvic.app/Contents/MacOS/xvic cheekymonkey.prg &
