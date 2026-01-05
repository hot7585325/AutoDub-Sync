# res://scripts/logic/SRTParser.gd
class_name SRTParser
extends RefCounted

class SubtitleLine:
	var index: int
	var start_time: float
	var end_time: float
	var text: String

static func parse(path: String) -> Array[SubtitleLine]:
	var result: Array[SubtitleLine] = []
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return result
	
	var content = file.get_as_text()
	# 簡單的 SRT 解析邏輯 (Regex 會更穩，但這裡用字串分割做示範)
	var blocks = content.split("\n\n", false)
	
	for block in blocks:
		var lines = block.split("\n")
		if lines.size() < 3: continue
		
		var sub = SubtitleLine.new()
		sub.index = lines[0].strip_edges().to_int()
		
		var times = lines[1].split(" --> ")
		sub.start_time = _time_to_seconds(times[0])
		sub.end_time = _time_to_seconds(times[1])
		sub.text = lines[2] # 簡化：只取一行文字
		
		result.append(sub)
	return result

static func _time_to_seconds(time_str: String) -> float:
	# 格式: 00:00:01,500
	var parts = time_str.strip_edges().replace(",", ".").split(":")
	var hours = parts[0].to_float()
	var minutes = parts[1].to_float()
	var seconds = parts[2].to_float()
	return hours * 3600 + minutes * 60 + seconds
