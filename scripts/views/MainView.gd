extends Control

# --- Tab 0: Aligner Nodes (文字對齊) ---
@onready var t0_text_srt = %TextSRT
@onready var t0_text_txt = %TextTXT
@onready var t0_lbl_srt_c = %LabelSRTCount
@onready var t0_lbl_txt_c = %LabelTxtCount
@onready var t0_lbl_status = %LabelStatus
@onready var t0_line_split = %LineSplitChars
@onready var t0_popup_txt = %PopupMenuTXT

# --- Tab 1: Splitter Nodes (音訊切割) ---
@onready var t1_line_audio = %LineAudioLong
@onready var t1_line_txt = %LineTxt
@onready var t1_line_out = %LineOutDir
@onready var t1_opt_lang = %OptionLang
@onready var t1_spin_comma = %SpinComma
@onready var t1_spin_period = %SpinPeriod
# 一般按鈕路徑
@onready var t1_btn_start = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/BtnSplitStart"
@onready var t1_btn_xml = $"VBoxMain/TabContainer/1_音訊切割 (Audio)/VBox/BtnExportXML"

# --- Tab 2: Sync Nodes (影片對齊) ---
@onready var t2_line_video = %LineVideo
@onready var t2_line_srt = %LineSRT
@onready var t2_line_audio = %LineAudioFolder
@onready var t2_line_trans_srt = %LineTransSRT
@onready var t2_label_trans = %LabelTrans
@onready var t2_chk_audio = %ChkAudio
@onready var t2_chk_srt = %ChkSRT
@onready var t2_spin_fps = %SpinFPS
@onready var t2_chk_flow = %ChkFlow
@onready var t2_chk_burn = %ChkBurn
@onready var t2_btn_start = $"VBoxMain/TabContainer/2_影片對齊 (Video)/VBox/BtnSyncStart"
@onready var t2_lbl_info_srt = %LblSRT
@onready var t2_lbl_info_audio = %LblAudio
@onready var t2_lbl_info_status = %LblStatus

# --- Tab 3: Merger Nodes (素材串接) ---
@onready var t3_list_pool = %FileList
@onready var t3_list_seq = %SeqList
@onready var t3_line_out = %LineMergeOut
@onready var t3_btn_start = $"VBoxMain/TabContainer/3_素材串接 (Merger)/HBox/VBoxRight/BtnMergeStart"

# --- Common Nodes ---
@onready var log_label = %LogOutput
@onready var progress_bar = %ProgressBar
@onready var file_dialog = %FileDialog

# --- Logic & Data ---
var project_data = ProjectData.new()
var process_manager = ProcessManager.new()
var media_merger = MediaMerger.new()
var split_thread: Thread

# File Dialog Modes
enum FDMode { 
	T0_SRT, T0_TXT, T0_SAVE, 
	T1_AUDIO, T1_TXT, T1_OUT, T1_XML,
	T2_VIDEO, T2_SRT, T2_AUDIO, T2_TRANS,
	T3_IMPORT, T3_SAVE 
}
var curr_mode = FDMode.T0_SRT
var t0_srt_lines_count = 0

func _ready():
	add_child(process_manager)
	add_child(media_merger)
	
	process_manager.log_updated.connect(_log)
	process_manager.progress_updated.connect(func(v, t): 
		progress_bar.max_value = t
		progress_bar.value = v
	)
	process_manager.processing_finished.connect(func(s): 
		t2_btn_start.disabled = false
		_log("處理結束")
	)
	media_merger.log_updated.connect(_log)
	media_merger.processing_finished.connect(func(s): t3_btn_start.disabled = false)
	
	_setup_tab0()
	_setup_tab1()
	_setup_tab2()
	_setup_tab3()
	
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.dir_selected.connect(_on_dir_selected)
	file_dialog.files_selected.connect(_on_files_selected)

func _setup_tab0():
	$"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxTools/BtnLoadSRT".pressed.connect(func(): _open_fd(FDMode.T0_SRT))
	$"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxTools/BtnLoadTXT".pressed.connect(func(): _open_fd(FDMode.T0_TXT))
	$"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxTools/BtnSave".pressed.connect(func(): _open_fd(FDMode.T0_SAVE))
	$"VBoxMain/TabContainer/0_文字對齊 (Aligner)/VBox/HBoxTools/BtnAutoSplit".pressed.connect(_on_t0_auto_split)
	t0_text_txt.text_changed.connect(_on_t0_text_changed)
	
	# 連接點擊事件 (用於同步反白)
	t0_text_srt.gui_input.connect(_on_t0_srt_input)
	t0_text_txt.gui_input.connect(_on_t0_txt_input)
	
	t0_popup_txt.add_item("Google Translate", 0)
	t0_popup_txt.id_pressed.connect(_on_t0_popup_item)

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
	t2_chk_burn.pressed.connect(_update_t2_ui)
	t2_btn_start.pressed.connect(_on_t2_start)
	_update_t2_ui()

func _setup_tab3():
	$"VBoxMain/TabContainer/3_素材串接 (Merger)/HBox/VBoxLeft/BtnAddFiles".pressed.connect(func(): _open_fd(FDMode.T3_IMPORT))
	$"VBoxMain/TabContainer/3_素材串接 (Merger)/HBox/VBoxLeft/BtnAddToSeq".pressed.connect(_on_t3_add_to_seq)
	$"VBoxMain/TabContainer/3_素材串接 (Merger)/HBox/VBoxRight/HBoxSeqTools/BtnSeqUp".pressed.connect(func(): _t3_move_item(-1))
	$"VBoxMain/TabContainer/3_素材串接 (Merger)/HBox/VBoxRight/HBoxSeqTools/BtnSeqDown".pressed.connect(func(): _t3_move_item(1))
	$"VBoxMain/TabContainer/3_素材串接 (Merger)/HBox/VBoxRight/HBoxSeqTools/BtnSeqRemove".pressed.connect(_t3_remove_item)
	$"VBoxMain/TabContainer/3_素材串接 (Merger)/HBox/VBoxRight/HBoxSeqTools/BtnSortName".pressed.connect(_t3_sort_seq)
	$"VBoxMain/TabContainer/3_素材串接 (Merger)/HBox/VBoxRight/HBoxOut/BtnBrowseMergeOut".pressed.connect(func(): _open_fd(FDMode.T3_SAVE))
	t3_btn_start.pressed.connect(_on_t3_start)

# --- Tab 0 Logic ---
func _on_t0_auto_split():
	var txt = t0_text_txt.text.replace("\n", "")
	var chars = t0_line_split.text
	for i in range(chars.length()):
		var c = chars[i]
		txt = txt.replace(c, c + "\n")
	# 清理空行
	var lines = txt.split("\n", false)
	t0_text_txt.text = "\n".join(lines)
	_on_t0_text_changed()

func _on_t0_text_changed():
	var c = t0_text_txt.get_line_count()
	t0_lbl_srt_c.text = "SRT 行數: %d" % t0_srt_lines_count
	t0_lbl_txt_c.text = "譯文 行數: %d" % c
	
	if c == t0_srt_lines_count and c > 0:
		t0_lbl_status.text = "狀態: ✅ 匹配"
		t0_lbl_status.modulate = Color.GREEN
	else:
		t0_lbl_status.text = "狀態: ❌ 差異 %d" % (c - t0_srt_lines_count)
		t0_lbl_status.modulate = Color.RED

# --- Tab 0 Logic 更新版 ---

func _on_t0_srt_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 使用 call_deferred 等待點擊完成，確保讀到的是"新"的游標位置
		call_deferred("_deferred_sync", true)

func _on_t0_txt_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			call_deferred("_deferred_sync", false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			t0_popup_txt.position = get_global_mouse_position()
			t0_popup_txt.popup()

# 新增的中介函式，負責在下一幀讀取正確行數
func _deferred_sync(is_srt_active):
	var line = 0
	if is_srt_active:
		line = t0_text_srt.get_caret_line()
	else:
		line = t0_text_txt.get_caret_line()
	
	_sync_highlight(line, is_srt_active)

func _sync_highlight(line, is_srt_active):
	# 1. 處理左邊 (SRT)
	if line < t0_text_srt.get_line_count():
		# 如果 SRT 是被動的 (我們點的是 TXT)，才需要強制移動 SRT 的視角與游標
		if not is_srt_active:
			t0_text_srt.set_caret_line(line)
			t0_text_srt.center_viewport_to_caret()
		
		# 無論主動被動，都進行全行選取反白 (藍色背景)
		var srt_line_text = t0_text_srt.get_line(line)
		# 注意：select 會移動游標到選取尾端，這對唯讀的 SRT 沒影響，視覺上就是反白
		t0_text_srt.select(line, 0, line, srt_line_text.length())
		
	# 2. 處理右邊 (TXT)
	if line < t0_text_txt.get_line_count():
		# 如果 TXT 是被動的 (我們點的是 SRT)，才強制移動
		if is_srt_active:
			t0_text_txt.set_caret_line(line)
			t0_text_txt.center_viewport_to_caret()
			
			# 被動狀態下，幫忙全選該行，方便查看
			var txt_line_text = t0_text_txt.get_line(line)
			t0_text_txt.select(line, 0, line, txt_line_text.length())
		else:
			# 如果 TXT 是主動的 (我們正在點它準備編輯)，
			# 千萬 "不要" 使用 select() 全選整行，否則你一打字就會把整行覆蓋掉！
			# 這裡我們只清除之前的選取，讓使用者專心編輯
			t0_text_txt.deselect()

func _on_t0_popup_item(id):
	if id == 0:
		var sel = t0_text_txt.get_selected_text()
		if sel.is_empty(): sel = t0_text_txt.text
		OS.shell_open("https://translate.google.com/?text=" + sel.uri_encode())

# --- Tab 1 Logic ---
func _run_splitter(is_xml_only, xml_path=""):
	if t1_line_audio.text.is_empty() or t1_line_txt.text.is_empty(): 
		_log("錯誤: 請輸入檔案")
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
			call_deferred("_splitter_done", ok, "XML匯出: " + xml_path)
		)
	else:
		if t1_line_out.text.is_empty(): return
		split_thread.start(func():
			var ok = AudioSplitter.split_audio(t1_line_audio.text, t1_line_txt.text, t1_line_out.text, p)
			call_deferred("_splitter_done", ok, "切割完成")
		)

func _splitter_done(success, msg):
	t1_btn_start.disabled = false
	if split_thread.is_started(): split_thread.wait_to_finish()
	_log(msg if success else "失敗")
	if success and not msg.contains("XML"):
		project_data.audio_folder_path = t1_line_out.text
		t2_line_audio.text = t1_line_out.text
		_update_t2_ui()

# --- Tab 2 Logic ---
func _update_t2_ui():
	var is_audio = t2_chk_audio.button_pressed
	project_data.sync_mode = ProjectData.SyncMode.BY_AUDIO if is_audio else ProjectData.SyncMode.BY_SRT
	
	if is_audio:
		t2_label_trans.text = "譯文 TXT (燒錄用):"
		t2_line_trans_srt.placeholder_text = "選填，僅燒錄時需要 (.txt)"
		t2_line_trans_srt.modulate.a = 1.0 if t2_chk_burn.button_pressed else 0.5
	else:
		t2_label_trans.text = "譯文 SRT (對齊用):"
		t2_line_trans_srt.placeholder_text = "必填，用於時間對齊 (.srt)"
		t2_line_trans_srt.modulate.a = 1.0
	t2_line_audio.modulate.a = 1.0 if is_audio else 0.5
	_validate_t2()

func _validate_t2():
	t2_lbl_info_srt.text = "SRT: %d" % _count_srt(project_data.srt_path)
	t2_lbl_info_audio.text = "Audio: %d" % _count_files(project_data.audio_folder_path)
	if project_data.is_valid_for_sync():
		t2_btn_start.disabled = false
		t2_lbl_info_status.text = "Status: Ready"
		t2_lbl_info_status.modulate = Color.GREEN
	else:
		t2_btn_start.disabled = true
		t2_lbl_info_status.text = "Status: Missing"
		t2_lbl_info_status.modulate = Color.RED

func _on_t2_start():
	project_data.target_fps = int(t2_spin_fps.value)
	project_data.use_optical_flow = t2_chk_flow.button_pressed
	project_data.burn_subtitles = t2_chk_burn.button_pressed
	t2_btn_start.disabled = true
	process_manager.start_processing(project_data)

# --- Tab 3 Logic ---
func _on_t3_add_to_seq():
	var items = t3_list_pool.get_selected_items()
	for i in items:
		t3_list_seq.add_item(t3_list_pool.get_item_text(i))

func _t3_move_item(dir):
	var sel = t3_list_seq.get_selected_items()
	if sel.is_empty(): return
	var idx = sel[0]
	var new_idx = idx + dir
	if new_idx >= 0 and new_idx < t3_list_seq.item_count:
		var txt = t3_list_seq.get_item_text(idx)
		t3_list_seq.remove_item(idx)
		t3_list_seq.add_item(txt)
		t3_list_seq.move_item(t3_list_seq.item_count-1, new_idx)
		t3_list_seq.select(new_idx)

func _t3_remove_item():
	var sel = t3_list_seq.get_selected_items()
	if sel.is_empty(): return
	t3_list_seq.remove_item(sel[0])

func _t3_sort_seq():
	t3_list_seq.sort_items_by_text()

func _on_t3_start():
	if t3_list_seq.item_count == 0 or t3_line_out.text.is_empty(): return
	var files = []
	for i in range(t3_list_seq.item_count): files.append(t3_list_seq.get_item_text(i))
	t3_btn_start.disabled = true
	media_merger.start_merge(files, t3_line_out.text)

# --- Helpers ---
func _open_fd(mode):
	curr_mode = mode
	match mode:
		FDMode.T0_SRT, FDMode.T2_SRT:
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = ["*.srt ; Subtitle"]
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
		FDMode.T2_TRANS:
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			if project_data.sync_mode == ProjectData.SyncMode.BY_AUDIO:
				file_dialog.filters = ["*.txt ; Text"]
			else:
				file_dialog.filters = ["*.srt ; Subtitle"]
		FDMode.T3_IMPORT:
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
			file_dialog.filters = ["*.mp4, *.wav, *.mp3"]
		FDMode.T3_SAVE:
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.filters = ["*.mp4"]
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
			t1_line_txt.text = path
			project_data.target_txt_path = path
		FDMode.T1_AUDIO:
			t1_line_audio.text = path
			project_data.source_audio_path = path
		FDMode.T1_TXT: t1_line_txt.text = path
		FDMode.T1_XML: _run_splitter(true, path)
		FDMode.T2_VIDEO:
			t2_line_video.text = path
			project_data.video_path = path
		FDMode.T2_SRT:
			project_data.srt_path = path
			t2_line_srt.text = path
		FDMode.T2_TRANS:
			project_data.trans_srt_path = path
			t2_line_trans_srt.text = path
		FDMode.T3_SAVE: t3_line_out.text = path
	_validate_t2()

func _on_files_selected(paths):
	if curr_mode == FDMode.T3_IMPORT:
		for p in paths: t3_list_pool.add_item(p)

func _on_dir_selected(path):
	if curr_mode == FDMode.T1_OUT: t1_line_out.text = path
	elif curr_mode == FDMode.T2_AUDIO: 
		t2_line_audio.text = path
		project_data.audio_folder_path = path
	_validate_t2()

func _log(m): log_label.append_text(str(m) + "\n")
func _count_srt(p): return SRTParser.parse(p).size()
func _count_files(p): 
	var d = DirAccess.open(p)
	if not d: return 0
	d.list_dir_begin()
	var c = 0
	var f = d.get_next()
	while f != "":
		if not d.current_is_dir() and (f.ends_with(".wav") or f.ends_with(".mp3")): c+=1
		f = d.get_next()
	return c
