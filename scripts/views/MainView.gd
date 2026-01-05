# res://scripts/views/MainView.gd
extends Control

# UI 節點參考 (請在編輯器中拉線或命名正確)
@onready var btn_video = $VBox/HBoxVideo/Button
@onready var btn_srt = $VBox/HBoxSRT/Button
@onready var btn_audio = $VBox/HBoxAudio/Button
@onready var btn_start = $VBox/BtnStart
@onready var log_label = $VBox/LogOutput
@onready var progress_bar = $VBox/ProgressBar
@onready var file_dialog = $FileDialog

var project_data = ProjectData.new()
var process_manager: ProcessManager
# 定義一個變數來記錄當前是哪一個按鈕觸發了檔案選擇
enum SelectMode { NONE, VIDEO, SRT, AUDIO_DIR }
var current_mode = SelectMode.NONE


func _ready():
    # 初始化邏輯管理器
    process_manager = ProcessManager.new()
    add_child(process_manager)
    
    # 連接信號
    process_manager.log_updated.connect(_on_log)
    process_manager.progress_updated.connect(_on_progress)
    process_manager.processing_finished.connect(_on_finished)
    
    btn_video.pressed.connect(func(): _open_dialog(SelectMode.VIDEO))
    btn_srt.pressed.connect(func(): _open_dialog(SelectMode.SRT))
    btn_audio.pressed.connect(func(): _open_dialog(SelectMode.AUDIO_DIR))
    
    # 連接 UI
    btn_start.pressed.connect(_on_start_pressed)
    # 這裡省略 FileDialog 的連接代碼，邏輯是點按鈕 -> 跳視窗 -> 存路徑到 project_data

func _on_start_pressed():
    if not project_data.is_valid():
        _log("錯誤：請檢查所有檔案路徑是否正確")
        return
        
    btn_start.disabled = true
    progress_bar.value = 0
    process_manager.start_processing(project_data)

func _on_log(msg: String):
    log_label.append_text(msg + "\n")

func _on_progress(current, total):
    progress_bar.max_value = total
    progress_bar.value = current

func _on_finished(success):
    btn_start.disabled = false
    if success:
        _log("=== 處理完畢 ===")
    else:
        _log("=== 處理失敗 ===")

func _log(msg):
    log_label.append_text("[color=yellow]" + msg + "[/color]\n")

func _open_dialog(mode):
    current_mode = mode
    if mode == SelectMode.VIDEO:
        file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
        file_dialog.filters = ["*.mp4, *.mov, *.avi ; Video Files"]
    elif mode == SelectMode.SRT:
        file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
        file_dialog.filters = ["*.srt ; Subtitle Files"]
    elif mode == SelectMode.AUDIO_DIR:
        file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
        file_dialog.filters = []
    
    file_dialog.popup()

func _on_file_selected(path):
    match current_mode:
        SelectMode.VIDEO:
            project_data.video_path = path
            $VBox/HBoxVideo/LineEdit.text = path
            _log("已選擇影片: " + path.get_file())
        SelectMode.SRT:
            project_data.srt_path = path
            $VBox/HBoxSRT/LineEdit.text = path
            _log("已選擇字幕: " + path.get_file())

func _on_dir_selected(path):
    if current_mode == SelectMode.AUDIO_DIR:
        project_data.audio_folder_path = path
        $VBox/HBoxAudio/LineEdit.text = path
        _log("已選擇音檔目錄: " + path)
