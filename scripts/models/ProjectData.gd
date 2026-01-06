class_name ProjectData
extends RefCounted

# 定義同步模式枚舉
enum SyncMode { BY_AUDIO, BY_SRT }

# Tab 2 資料
var sync_mode: SyncMode = SyncMode.BY_AUDIO # 預設依賴音檔
var video_path: String = ""
var srt_path: String = ""       # 原文 SRT
var trans_srt_path: String = "" # 新增：譯文 SRT (用來計算時間)
var audio_folder_path: String = ""
var output_path: String = ""

# 用於 Tab 1 的 TXT (維持不變)
var target_txt_path: String = ""

func is_valid_for_sync() -> bool:
	var basic_valid = FileAccess.file_exists(video_path) and FileAccess.file_exists(srt_path)
	
	if not basic_valid: return false
	
	# 根據模式檢查不同的檔案
	if sync_mode == SyncMode.BY_AUDIO:
		return DirAccess.dir_exists_absolute(audio_folder_path)
	elif sync_mode == SyncMode.BY_SRT:
		return FileAccess.file_exists(trans_srt_path)
		
	return false
