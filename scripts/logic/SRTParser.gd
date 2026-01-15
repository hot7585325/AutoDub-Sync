class_name SRTParser
extends RefCounted

class SubtitleItem:
	var index: int
	var start_time: float
	var end_time: float
	var text: String

static func parse(path: String) -> Array[SubtitleItem]:
	var result: Array[SubtitleItem] = []
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return result
	
	var content = f.get_as_text().replace("\r\n", "\n")
	var blocks = content.split("\n\n", false)
	
	for block in blocks:
		var lines = block.split("\n", false)
		if lines.size() >= 3:
			var item = SubtitleItem.new()
			item.index = lines[0].to_int()
			
			var times = lines[1].split(" --> ")
			if times.size() == 2:
				item.start_time = _parse_time(times[0])
				item.end_time = _parse_time(times[1])
			
			# 合併剩餘行數為內容
			var text_lines = []
			for i in range(2, lines.size()):
				text_lines.append(lines[i])
			item.text = "\n".join(text_lines)
			
			result.append(item)
	return result

static func _parse_time(time_str: String) -> float:
	# 格式 00:00:01,500
	var parts = time_str.replace(",", ".").split(":")
	if parts.size() == 3:
		return parts[0].to_float() * 3600 + parts[1].to_float() * 60 + parts[2].to_float()
	return 0.0
