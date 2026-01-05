# res://scripts/models/ProjectData.gd
class_name ProjectData
extends RefCounted

var video_path: String = ""
var srt_path: String = ""
var audio_folder_path: String = ""
var output_path: String = ""

# 設定參數
var use_minterpolate: bool = false
var target_fps: int = 30

func is_valid() -> bool:
	return FileAccess.file_exists(video_path) and \
		   FileAccess.file_exists(srt_path) and \
		   DirAccess.dir_exists_absolute(audio_folder_path)
