class_name MediaMerger
extends Node

signal log_updated(msg: String)
signal processing_finished(success: bool)

var _thread: Thread

func start_merge(file_list: Array, output_path: String):
	if _thread and _thread.is_started(): return
	_thread = Thread.new()
	_thread.start(_run.bind(file_list, output_path))

func _run(files, out_path):
	call_deferred("emit_signal", "log_updated", "開始串接 %d 個檔案..." % files.size())
	
	var temp_list = "user://merge_list.txt"
	var f = FileAccess.open(temp_list, FileAccess.WRITE)
	for path in files:
		var abs = ProjectSettings.globalize_path(path)
		f.store_line("file '%s'" % abs)
	f.close()
	
	var abs_list = ProjectSettings.globalize_path(temp_list)
	var args = [
		"-y", "-f", "concat", "-safe", "0",
		"-i", abs_list,
		"-c", "copy", # 假設規格一致，使用 Copy 模式最快
		out_path
	]
	
	OS.execute("ffmpeg", args, [], true)
	call_deferred("emit_signal", "log_updated", "✅ 串接完成: " + out_path)
	call_deferred("emit_signal", "processing_finished", true)

func _exit_tree():
	if _thread and _thread.is_started(): _thread.wait_to_finish()
