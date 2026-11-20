# logbook.gd - the Logbook (s25): every line Canopy FM and Lucky have said this
# run, kept so the player can read a tip again from the pause menu.
# Not a node: the arena owns one (Arena.logbook) and adds each line the moment it
# goes on the radio; the pause menu asks it for pages of text to draw.
class_name Logbook
extends RefCounted
## What is kept, and what is not:
##   kept     Canopy FM and Lucky lines (tips, hints, small talk), in the order said.
##   skipped  Helios's notices (threats, not tips), empty lines, and any line whose
##            words are already in the book. A wave restart or a cut-in line can
##            put the same words on the air twice; the book keeps them once.
##   words    the clean words from the config, never the "[static]" version the
##            radio panel shows while the block is dark (see Arena.with_static).
##
## HOW PAGES WORK: the newest line comes first. Each line becomes one or more
## rows of text (long lines are wrapped). Rows are packed onto pages of
## `rows_per_page`, and a line is never split across two pages.

const CONFIG: GameConfig = preload("res://config/game_config.tres")

## The short name written in front of each line, per speaker.
const SPEAKER_NAMES: Dictionary[StringName, String] = {
	Radio.CANOPY: "Canopy FM",
	Radio.LUCKY: "Lucky",
}

## The lines, oldest first. Each is {speaker: StringName, text: String, wave: int}.
var entries: Array[Dictionary] = []


## Adds one line. Returns true if it was kept, false if it was skipped (see the
## list at the top of the file).
func add(speaker: StringName, text: String, wave: int) -> bool:
	if not SPEAKER_NAMES.has(speaker) or text.strip_edges() == "":
		return false
	if has_text(text):
		return false
	entries.append({speaker = speaker, text = text, wave = wave})
	# Past the cap, the oldest line goes. pop_front removes the first entry.
	while entries.size() > CONFIG.logbook_max_entries:
		entries.pop_front()
	return true


## True if a line with exactly these words is already in the book.
func has_text(text: String) -> bool:
	for entry: Dictionary in entries:
		if entry.text == text:
			return true
	return false


## How many lines the book holds.
func size() -> int:
	return entries.size()


## The book as pages, newest line first. See pages_from().
func pages(rows_per_page: int = CONFIG.logbook_lines_per_page, wrap_chars: int = CONFIG.logbook_wrap_chars) -> Array:
	var newest_first: Array[Dictionary] = entries.duplicate()
	newest_first.reverse()  # reverse() flips the list in place
	return pages_from(newest_first, rows_per_page, wrap_chars)


## Turns `lines` (already in the order to show) into pages. Each page is an Array
## of rows, and each row is {speaker, text, first}: the first row of a line
## (first = true) starts with "W4 Canopy FM:", the rows after it are the rest of
## the wrapped words.
## A page is closed when the next line would not fit on it. A line longer than a
## whole page gets a page of its own (cut at rows_per_page rows).
## `static`: it needs no Logbook, so tests can call it with made-up lines.
static func pages_from(lines: Array[Dictionary], rows_per_page: int, wrap_chars: int) -> Array:
	var result: Array = []
	var page: Array[Dictionary] = []
	for line: Dictionary in lines:
		var label: String = "W%d %s: %s" % [line.wave, SPEAKER_NAMES.get(line.speaker, "?"), line.text]
		var rows: Array[Dictionary] = []
		for row_text: String in wrap_words(label, wrap_chars):
			rows.append({speaker = line.speaker, text = row_text, first = rows.is_empty()})
		if not page.is_empty() and page.size() + rows.size() > rows_per_page:
			result.append(page)
			page = []
		# slice(0, n) keeps the first n rows: an extra-long line is cut to one page.
		page.append_array(rows.slice(0, rows_per_page))
	if not page.is_empty():
		result.append(page)
	return result


## Splits `text` into rows of at most about `chars` letters, breaking only
## between words. A single word longer than `chars` gets a row of its own.
## `static` so the tests can call it. (Not called "wrap": Godot already has a
## wrap() for numbers, and the two would clash.)
static func wrap_words(text: String, chars: int) -> Array[String]:
	var rows: Array[String] = []
	var row: String = ""
	for word: String in text.split(" ", false):  # false = skip empty pieces from double spaces
		if row == "":
			row = word
		elif row.length() + 1 + word.length() <= chars:
			row += " " + word
		else:
			rows.append(row)
			row = word
	if row != "":
		rows.append(row)
	return rows
