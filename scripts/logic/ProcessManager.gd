class_name ProcessManager
extends Node

signal log_updated(msg: String)
signal progress_updated(value: float, total: float)
signal processing_finished(success: bool)

var _thread: Thread
var _data: ProjectData

const FFMPEG_CMD = "ffmpeg" 
const FFPROBE_CMD = "ffprobe"
const TARGET_RES = "1920:1080"
const TARGET_AR = "44100"
const TARGET_AC = "2"

func start_processing(data: ProjectData):
	if _thread and _thread.is_started(): return
	_data = data
	_thread = Thread.new()
	_thread.start(_run_task)

func _run_task():
	_log("=== 開始合成 (含字幕燒錄) ===")
	var temp_dir = "user://temp_work/"
	if not DirAccess.dir_exists_absolute(temp_dir): DirAccess.make_dir_absolute(temp_dir)

	var safe_video = ProjectSettings.globalize_path(temp_dir + "source.mp4")
	DirAccess.copy_absolute(_data.video_path, safe_video)
	var total_dur = _get_dur(safe_video)

	var source_subs = SRTParser.parse(_data.srt_path)
	
	# --- 準備翻譯內容 ---
	var target_subs_map = {} # 用於 BY_SRT 模式的時間對照
	var burn_text_list = []  # 用於燒錄文字內容
	
	if _data.sync_mode == ProjectData.SyncMode.BY_SRT:
		# SRT 模式：讀取 SRT 取得時間與文字
		var t = SRTParser.parse(_data.trans_srt_path)
		for i in t: 
			target_subs_map[i.index] = i.end_time - i.start_time
			# 確保 list 長度夠
			while burn_text_list.size() <= i.index: burn_text_list.append("")
			burn_text_list[i.index] = i.text
	else:
		# Audio 模式：若要燒錄，讀取 TXT
		if _data.burn_subtitles and FileAccess.file_exists(_data.trans_srt_path):
			var f = FileAccess.open(_data.trans_srt_path, FileAccess.READ)
			# 這裡假設 TXT 已經對齊好，一行一句
			# 為了對應 index (從1開始)，我們先塞一個空字串在 index 0
			burn_text_list.append("") 
			while not f.eof_reached():
				var l = f.get_line().strip_edges()
				if not l.is_empty(): burn_text_list.append(l)
			f.close()

	var concat_str = ""
	var last_end = 0.0
	var idx = 1
	var fps_str = str(_data.target_fps)

	for sub in source_subs:
		call_deferred("emit_signal", "progress_updated", idx, source_subs.size())
		
		# --- 1. 間隙 (Gap) ---
		var gap = sub.start_time - last_end
		if gap > 0.1:
			var gp = ProjectSettings.globalize_path(temp_dir + "gap_%d.mp4" % idx)
			var gargs = [
				"-y", "-ss", str(last_end), "-t", str(gap), "-i", safe_video,
				"-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=%s" % TARGET_AR,
				"-filter_complex", "[0:v]scale=%s,fps=%s,setsar=1[v]" % [TARGET_RES, fps_str],
				"-map", "[v]", "-map", "1:a", "-shortest",
				"-ar", TARGET_AR, "-ac", TARGET_AC, 
				"-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", gp
			]
			OS.execute(FFMPEG_CMD, gargs, [], true)
			concat_str += "file '%s'\n" % gp
		
		# --- 2. 字幕段 (Chunk) ---
		var orig = sub.end_time - sub.start_time
		if orig <= 0: orig = 0.1
		var target = orig
		var wav = ""
		var has_audio = false
		
		# 決定目標時長
		if _data.sync_mode == ProjectData.SyncMode.BY_AUDIO:
			for ext in ["wav", "mp3"]:
				var try = _data.audio_folder_path.path_join("%03d.%s" % [sub.index, ext])
				if FileAccess.file_exists(try):
					wav = ProjectSettings.globalize_path(try)
					has_audio = true
					break
			if has_audio: target = _get_dur(wav)
		elif _data.sync_mode == ProjectData.SyncMode.BY_SRT:
			if target_subs_map.has(sub.index): target = target_subs_map[sub.index]

		var speed = target / orig
		var cp = ProjectSettings.globalize_path(temp_dir + "chunk_%d.mp4" % idx)
		var args = ["-y", "-ss", str(sub.start_time), "-t", str(orig), "-i", safe_video]
		
		# --- 濾鏡與字幕燒錄 ---
		var v_filter = ""
		
		# 基礎變速
		if _data.use_optical_flow:
			v_filter = "[0:v]setpts=PTS*%.5f,scale=%s,minterpolate='mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1:fps=%s'[v_scaled]" % [speed, TARGET_RES, fps_str]
		else:
			v_filter = "[0:v]setpts=PTS*%.5f,scale=%s,fps=%s,setsar=1[v_scaled]" % [speed, TARGET_RES, fps_str]
		
		# 判斷是否燒錄字幕
		var final_v_map = "[v_scaled]"
		var temp_srt_path = ""
		
		if _data.burn_subtitles and idx < burn_text_list.size():
			var text_content = burn_text_list[idx]
			if not text_content.is_empty():
				# 生成微型 SRT (時間 0 -> target)
				temp_srt_path = temp_dir + "temp_sub_%d.srt" % idx
				_create_temp_srt(temp_srt_path, target, text_content)
				
				# 疊加字幕濾鏡 (注意 Windows 路徑轉義)
				var esc_path = _escape_filter_path(ProjectSettings.globalize_path(temp_srt_path))
				# ForceStyle: 字體大小 24, 邊框 2 (避免背景太亂看不到字)
				v_filter += ";[v_scaled]subtitles='%s':force_style='FontSize=24,Outline=2'[v_sub]" % esc_path
				final_v_map = "[v_sub]"

		if has_audio:
			args.append("-i"); args.append(wav)
			args.append("-filter_complex"); args.append(v_filter)
			args.append("-map"); args.append(final_v_map)
			args.append("-map"); args.append("1:a")
		else:
			args.append("-f"); args.append("lavfi"); args.append("-i"); args.append("anullsrc=channel_layout=stereo:sample_rate=%s" % TARGET_AR)
			args.append("-filter_complex"); args.append(v_filter)
			args.append("-map"); args.append(final_v_map)
			args.append("-map"); args.append("1:a")
			args.append("-shortest")
			
		args.append("-ar"); args.append(TARGET_AR); args.append("-ac"); args.append(TARGET_AC)
		args.append("-c:v"); args.append("libx264"); args.append("-preset"); args.append("ultrafast"); args.append("-c:a"); args.append("aac")
		args.append(cp)
		
		OS.execute(FFMPEG_CMD, args, [], true)
		concat_str += "file '%s'\n" % cp
		last_end = sub.end_time
		idx += 1
		
	# --- 3. 片尾 ---
	var tail = total_dur - last_end
	if tail > 0.2:
		var tp = ProjectSettings.globalize_path(temp_dir + "tail.mp4")
		var targs = [
			"-y", "-ss", str(last_end), "-t", str(tail), "-i", safe_video, 
			"-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=%s" % TARGET_AR,
			"-filter_complex", "[0:v]scale=%s,fps=%s,setsar=1[v]" % [TARGET_RES, fps_str],
			"-map", "[v]", "-map", "1:a", "-shortest",
			"-ar", TARGET_AR, "-ac", TARGET_AC, "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", tp
		]
		OS.execute(FFMPEG_CMD, targs, [], true)
		concat_str += "file '%s'\n" % tp

	# --- 4. 合併 ---
	var lp = ProjectSettings.globalize_path(temp_dir + "list.txt")
	var f = FileAccess.open(temp_dir + "list.txt", FileAccess.WRITE)
	f.store_string(concat_str)
	f.close()
	
	var fout = _data.output_path
	if fout.is_empty(): fout = _data.video_path.get_base_dir().path_join("output_synced.mp4")
	
	OS.execute(FFMPEG_CMD, ["-y", "-f", "concat", "-safe", "0", "-i", lp, "-c", "copy", fout], [], true)
	_log("✅ 完成: " + fout)
	call_deferred("emit_signal", "processing_finished", true)

# 生成單句 SRT 檔案
func _create_temp_srt(path: String, duration: float, text: String):
	var f = FileAccess.open(path, FileAccess.WRITE)
	# 格式: 00:00:00,000 --> hh:mm:ss,ms
	var end_time_str = _fmt_time(duration)
	var content = "1\n00:00:00,000 --> %s\n%s" % [end_time_str, text]
	f.store_string(content)
	f.close()

# 格式化時間 float -> 00:00:05,123
func _fmt_time(t: float) -> String:
	var total_ms = int(t * 1000)
	var ms = total_ms % 1000
	var total_s = total_ms / 1000
	var s = total_s % 60
	var m = (total_s / 60) % 60
	var h = total_s / 3600
	return "%02d:%02d:%02d,%03d" % [h, m, s, ms]

# FFmpeg 濾鏡路徑轉義 (Windows 必備: C:\ -> C\\:/)
func _escape_filter_path(path: String) -> String:
	var p = path.replace("\\", "/") # 先統一轉正斜線
	p = p.replace(":", "\\:")     # 轉義冒號
	return p

func _get_dur(p):
	var o = []
	OS.execute(FFPROBE_CMD, ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", p], o, true)
	if o.size() > 0: return o[0].strip_edges().to_float()
	return 0.0

func _log(m): call_deferred("emit_signal", "log_updated", m)
func _exit_tree(): if _thread and _thread.is_started(): _thread.wait_to_finish()
