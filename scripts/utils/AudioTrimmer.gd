class_name AudioTrimmer
extends RefCounted

# 分析並回傳建議的 [start_time, duration]
# 如果沒有偵測到靜音，回傳 [0, 總長度]
static func analyze_trim(audio_path: String) -> Array:
	var abs_path = ProjectSettings.globalize_path(audio_path)
	var duration = _get_duration(abs_path)
	if duration <= 0: return [0.0, 0.0]
	
	# 使用 silencedetect 濾鏡，噪音閾值 -50dB，持續 0.5秒以上視為靜音
	var args = ["-v", "info", "-i", abs_path, "-af", "silencedetect=noise=-50dB:d=0.5", "-f", "null", "-"]
	var output = []
	OS.execute("ffmpeg", args, output, true) # output 會包含 stderr
	var log_str = "\n".join(output)
	
	var start_trim = 0.0
	var end_trim = duration
	
	# 解析 log 尋找 silence_end (首) 和 silence_start (尾)
	# 邏輯：
	# 1. 如果 log 出現 "silence_end: 2.5"，且這是第一個出現的 end，表示前面 2.5s 是靜音。
	# 2. 如果 log 出現 "silence_start: 100.0"，且這是最後一個出現的 start，表示 100s 後是靜音。
	
	var regex_end = RegEx.new()
	regex_end.compile("silence_end: ([0-9\\.]+)")
	
	var regex_start = RegEx.new()
	regex_start.compile("silence_start: ([0-9\\.]+)")
	
	var matches_end = regex_end.search_all(log_str)
	if matches_end.size() > 0:
		var first_end = matches_end[0].get_string(1).to_float()
		# 防呆：如果首段靜音超過總長一半，可能是誤判，保守起見不切
		if first_end < duration * 0.5:
			start_trim = first_end
	
	var matches_start = regex_start.search_all(log_str)
	if matches_start.size() > 0:
		var last_start = matches_start[matches_start.size()-1].get_string(1).to_float()
		# 防呆：如果尾段靜音開始得太早，可能是誤判
		if last_start > duration * 0.5:
			end_trim = last_start

	var new_dur = end_trim - start_trim
	if new_dur <= 0: return [0.0, duration]
	
	return [start_trim, new_dur]

static func _get_duration(path) -> float:
	var out = []
	OS.execute("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", path], out, true)
	if out.size() > 0: return out[0].strip_edges().to_float()
	return 0.0
