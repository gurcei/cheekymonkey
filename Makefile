all: main.s
	python conv.py
	xa main.s -o cheekymonkey.prg

run:
	/Applications/Vice/xvic.app/Contents/MacOS/xvic cheekymonkey.prg &
