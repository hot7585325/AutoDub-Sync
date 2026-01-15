class_name AudioSplitter
extends RefCounted

class SplitParams:
	var comma_weight: float = 1.5
	var period_weight: float = 3.0
	var base_word_weight: float = 1.0
	var is_latin_mode: bool = false

# 主入口
static func split_audio(large_audio_path: String, txt_path: String, output_dir: String, params: SplitParams) -> bool:
	var lines = _read_lines(txt_path)
	if lines.is_empty(): return false
	
	# 1. 自動去頭去尾分析
	var trim_info = AudioTrimmer.analyze_trim(large_audio_path)
	var start_offset = trim_info[0]
	var total_duration = trim_info[1]
	
	if total_duration <= 0: return false
	
	# 2. 計算權重
	var line_weights = []
	var total_weight = 0.0
	for line in lines:
		var w = _calculate_weight(line, params)
		line_weights.append(w)
		total_weight += w
	
	if total_weight == 0: return false

	# 3. 執行切割
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)
		
	var current_rel_start = 0.0
	var idx = 1
	var abs_in = ProjectSettings.globalize_path(large_audio_path)
	
	for w in line_weights:
		var dur = total_duration * (w / total_weight)
		
		# 實際切割開始時間 = trim_start + current_relative
		var actual_start = start_offset + current_rel_start
		
		var out_name = "%03d.wav" % idx
		var out_path = output_dir.path_join(out_name)
		var abs_out = ProjectSettings.globalize_path(out_path)
		
		var args = ["-y", "-i", abs_in, "-ss", str(actual_start), "-t", str(dur), abs_out]
		OS.execute("ffmpeg", args, [], true)
		
		current_rel_start += dur
		idx += 1
		
	return true

# 生成 XML
static func generate_xml(large_audio_path: String, txt_path: String, output_xml_path: String, params: SplitParams) -> bool:
	var lines = _read_lines(txt_path)
	# XML 生成同樣納入 Trim 邏輯
	var trim_info = AudioTrimmer.analyze_trim(large_audio_path)
	var start_offset = trim_info[0]
	var total_duration = trim_info[1]
	
	if lines.is_empty() or total_duration <= 0: return false
	
	var line_weights = []
	var total_weight = 0.0
	for line in lines:
		var w = _calculate_weight(line, params)
		line_weights.append(w)
		total_weight += w
	
	var file_name = large_audio_path.get_file()
	var file_path_url = "file://" + ProjectSettings.globalize_path(large_audio_path)
	
	var xml = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.8">
<resources>
	<format id="r1" name="FFVideoFormat1080p30" frameDuration="1001/30000s" width="1920" height="1080"/>
	<asset id="r2" name="%s" src="%s" start="0s" duration="%ds" hasAudio="1" hasVideo="0" />
</resources>
<library>
	<event name="AutoDub_Event">
		<project name="AutoDub_Trimmed_Cuts">
			<sequence format="r1">
				<spine>
""" % [file_name, file_path_url, int(total_duration + start_offset + 10)]

	var current_rel_start = 0.0
	var idx = 1
	
	for w in line_weights:
		var dur = total_duration * (w / total_weight)
		var actual_start = start_offset + current_rel_start
		
		var name = "%03d" % idx
		# offset: Timeline 位置 (從 0 開始排)
		# start: 原始素材內的時間 (必須包含 Trim Offset)
		var clip = """<asset-clip name="%s" ref="r2" offset="%.4fs" start="%.4fs" duration="%.4fs" audioRole="dialogue" />""" % [name, current_rel_start, actual_start, dur]
		xml += clip
		current_rel_start += dur
		idx += 1

	xml += "</spine></sequence></project></event></library></fcpxml>"
	
	var f = FileAccess.open(output_xml_path, FileAccess.WRITE)
	if f:
		f.store_string(xml)
		f.close()
		return true
	return false

static func _calculate_weight(text: String, params: SplitParams) -> float:
	var weight = 0.0
	if params.is_latin_mode:
		var words = text.split(" ", false)
		weight += words.size() * 1.5 * params.base_word_weight
	else:
		var clean = text.replace(" ", "").replace("\n", "")
		weight += clean.length() * params.base_word_weight
	
	weight += (text.count(",") + text.count("，") + text.count("、")) * params.comma_weight
	weight += (text.count(".") + text.count("?") + text.count("!") + text.count("。") + text.count("？") + text.count("！")) * params.period_weight
	return max(0.1, weight)

static func _read_lines(path):
	var f = FileAccess.open(path, FileAccess.READ)
	var arr = []
	if f:
		while not f.eof_reached():
			var l = f.get_line().strip_edges()
			if not l.is_empty(): arr.append(l)
	return arr
