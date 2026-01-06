extends Control

# --- Tab 1: Prep Nodes ---
@onready var t1_line_audio = $"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/GridInputs/LineAudioLong"
@onready var t1_line_txt = $"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/GridInputs/LineTxt"
@onready var t1_line_out = $"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/GridInputs/LineOutDir"
@onready var t1_spin_comma = $"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/HBoxParams/SpinComma"
@onready var t1_spin_period = $"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/HBoxParams/SpinPeriod"
@onready var t1_btn_start = $"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/BtnSplitStart"

# --- Tab 2: Sync Nodes ---
@onready var t2_line_video = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/LineVideo"
@onready var t2_line_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/LineSRT"
@onready var t2_line_audio = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/LineAudioFolder"
@onready var t2_line_trans_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/LineTransSRT"

@onready var t2_btn_audio = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/BtnAudioFolder"
@onready var t2_btn_trans_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/BtnTransSRT"
@onready var t2_btn_start = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/BtnSyncStart"

# Radio Buttons
@onready var radio_audio = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/HBoxMode/CheckBox_Audio"
@onready var radio_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/HBoxMode/CheckBox_SRT"

# Info Panel
@onready var t2_lbl_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/InfoPanel/HBoxInfo/LblSRT"
@onready var t2_lbl_txt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/InfoPanel/HBoxInfo/LblTXT"
@onready var t2_lbl_audio = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/InfoPanel/HBoxInfo/LblAudio"
@onready var t2_lbl_status = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/InfoPanel/HBoxInfo/LblStatus"

# --- Shared Nodes ---
@onready var tab_container = $VBoxMain/TabContainer
@onready var progress_bar = $VBoxMain/ProgressBar
@onready var log_label = $VBoxMain/LogOutput
@onready var file_dialog = $FileDialog

# --- Logic & Data ---
var project_data = ProjectData.new()
var process_manager: ProcessManager
var split_thread: Thread

# File Dialog Mode
enum Mode { T1_AUDIO, T1_TXT, T1_OUT, T2_VIDEO, T2_SRT, T2_AUDIO, T2_TRANS_SRT }
var curr_mode = Mode.T1_AUDIO

func _ready():
	process_manager = ProcessManager.new()
	add_child(process_manager)
	
	# 連接信號
	process_manager.log_updated.connect(_log)
	process_manager.progress_updated.connect(_on_progress)
	process_manager.processing_finished.connect(_on_sync_finished)
	
	# Tab 1 按鈕
	$"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/GridInputs/BtnBrowseLong".pressed.connect(func(): _open_fd(Mode.T1_AUDIO))
	$"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/GridInputs/BtnBrowseTxt".pressed.connect(func(): _open_fd(Mode.T1_TXT))
	$"VBoxMain/TabContainer/1_音訊預處理 (Audio)/VBox/GridInputs/BtnBrowseOutDir".pressed.connect(func(): _open_fd(Mode.T1_OUT))
	
	# Tab 2 按鈕
	$"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/BtnVideo".pressed.connect(func(): _open_fd(Mode.T2_VIDEO))
	$"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/BtnSRT".pressed.connect(func(): _open_fd(Mode.T2_SRT))
	t2_btn_audio.pressed.connect(func(): _open_fd(Mode.T2_AUDIO))
	t2_btn_trans_srt.pressed.connect(func(): _open_fd(Mode.T2_TRANS_SRT))
	
	# 執行按鈕
	t1_btn_start.pressed.connect(_on_split_pressed)
	t2_btn_start.pressed.connect(_on_sync_pressed)
	
	# Radio Button 切換
	radio_audio.pressed.connect(_on_mode_toggled)
	radio_srt.pressed.connect(_on_mode_toggled)
	
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.dir_selected.connect(_on_dir_selected)
	
	# 初始化 UI 狀態
	_on_mode_toggled()

func _on_mode_toggled():
	var is_audio_mode = radio_audio.button_pressed
	
	# 設定資料層
	project_data.sync_mode = ProjectData.SyncMode.BY_AUDIO if is_audio_mode else ProjectData.SyncMode.BY_SRT
	
	# 控制 UI 可用性 (視覺反黑)
	# 1. 音訊按鈕
	t2_btn_audio.disabled = not is_audio_mode
	t2_line_audio.modulate.a = 1.0 if is_audio_mode else 0.3
	
	# 2. 譯文 SRT 按鈕
	t2_btn_trans_srt.disabled = is_audio_mode
	t2_line_trans_srt.modulate.a = 1.0 if not is_audio_mode else 0.3
	
	# 刷新檢查
	_validate_dashboard()

func _open_fd(mode):
	curr_mode = mode
	match mode:
		Mode.T1_AUDIO: _config_fd(FileDialog.FILE_MODE_OPEN_FILE, ["*.wav, *.mp3 ; Audio"])
		Mode.T1_TXT: _config_fd(FileDialog.FILE_MODE_OPEN_FILE, ["*.txt"])
		Mode.T1_OUT: _config_fd(FileDialog.FILE_MODE_OPEN_DIR, [])
		
		Mode.T2_VIDEO: _config_fd(FileDialog.FILE_MODE_OPEN_FILE, ["*.mp4, *.mkv"])
		Mode.T2_SRT: _config_fd(FileDialog.FILE_MODE_OPEN_FILE, ["*.srt"])
		Mode.T2_AUDIO: _config_fd(FileDialog.FILE_MODE_OPEN_DIR, [])
		Mode.T2_TRANS_SRT: _config_fd(FileDialog.FILE_MODE_OPEN_FILE, ["*.srt"])
	
	file_dialog.popup_centered()

func _config_fd(mode, filters):
	file_dialog.file_mode = mode
	file_dialog.filters = filters

func _on_file_selected(path):
	match curr_mode:
		Mode.T1_AUDIO: t1_line_audio.text = path
		Mode.T1_TXT: 
			t1_line_txt.text = path
			project_data.target_txt_path = path
			_validate_dashboard()
		Mode.T2_VIDEO: 
			t2_line_video.text = path
			project_data.video_path = path
		Mode.T2_SRT: 
			t2_line_srt.text = path
			project_data.srt_path = path
			_validate_dashboard()
		Mode.T2_TRANS_SRT:
			t2_line_trans_srt.text = path
			project_data.trans_srt_path = path
			_validate_dashboard()

func _on_dir_selected(path):
	match curr_mode:
		Mode.T1_OUT: t1_line_out.text = path
		Mode.T2_AUDIO: 
			t2_line_audio.text = path
			project_data.audio_folder_path = path
			_validate_dashboard()

# --- Tab 1 Logic ---
func _on_split_pressed():
	if t1_line_audio.text.is_empty() or t1_line_txt.text.is_empty() or t1_line_out.text.is_empty():
		_log("錯誤：請填寫 Tab 1 所有欄位")
		return
	t1_btn_start.disabled = true
	progress_bar.value = 0
	split_thread = Thread.new()
	split_thread.start(_run_split_task.bind(t1_line_audio.text, t1_line_txt.text, t1_line_out.text, t1_spin_comma.value, t1_spin_period.value))

func _run_split_task(audio, txt, out, comma, period):
	_log("正在分析並切割音檔...")
	var params = AudioSplitter.SplitParams.new()
	params.comma_weight = comma
	params.period_weight = period
	var success = AudioSplitter.split_audio(audio, txt, out, params)
	call_deferred("_on_split_finished", success, out)

func _on_split_finished(success, out_dir):
	t1_btn_start.disabled = false
	if split_thread.is_started(): split_thread.wait_to_finish()
	if success:
		_log("[color=green]切割完成！[/color]")
		project_data.audio_folder_path = out_dir
		t2_line_audio.text = out_dir
		# 切換到 Tab 2 且選為音訊模式
		radio_audio.button_pressed = true
		_on_mode_toggled()
		tab_container.current_tab = 1
	else:
		_log("[color=red]切割失敗[/color]")

# --- Tab 2 Logic ---
func _validate_dashboard():
	# 根據目前模式顯示資訊
	var srt_c = _count_lines(project_data.srt_path, true)
	var txt_c = _count_lines(project_data.target_txt_path, false)
	
	t2_lbl_srt.text = "SRT: %d" % srt_c
	t2_lbl_txt.text = "TXT: %d" % txt_c
	
	# 依模式檢查
	var valid = project_data.is_valid_for_sync()
	
	if not valid:
		t2_lbl_status.text = "缺必要檔案"
		t2_lbl_status.modulate = Color.GRAY
		t2_btn_start.disabled = true
		t2_lbl_audio.text = "Audio: -"
		return
		
	if project_data.sync_mode == ProjectData.SyncMode.BY_AUDIO:
		var audio_c = _count_files(project_data.audio_folder_path, ["wav", "mp3"])
		t2_lbl_audio.text = "Audio: %d" % audio_c
		
		if audio_c > 0 and srt_c > 0:
			t2_btn_start.disabled = false
			t2_lbl_status.text = "就緒 (依音檔)"
			t2_lbl_status.modulate = Color.GREEN
		else:
			t2_btn_start.disabled = true
			t2_lbl_status.text = "無音檔"
			t2_lbl_status.modulate = Color.RED
			
	elif project_data.sync_mode == ProjectData.SyncMode.BY_SRT:
		var trans_srt_c = _count_lines(project_data.trans_srt_path, true)
		t2_lbl_audio.text = "Trans SRT: %d" % trans_srt_c
		
		if trans_srt_c == srt_c:
			t2_btn_start.disabled = false
			t2_lbl_status.text = "就緒 (依SRT)"
			t2_lbl_status.modulate = Color.GREEN
		else:
			t2_btn_start.disabled = false # 允許容錯
			t2_lbl_status.text = "警告：行數不一"
			t2_lbl_status.modulate = Color.YELLOW

func _on_sync_pressed():
	t2_btn_start.disabled = true
	process_manager.start_processing(project_data)

func _on_progress(val, total):
	progress_bar.max_value = total
	progress_bar.value = val

func _on_sync_finished(success):
	t2_btn_start.disabled = false

func _log(msg):
	log_label.append_text(str(msg) + "\n")

func _count_lines(path, is_srt):
	if path.is_empty(): return 0
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return 0
	var txt = f.get_as_text()
	if is_srt: return txt.count(" --> ")
	return txt.split("\n", false).size()

func _count_files(dir_path, exts):
	if dir_path.is_empty(): return 0
	var dir = DirAccess.open(dir_path)
	if not dir: return 0
	dir.list_dir_begin()
	var c = 0
	var fn = dir.get_next()
	while fn != "":
		if not dir.current_is_dir():
			for ext in exts:
				if fn.to_lower().ends_with(ext): 
					c+=1
					break
		fn = dir.get_next()
	return c
