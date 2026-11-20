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
## HOW PAGES WORK: lines said one after another by the same speaker in the same
## wave make one BLOCK (Canopy FM's two-line Bramble tip, say). The newest block
## comes first, but inside a block the lines keep the order they were said, so a
## tip still reads top to bottom. A block's first line starts "W4 Canopy FM:".
## Each line becomes one or more rows of text (long lines are wrapped). Rows are
## packed onto pages of `rows_per_page`, and a line is never split across pages.

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


## The book as pages, newest block first. See newest_blocks_first() and pages_from().
func pages(rows_per_page: int = CONFIG.logbook_lines_per_page, wrap_chars: int = CONFIG.logbook_wrap_chars) -> Array:
	return pages_from(newest_blocks_first(entries), rows_per_page, wrap_chars)


## `lines` (oldest first) in the order the Logbook shows them: blocks newest
## first, the lines inside a block oldest first. The first line of each block
## gets `tagged = true` (it carries the "W4 Canopy FM:" tag). `static` for tests.
static func newest_blocks_first(lines: Array[Dictionary]) -> Array[Dictionary]:
	# Step 1: cut the list into blocks. A new block starts whenever the speaker or
	# the wave differs from the line before.
	var blocks: Array = []
	for line: Dictionary in lines:
		var last_block: Array = blocks[-1] if not blocks.is_empty() else []
		var same: bool = not last_block.is_empty() and last_block[-1].speaker == line.speaker and last_block[-1].wave == line.wave
		if same:
			last_block.append(line)  # Arrays are shared, so this grows the block in `blocks`
		else:
			blocks.append([line])
	# Step 2: newest block first; each line copied with its `tagged` flag.
	blocks.reverse()  # reverse() flips the list in place
	var ordered: Array[Dictionary] = []
	for block: Array in blocks:
		for i: int in block.size():
			var copy: Dictionary = block[i].duplicate()
			copy.tagged = i == 0
			ordered.append(copy)
	return ordered


## Turns `lines` (already in the order to show) into pages. Each page is an Array
## of rows, and each row is {speaker, text, first, new_block}: `first` marks the
## first row of a line, `new_block` the first row of a block. A line with
## `tagged` (or with no such field, or the first on a page) starts with
## "W4 Canopy FM:"; the rows after it are the rest of the wrapped words.
## A page is closed when the next line would not fit on it. A line longer than a
## whole page gets a page of its own (cut at rows_per_page rows).
## `static`: it needs no Logbook, so tests can call it with made-up lines.
static func pages_from(lines: Array[Dictionary], rows_per_page: int, wrap_chars: int) -> Array:
	var result: Array = []
	var page: Array[Dictionary] = []
	for line: Dictionary in lines:
		var tagged: bool = line.get("tagged", true)
		var rows: Array[Dictionary] = _rows_for(line, tagged, wrap_chars)
		if not page.is_empty() and page.size() + rows.size() > rows_per_page:
			result.append(page)
			page = []
			# A block that runs onto a new page names its speaker again up top.
			if not tagged:
				rows = _rows_for(line, true, wrap_chars)
		# slice(0, n) keeps the first n rows: an extra-long line is cut to one page.
		page.append_array(rows.slice(0, rows_per_page))
	if not page.is_empty():
		result.append(page)
	return result


## The wrapped rows of one line, with or without its "W4 Canopy FM:" tag.
static func _rows_for(line: Dictionary, tagged: bool, wrap_chars: int) -> Array[Dictionary]:
	var label: String = line.text
	if tagged:
		label = "W%d %s: %s" % [line.wave, SPEAKER_NAMES.get(line.speaker, "?"), line.text]
	var rows: Array[Dictionary] = []
	for row_text: String in wrap_words(label, wrap_chars):
		rows.append({speaker = line.speaker, text = row_text, first = rows.is_empty(), new_block = rows.is_empty() and tagged})
	return rows


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
