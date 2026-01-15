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

func start_processing(data: ProjectData):
	if _thread and _thread.is_started(): return
	_data = data
	_thread = Thread.new()
	_thread.start(_run_task)

func _run_task():
	_log("=== 開始影片對齊合成 ===")
	var temp_dir = "user://temp_work/"
	DirAccess.make_dir_absolute(temp_dir) # 確保目錄存在

	# 複製並標準化來源影片
	var safe_video_path = ProjectSettings.globalize_path(temp_dir + "source.mp4")
	DirAccess.copy_absolute(_data.video_path, safe_video_path)
	var total_video_dur = _get_duration(safe_video_path)

	# 解析字幕
	var source_subs = SRTParser.parse(_data.srt_path)
	_log("載入字幕: %d 句" % source_subs.size())
	
	# 若為 SRT 模式，解析譯文 SRT
	var target_subs_map = {}
	if _data.sync_mode == ProjectData.SyncMode.BY_SRT:
		var t_subs = SRTParser.parse(_data.trans_srt_path)
		for ts in t_subs: target_subs_map[ts.index] = ts.end_time - ts.start_time

	var concat_str = ""
	var last_end = 0.0
	var idx = 1
	var target_fps_str = str(_data.target_fps)

	for sub in source_subs:
		call_deferred("emit_signal", "progress_updated", idx, source_subs.size())
		
		# --- 1. 間隙 (Gap) ---
		var gap_dur = sub.start_time - last_end
		if gap_dur > 0.1:
			var gap_p = ProjectSettings.globalize_path(temp_dir + "gap_%03d.mp4" % sub.index)
			var gap_args = [
				"-y", "-ss", str(last_end), "-t", str(gap_dur), "-i", safe_video_path,
				"-vf", "scale=%s,fps=%s,setsar=1" % [TARGET_RES, target_fps_str],
				"-ar", TARGET_AR, "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", gap_p
			]
			OS.execute(FFMPEG_CMD, gap_args, [], true)
			concat_str += "file '%s'\n" % gap_p

		# --- 2. 字幕段落 ---
		var orig_dur = sub.end_time - sub.start_time
		if orig_dur <= 0: orig_dur = 0.1
		
		var target_dur = orig_dur
		var has_audio = false
		var wav_path = ""
		
		if _data.sync_mode == ProjectData.SyncMode.BY_AUDIO:
			for ext in ["wav", "mp3"]:
				var try = _data.audio_folder_path.path_join("%03d.%s" % [sub.index, ext])
				if FileAccess.file_exists(try):
					wav_path = ProjectSettings.globalize_path(try)
					has_audio = true
					break
			if has_audio: target_dur = _get_duration(wav_path)
		elif _data.sync_mode == ProjectData.SyncMode.BY_SRT:
			if target_subs_map.has(sub.index): target_dur = target_subs_map[sub.index]

		var speed = target_dur / orig_dur
		var chunk_p = ProjectSettings.globalize_path(temp_dir + "chunk_%03d.mp4" % sub.index)
		
		var args = ["-y", "-ss", str(sub.start_time), "-t", str(orig_dur), "-i", safe_video_path]
		
		# 濾鏡: 補幀判斷
		var filter = ""
		if _data.use_optical_flow:
			filter = "[0:v]setpts=PTS*%.5f,scale=%s,minterpolate='mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1:fps=%s'[v]" % [speed, TARGET_RES, target_fps_str]
		else:
			filter = "[0:v]setpts=PTS*%.5f,scale=%s,fps=%s,setsar=1[v]" % [speed, TARGET_RES, target_fps_str]
		
		if has_audio:
			args.append("-i")
			args.append(wav_path)
			args.append("-filter_complex")
			args.append(filter)
			args.append("-map")
			args.append("[v]")
			args.append("-map")
			args.append("1:a")
		else:
			# 無音檔生成靜音
			args.append("-f")
			args.append("lavfi")
			args.append("-i")
			args.append("anullsrc=channel_layout=stereo:sample_rate=%s" % TARGET_AR)
			args.append("-filter_complex")
			args.append(filter)
			args.append("-map")
			args.append("[v]")
			args.append("-map")
			args.append("1:a")
			args.append("-shortest")
		
		# 編碼參數
		args.append("-ar")
		args.append(TARGET_AR)
		args.append("-c:v")
		args.append("libx264")
		args.append("-preset")
		args.append("ultrafast")
		args.append("-c:a")
		args.append("aac")
		args.append(chunk_p)
		
		OS.execute(FFMPEG_CMD, args, [], true)
		concat_str += "file '%s'\n" % chunk_p
		last_end = sub.end_time
		idx += 1

	# --- 3. 片尾 ---
	var tail_dur = total_video_dur - last_end
	if tail_dur > 0.2:
		var tail_p = ProjectSettings.globalize_path(temp_dir + "tail.mp4")
		var args = ["-y", "-ss", str(last_end), "-t", str(tail_dur), "-i", safe_video_path,
			"-vf", "scale=%s,fps=%s,setsar=1" % [TARGET_RES, target_fps_str],
			"-ar", TARGET_AR, "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", tail_p]
		OS.execute(FFMPEG_CMD, args, [], true)
		concat_str += "file '%s'\n" % tail_p
	
	# --- 4. 合併 ---
	var list_p = ProjectSettings.globalize_path(temp_dir + "list.txt")
	var f = FileAccess.open(list_p, FileAccess.WRITE)
	f.store_string(concat_str)
	f.close()
	
	var final_out = _data.output_path
	if final_out.is_empty(): final_out = _data.video_path.get_base_dir().path_join("output_synced.mp4")
	
	OS.execute(FFMPEG_CMD, ["-y", "-f", "concat", "-safe", "0", "-i", list_p, "-c", "copy", final_out], [], true)
	_log("✅ 完成: " + final_out)
	call_deferred("emit_signal", "processing_finished", true)

func _get_duration(path):
	var out = []
	OS.execute(FFPROBE_CMD, ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", path], out, true)
	if out.size() > 0: return out[0].strip_edges().to_float()
	return 0.0

func _log(msg):
	call_deferred("emit_signal", "log_updated", msg)

func _exit_tree():
	if _thread and _thread.is_started(): _thread.wait_to_finish()
