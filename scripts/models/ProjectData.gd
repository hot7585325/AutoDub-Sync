class_name ProjectData
extends RefCounted

# --- Enum 定義 ---
enum SyncMode { BY_AUDIO, BY_SRT }

# --- Tab 0 & 1 資料 (對齊與切割) ---
var raw_srt_path: String = ""       # 原始 SRT (用來參考行數)
var target_txt_path: String = ""    # 整理後的 TXT
var source_audio_path: String = ""  # 來源長音檔
var split_output_dir: String = ""   # 切割輸出目錄

# --- Tab 2 資料 (合成) ---
var sync_mode: SyncMode = SyncMode.BY_AUDIO
var video_path: String = ""
var srt_path: String = ""           # 通常等於 raw_srt_path
var trans_srt_path: String = ""     # 若使用 BY_SRT 模式
var audio_folder_path: String = ""  # 通常等於 split_output_dir
var output_path: String = ""

# --- 畫質設定 ---
var target_fps: int = 60
var use_optical_flow: bool = false

func is_valid_for_sync() -> bool:
	var basic = FileAccess.file_exists(video_path) and FileAccess.file_exists(srt_path)
	if not basic: return false
	
	if sync_mode == SyncMode.BY_AUDIO:
		return DirAccess.dir_exists_absolute(audio_folder_path)
	elif sync_mode == SyncMode.BY_SRT:
		return FileAccess.file_exists(trans_srt_path)
	return false
