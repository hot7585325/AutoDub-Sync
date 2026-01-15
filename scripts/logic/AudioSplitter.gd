class_name AudioSplitter
extends RefCounted

class SplitParams:
	var comma_weight: float = 1.5
	var period_weight: float = 3.0
	var base_word_weight: float = 1.0
	var is_latin_mode: bool = false

# 切割主入口
static func split_audio(large_audio_path: String, txt_path: String, output_dir: String, params: SplitParams) -> bool:
	var lines = _read_lines(txt_path)
	if lines.is_empty(): return false
	
	var total_duration = _get_audio_duration(large_audio_path)
	if total_duration <= 0: return false
	
	# 1. 計算權重分佈
	var line_weights = []
	var total_weight = 0.0
	for line in lines:
		var w = _calculate_weight(line, params)
		line_weights.append(w)
		total_weight += w
	
	if total_weight == 0: return false

	# 2. 執行 FFmpeg 切割
	var current_start = 0.0
	var idx = 1
	
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)
		
	var abs_in = ProjectSettings.globalize_path(large_audio_path)
	
	for w in line_weights:
		var dur = total_duration * (w / total_weight)
		var out_name = "%03d.wav" % idx
		var out_path = output_dir.path_join(out_name)
		var abs_out = ProjectSettings.globalize_path(out_path)
		
		# 若來源是 mp3，輸出轉 wav (PCM)
		var args = ["-y", "-i", abs_in, "-ss", str(current_start), "-t", str(dur), abs_out]
		OS.execute("ffmpeg", args, [], true)
		
		current_start += dur
		idx += 1
		
	return true

# 生成 XML 給 PR/Final Cut 使用 (不切割，只標記)
static func generate_xml(large_audio_path: String, txt_path: String, output_xml_path: String, params: SplitParams) -> bool:
	var lines = _read_lines(txt_path)
	var total_duration = _get_audio_duration(large_audio_path)
	if lines.is_empty() or total_duration <= 0: return false
	
	# 計算權重
	var line_weights = []
	var total_weight = 0.0
	for line in lines:
		var w = _calculate_weight(line, params)
		line_weights.append(w)
		total_weight += w
	
	# 構建簡易 FCPXML (Format version 1.8 兼容性較好)
	var fps = 30 # 基準
	var frame_duration = "1001/30000s" # NTSC
	var total_frames = int(total_duration * fps)
	var file_name = large_audio_path.get_file()
	var file_path_url = "file://" + ProjectSettings.globalize_path(large_audio_path)
	
	var xml = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.8">
<resources>
	<format id="r1" name="FFVideoFormat1080p30" frameDuration="%s" width="1920" height="1080"/>
	<asset id="r2" name="%s" src="%s" start="0s" duration="%ds" hasAudio="1" hasVideo="0" />
</resources>
<library>
	<event name="AutoDub_Event">
		<project name="AutoDub_Audio_Cuts">
			<sequence format="r1">
				<spine>
""" % [frame_duration, file_name, file_path_url, int(total_duration)]

	var current_start_sec = 0.0
	var idx = 1
	
	for w in line_weights:
		var dur_sec = total_duration * (w / total_weight)
		
		# 轉換為 Frame 單位 (FCPXML 需要精確的 rational time，這裡簡化使用秒數 "s")
		# 注意：為了相容性，使用 offset/start/duration 屬性
		# ref: 引用 asset r2
		# offset: 在 timeline 上的位置
		# start: 在素材內部的開始時間
		# duration: 片段長度
		
		var name = "%03d" % idx
		var clip_node = """
					<asset-clip name="%s" ref="r2" offset="%.4fs" start="%.4fs" duration="%.4fs" audioRole="dialogue" />""" % [name, current_start_sec, current_start_sec, dur_sec]
		
		xml += clip_node
		current_start_sec += dur_sec
		idx += 1

	xml += """
				</spine>
			</sequence>
		</project>
	</event>
</library>
</fcpxml>"""

	var f = FileAccess.open(output_xml_path, FileAccess.WRITE)
	if f:
		f.store_string(xml)
		f.close()
		return true
	return false

# 輔助函數
static func _calculate_weight(text: String, params: SplitParams) -> float:
	var weight = 0.0
	if params.is_latin_mode:
		var words = text.split(" ", false)
		weight += words.size() * 1.5 * params.base_word_weight
	else:
		var clean_text = text.replace(" ", "").replace("\n", "")
		weight += clean_text.length() * params.base_word_weight
	
	weight += (text.count(",") + text.count("，") + text.count("、")) * params.comma_weight
	weight += (text.count(".") + text.count("?") + text.count("!") + text.count("。") + text.count("？") + text.count("！")) * params.period_weight
	return max(0.1, weight)

static func _read_lines(path) -> Array:
	var f = FileAccess.open(path, FileAccess.READ)
	var arr = []
	if f:
		while not f.eof_reached():
			var l = f.get_line().strip_edges()
			if not l.is_empty(): arr.append(l)
	return arr

static func _get_audio_duration(path) -> float:
	var output = []
	var args = ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", ProjectSettings.globalize_path(path)]
	OS.execute("ffprobe", args, output, true)
	if output.size() > 0: return output[0].to_float()
	return 0.0
