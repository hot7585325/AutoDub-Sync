extends Control

# --- Tab 0: Aligner Nodes (文字對齊) ---
@onready var t0_text_srt = $"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxEditors/VBoxLeft/TextSRT"
@onready var t0_text_txt = $"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxEditors/VBoxRight/TextTXT"
@onready var t0_lbl_srt_c = $"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxInfo/LabelSRTCount"
@onready var t0_lbl_txt_c = $"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxInfo/LabelTxtCount"
@onready var t0_lbl_status = $"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxInfo/LabelStatus"
@onready var t0_chk_period = $"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/PanelRules/HBoxRules/HBoxRules/ChkPeriod"
@onready var t0_chk_comma = $"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/PanelRules/HBoxRules/HBoxRules/ChkComma"
@onready var t0_chk_space = $"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/PanelRules/HBoxRules/HBoxRules/ChkSpace"

# --- Tab 1: Splitter Nodes (音訊切割) ---
@onready var t1_line_audio = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/GridInputs/LineAudioLong"
@onready var t1_line_txt = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/GridInputs/LineTxt"
@onready var t1_line_out = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/GridInputs/LineOutDir"
@onready var t1_opt_lang = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/HBoxParams/OptionLang"
@onready var t1_spin_comma = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/HBoxParams/SpinComma"
@onready var t1_spin_period = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/HBoxParams/SpinPeriod"
@onready var t1_btn_start = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/BtnSplitStart"
@onready var t1_btn_xml = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/BtnExportXML"

# --- Tab 2: Sync Nodes (影片對齊) ---
@onready var t2_line_video = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/LineVideo"
@onready var t2_line_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/LineSRT"
@onready var t2_line_audio = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/LineAudioFolder"
@onready var t2_line_trans_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/LineTransSRT"
@onready var t2_chk_audio = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/HBoxMode/ChkAudio"
@onready var t2_chk_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/HBoxMode/ChkSRT"
@onready var t2_spin_fps = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/HBoxSettings/SpinFPS"
@onready var t2_chk_flow = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/HBoxSettings/ChkFlow" # 修正變數名稱
@onready var t2_btn_start = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/BtnSyncStart"
@onready var t2_lbl_info_srt = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/InfoPanel/HBoxInfo/LblSRT"
@onready var t2_lbl_info_audio = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/InfoPanel/HBoxInfo/LblAudio"
@onready var t2_lbl_info_status = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/InfoPanel/HBoxInfo/LblStatus"

# --- Common Nodes ---
@onready var log_label = $VBoxMain/LogOutput
@onready var progress_bar = $VBoxMain/ProgressBar
@onready var file_dialog = $FileDialog

# --- Logic & Data ---
var project_data = ProjectData.new()
var process_manager = ProcessManager.new()
var split_thread: Thread

# File Dialog Modes
enum FDMode { 
	T0_SRT, T0_TXT, T0_SAVE, 
	T1_AUDIO, T1_TXT, T1_OUT, T1_XML,
	T2_VIDEO, T2_SRT, T2_AUDIO, T2_TRANS 
}
var curr_mode = FDMode.T0_SRT
var t0_srt_lines_count = 0

func _ready():
	add_child(process_manager)
	
	# 連接核心信號
	process_manager.log_updated.connect(_log)
	process_manager.progress_updated.connect(func(v, t): 
		progress_bar.max_value = t
		progress_bar.value = v
	)
	process_manager.processing_finished.connect(func(s): 
		t2_btn_start.disabled = false
		_log("處理結束")
	)
	
	_setup_tab0()
	_setup_tab1()
	_setup_tab2()
	
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.dir_selected.connect(_on_dir_selected)

func _setup_tab0():
	$"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxTools/BtnLoadSRT".pressed.connect(func(): _open_fd(FDMode.T0_SRT))
	$"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxTools/BtnLoadTXT".pressed.connect(func(): _open_fd(FDMode.T0_TXT))
	$"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxTools/BtnSave".pressed.connect(func(): _open_fd(FDMode.T0_SAVE))
	$"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxTools/BtnAutoSplit".pressed.connect(_on_t0_auto_split)
	t0_text_txt.text_changed.connect(_on_t0_text_changed)

func _setup_tab1():
	$"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/GridInputs/BtnBrowseLong".pressed.connect(func(): _open_fd(FDMode.T1_AUDIO))
	$"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/GridInputs/BtnBrowseTxt".pressed.connect(func(): _open_fd(FDMode.T1_TXT))
	$"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/GridInputs/BtnBrowseOutDir".pressed.connect(func(): _open_fd(FDMode.T1_OUT))
	t1_btn_start.pressed.connect(func(): _run_splitter(false))
	t1_btn_xml.pressed.connect(func(): _open_fd(FDMode.T1_XML))
	
	t1_opt_lang.add_item("CJK (中日韓)", 0)
	t1_opt_lang.add_item("Latin (歐美)", 1)

func _setup_tab2():
	$"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/BtnVideo".pressed.connect(func(): _open_fd(FDMode.T2_VIDEO))
	$"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/BtnSRT".pressed.connect(func(): _open_fd(FDMode.T2_SRT))
	$"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/BtnAudioFolder".pressed.connect(func(): _open_fd(FDMode.T2_AUDIO))
	$"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/GridInputs/BtnTransSRT".pressed.connect(func(): _open_fd(FDMode.T2_TRANS))
	
	t2_chk_audio.pressed.connect(_update_t2_ui)
	t2_chk_srt.pressed.connect(_update_t2_ui)
	t2_btn_start.pressed.connect(_on_t2_start)
	
	# 初始化 Tab 2 狀態
	_update_t2_ui()

# --- Tab 0 Logic: 文字對齊 ---
func _on_t0_auto_split():
	var txt = t0_text_txt.text.replace("\n", "")
	var delims = []
	if t0_chk_period.button_pressed: delims.append_array(["。", "！", "？", ".", "!", "?"])
	if t0_chk_comma.button_pressed: delims.append_array(["，", "、", ",", "…"])
	if t0_chk_space.button_pressed: delims.append(" ")
	
	for d in delims:
		var r = d.strip_edges() + "\n"
		if d == " ": r = "\n"
		txt = txt.replace(d, r)
	
	t0_text_txt.text = txt
	_on_t0_text_changed()

func _on_t0_text_changed():
	var lines = t0_text_txt.text.split("\n", false)
	var c = lines.size()
	
	t0_lbl_srt_c.text = "SRT 行數: %d" % t0_srt_lines_count
	t0_lbl_txt_c.text = "譯文 行數: %d" % c
	
	if c == t0_srt_lines_count and c > 0:
		t0_lbl_status.text = "狀態: ✅ 完美匹配"
		t0_lbl_status.modulate = Color.GREEN
	else:
		var diff = c - t0_srt_lines_count
		t0_lbl_status.text = "狀態: ❌ 差異 %d 行" % diff
		t0_lbl_status.modulate = Color.RED

# --- Tab 1 Logic: 音訊切割 ---
func _run_splitter(is_xml_only, xml_path=""):
	if t1_line_audio.text.is_empty() or t1_line_txt.text.is_empty():
		_log("錯誤: 請選擇音檔與文字檔")
		return
	
	t1_btn_start.disabled = true
	var p = AudioSplitter.SplitParams.new()
	p.comma_weight = t1_spin_comma.value
	p.period_weight = t1_spin_period.value
	p.is_latin_mode = (t1_opt_lang.selected == 1)
	
	split_thread = Thread.new()
	if is_xml_only:
		split_thread.start(func(): 
			var ok = AudioSplitter.generate_xml(t1_line_audio.text, t1_line_txt.text, xml_path, p)
			call_deferred("_splitter_done", ok, "XML 已匯出: " + xml_path)
		)
	else:
		if t1_line_out.text.is_empty(): 
			_log("錯誤: 請選擇輸出資料夾")
			t1_btn_start.disabled = false
			return
			
		split_thread.start(func():
			var ok = AudioSplitter.split_audio(t1_line_audio.text, t1_line_txt.text, t1_line_out.text, p)
			call_deferred("_splitter_done", ok, "切割完成")
		)

func _splitter_done(success, msg):
	t1_btn_start.disabled = false
	if split_thread.is_started(): split_thread.wait_to_finish()
	
	if success:
		_log("✅ " + msg)
		# 如果是執行切割，自動幫忙設定 Tab 2
		if not msg.contains("XML"):
			project_data.audio_folder_path = t1_line_out.text
			t2_line_audio.text = t1_line_out.text
			_update_t2_ui()
	else:
		_log("❌ 失敗，請檢查輸入檔案")

# --- Tab 2 Logic: 影片合成 ---
func _update_t2_ui():
	var is_audio = t2_chk_audio.button_pressed
	project_data.sync_mode = ProjectData.SyncMode.BY_AUDIO if is_audio else ProjectData.SyncMode.BY_SRT
	
	# UI 反黑
	t2_line_audio.modulate.a = 1.0 if is_audio else 0.5
	t2_line_trans_srt.modulate.a = 1.0 if not is_audio else 0.5
	
	_validate_t2()

func _validate_t2():
	var srt_c = _count_srt(project_data.srt_path)
	t2_lbl_info_srt.text = "SRT: %d" % srt_c
	
	var audio_c = _count_files(project_data.audio_folder_path)
	t2_lbl_info_audio.text = "Audio: %d" % audio_c
	
	# 檢查是否可以開始
	if project_data.is_valid_for_sync():
		t2_btn_start.disabled = false
		t2_lbl_info_status.text = "Status: Ready"
		t2_lbl_info_status.modulate = Color.GREEN
	else:
		t2_btn_start.disabled = true
		t2_lbl_info_status.text = "Status: Missing Files"
		t2_lbl_info_status.modulate = Color.RED

func _on_t2_start():
	# 寫入畫質設定
	project_data.target_fps = int(t2_spin_fps.value)
	project_data.use_optical_flow = t2_chk_flow.button_pressed
	
	if project_data.use_optical_flow:
		_log("⚠️ 已開啟 AI 補幀，處理速度會顯著變慢...")
		
	t2_btn_start.disabled = true
	process_manager.start_processing(project_data)

# --- Helpers ---
func _open_fd(mode):
	curr_mode = mode
	match mode:
		FDMode.T0_SRT, FDMode.T2_SRT, FDMode.T2_TRANS: 
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = ["*.srt ; Subtitles"]
		FDMode.T0_TXT, FDMode.T1_TXT: 
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = ["*.txt ; Text"]
		FDMode.T0_SAVE: 
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.filters = ["*.txt ; Text"]
		FDMode.T1_XML:
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.filters = ["*.xml ; FCPXML"]
		FDMode.T1_AUDIO: 
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = ["*.wav, *.mp3 ; Audio"]
		FDMode.T1_OUT, FDMode.T2_AUDIO: 
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
			file_dialog.filters = []
		FDMode.T2_VIDEO: 
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = ["*.mp4, *.mkv ; Video"]
	
	file_dialog.popup_centered()

func _on_file_selected(path):
	match curr_mode:
		FDMode.T0_SRT:
			var subs = SRTParser.parse(path)
			t0_srt_lines_count = subs.size()
			var txt = ""
			for s in subs: txt += "[%d] %s\n" % [s.index, s.text]
			t0_text_srt.text = txt
			_on_t0_text_changed()
			# 連動設定到 Tab 1 & 2
			project_data.raw_srt_path = path
			project_data.srt_path = path
			t2_line_srt.text = path
		FDMode.T0_TXT:
			var f = FileAccess.open(path, FileAccess.READ)
			if f: t0_text_txt.text = f.get_as_text()
			_on_t0_text_changed()
		FDMode.T0_SAVE:
			var f = FileAccess.open(path, FileAccess.WRITE)
			if f: f.store_string(t0_text_txt.text)
			# 連動設定到 Tab 1
			t1_line_txt.text = path
			project_data.target_txt_path = path
		FDMode.T1_AUDIO:
			t1_line_audio.text = path
			project_data.source_audio_path = path
		FDMode.T1_TXT:
			t1_line_txt.text = path
		FDMode.T1_XML:
			_run_splitter(true, path)
		FDMode.T2_VIDEO:
			t2_line_video.text = path
			project_data.video_path = path
		FDMode.T2_SRT:
			project_data.srt_path = path
			t2_line_srt.text = path
		FDMode.T2_TRANS:
			project_data.trans_srt_path = path
			t2_line_trans_srt.text = path
	
	_validate_t2()

func _on_dir_selected(path):
	if curr_mode == FDMode.T1_OUT: 
		t1_line_out.text = path
	elif curr_mode == FDMode.T2_AUDIO: 
		t2_line_audio.text = path
		project_data.audio_folder_path = path
	
	_validate_t2()

func _log(msg): 
	log_label.append_text(str(msg) + "\n")

func _count_srt(p): 
	return SRTParser.parse(p).size()

func _count_files(p): 
	var d = DirAccess.open(p)
	if not d: return 0
	d.list_dir_begin()
	var c = 0
	var f = d.get_next()
	while f != "":
		if not d.current_is_dir():
			# 寬鬆檢查 wav 或 mp3
			var low = f.to_lower()
			if low.ends_with(".wav") or low.ends_with(".mp3"): c+=1
		f = d.get_next()
	return c
