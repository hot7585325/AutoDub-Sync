# res://scripts/logic/ProcessManager.gd
class_name ProcessManager
extends Node

# 定義信號與 UI 溝通
signal log_updated(msg: String)
signal progress_updated(value: float, total: float)
signal processing_finished(success: bool)

var _thread: Thread
var _data: ProjectData

# FFmpeg 執行檔路徑 (假設放在專案目錄或系統環境變數)
const FFMPEG_CMD = "ffmpeg" 
const FFPROBE_CMD = "ffprobe"

func start_processing(data: ProjectData):
	if _thread and _thread.is_started():
		return # 防止重複執行
	
	_data = data
	_thread = Thread.new()
	# 在背景執行 _run_thread 函式
	_thread.start(_run_task)

# --- 以下在背景執行緒運行，不可直接碰 UI ---
func _run_task():
	_log("開始處理...")
	
	# 1. 建立臨時工作目錄 (解決中文路徑問題的關鍵)
	var temp_dir = "user://temp_work/"
	var dir = DirAccess.open("user://")
	if dir.dir_exists("temp_work"):
		# 簡單清理 (實際專案要遞迴刪除)
		pass 
	else:
		dir.make_dir("temp_work")
		
	# 2. 將素材複製到 Temp 並改名為英文
	# 這一步是為了確保 FFmpeg 不會因為路徑亂碼而失敗
	var safe_video = ProjectSettings.globalize_path(temp_dir + "source.mp4")
	var safe_list_txt = ProjectSettings.globalize_path(temp_dir + "list.txt")
	
	dir.copy(_data.video_path, temp_dir + "source.mp4")
	_log("已複製影片到臨時區")

	# 3. 解析 SRT
	var subtitles = SRTParser.parse(_data.srt_path)
	_log("解析出 %d 句字幕" % subtitles.size())
	
	var concat_list_content = ""
	var file_idx = 1
	
	# 4. 迴圈處理每一句
	for sub in subtitles:
		call_deferred("emit_signal", "progress_updated", file_idx, subtitles.size())
		
		# A. 計算原始時長
		var original_dur = sub.end_time - sub.start_time
		
		# B. 獲取對應音檔時長 (假設命名為 001.wav, 002.wav...)
		# 注意：這裡需要補零邏輯
		var wav_name = "%03d.wav" % sub.index
		var wav_path = _data.audio_folder_path.path_join(wav_name)
		
		# 檢查音檔是否存在
		if not FileAccess.file_exists(wav_path):
			_log("錯誤：找不到音檔 " + wav_name)
			file_idx += 1
			continue
			
		var target_dur = _get_audio_duration(wav_path)
		
		# C. 計算縮放倍率
		# 如果目標音檔是 5秒，原片是 2秒，倍率 = 2.5 (變慢/拉長)
		var speed_factor = target_dur / original_dur
		
		# D. 生成單句影片片段
		var chunk_name = "chunk_%03d.mp4" % sub.index
		var chunk_path = ProjectSettings.globalize_path(temp_dir + chunk_name)
		
		# 組裝 FFmpeg 指令
		# 1. 切割 (-ss -t)
		# 2. 變速 (setpts)
		# 3. 強制統一格式 (scale, fps) 避免 concat 失敗
		# 4. 替換音訊 (-i wav -map...)
		
		var cmd_args = [
			"-y",
			"-ss", str(sub.start_time),
			"-t", str(original_dur),
			"-i", safe_video,
			"-i", wav_path,
			"-filter_complex", 
			"[0:v]setpts=PTS*%.5f,scale=1920:1080,fps=30[v]" % speed_factor,
			"-map", "[v]", 
			"-map", "1:a", # 使用 wav 的音訊
			"-shortest",   # 以最短的流為準
			chunk_path
		]
		
		var output = []
		OS.execute(FFMPEG_CMD, cmd_args, output, true)
		
		# 寫入 concat 列表
		# 注意：ffmpeg concat 需要 'file path' 格式，Windows 路徑要轉義
		concat_list_content += "file '%s'\n" % chunk_path
		
		_log("已處理片段: " + chunk_name + " (倍率: %.2f)" % speed_factor)
		file_idx += 1

	# 5. 執行合併 (Concat)
	var list_file = FileAccess.open(temp_dir + "list.txt", FileAccess.WRITE)
	list_file.store_string(concat_list_content)
	list_file.close()
	
	var final_output = _data.output_path
	if final_output.is_empty():
		final_output = _data.video_path.get_base_dir().path_join("output_synced.mp4")

	var concat_args = [
		"-y",
		"-f", "concat",
		"-safe", "0",
		"-i", safe_list_txt,
		"-c", "copy", # 直接複製流，不重新編碼，極快
		final_output
	]
	
	_log("正在合併檔案...")
	OS.execute(FFMPEG_CMD, concat_args, [], true)
	
	_log("完成！輸出檔案：" + final_output)
	call_deferred("emit_signal", "processing_finished", true)

func _get_audio_duration(path: String) -> float:
	# 使用 ffprobe 快速獲取時長
	var output = []
	var args = ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", path]
	OS.execute(FFPROBE_CMD, args, output, true)
	if output.size() > 0:
		return output[0].strip_edges().to_float()
	return 1.0

func _log(msg: String):
	# 使用 call_deferred 安全地呼叫主執行緒的信號
	call_deferred("emit_signal", "log_updated", msg)

func _exit_tree():
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
