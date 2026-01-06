class_name AudioSplitter
extends RefCounted

# 定義切割參數結構
class SplitParams:
	var comma_weight: float = 1.5
	var period_weight: float = 3.0
	var base_word_weight: float = 1.0

# 主要入口函數
static func split_audio(large_audio_path: String, txt_path: String, output_dir: String, params: SplitParams) -> bool:
	# 1. 讀取 TXT
	var f = FileAccess.open(txt_path, FileAccess.READ)
	if not f: return false
	
	var lines = []
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if not line.is_empty():
			lines.append(line)
			
	if lines.is_empty(): return false

	# 2. 獲取音檔總時長
	var total_duration = _get_audio_duration(large_audio_path)
	if total_duration <= 0: return false

	# 3. 計算權重
	var line_weights = []
	var total_weight_sum = 0.0
	
	for line in lines:
		var w = _calculate_weight(line, params)
		line_weights.append(w)
		total_weight_sum += w
	
	if total_weight_sum == 0: return false

	# 4. 執行切割
	var current_start = 0.0
	var idx = 1
	var ffmpeg_cmd = "ffmpeg"
	
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	for w in line_weights:
		var duration = total_duration * (w / total_weight_sum)
		var out_name = "%03d.wav" % idx # 輸出保持為 wav 格式
		var out_path = output_dir.path_join(out_name)
		
		var abs_in = ProjectSettings.globalize_path(large_audio_path)
		var abs_out = ProjectSettings.globalize_path(out_path)
		
		# 若來源是 mp3，輸出轉為 wav (PCM) 避免時間誤差
		var args = [
			"-y",
			"-i", abs_in,
			"-ss", str(current_start),
			"-t", str(duration),
			abs_out # FFmpeg 會根據副檔名自動決定編碼
		]
		
		OS.execute(ffmpeg_cmd, args, [], true)
		
		current_start += duration
		idx += 1
		
	return true

# 計算單句權重
static func _calculate_weight(text: String, params: SplitParams) -> float:
	var weight = 0.0
	
	# 粗略估算單字數
	var words = text.split(" ", false)
	weight += words.size() * params.base_word_weight
	
	# 標點符號加權
	weight += text.count(",") * params.comma_weight
	weight += text.count("，") * params.comma_weight
	weight += (text.count(".") + text.count("?") + text.count("!")) * params.period_weight
	weight += (text.count("。") + text.count("？") + text.count("！")) * params.period_weight
	
	return max(0.1, weight)

static func _get_audio_duration(path: String) -> float:
	var abs_path = ProjectSettings.globalize_path(path)
	var output = []
	var args = ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", abs_path]
	OS.execute("ffprobe", args, output, true)
	if output.size() > 0:
		return output[0].strip_edges().to_float()
	return 0.0
