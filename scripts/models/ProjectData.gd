class_name ProjectData
extends RefCounted

enum SyncMode { BY_AUDIO, BY_SRT }

# --- Tab 0 & 1 資料 ---
var raw_srt_path: String = ""       # 來源 SRT
var target_txt_path: String = ""    # 對齊後的 TXT
var source_audio_path: String = ""  # 來源長音檔
var split_output_dir: String = ""   # 切割輸出資料夾

# --- Tab 2 資料 ---
var sync_mode: SyncMode = SyncMode.BY_AUDIO
var video_path: String = ""
var srt_path: String = ""           
var trans_srt_path: String = ""     # 共用欄位：TXT(燒錄文字) 或 SRT(對齊+燒錄)
var audio_folder_path: String = ""  
var output_path: String = ""

# --- 畫質與燒錄設定 ---
var target_fps: int = 60
var use_optical_flow: bool = false
var burn_subtitles: bool = false    # [新增] 是否燒錄字幕

func is_valid_for_sync() -> bool:
	var basic = FileAccess.file_exists(video_path) and FileAccess.file_exists(srt_path)
	if not basic: return false
	
	if sync_mode == SyncMode.BY_AUDIO:
		# 若要燒字幕，則必須有翻譯檔
		if burn_subtitles and not FileAccess.file_exists(trans_srt_path):
			return false
		return DirAccess.dir_exists_absolute(audio_folder_path)
	elif sync_mode == SyncMode.BY_SRT:
		return FileAccess.file_exists(trans_srt_path)
	return false
