extends Node

## Root node doubles as the "monitor" with a real `is_viewing` property.
var is_viewing: bool = false

var _file := "/tmp/test_aware_result.txt"
var _frame := 0
var _viewed_ok := 0
var _hidden_ok := 0
var _view_signal := 0
var _avert_signal := 0
var _aware: AnomalyBase
var _final_visible := "n/a"
var _out := ""


func _append(s: String) -> void:
	_out += s + "\n"


func _write() -> void:
	var f := FileAccess.open(_file, FileAccess.WRITE)
	if f:
		f.store_string(_out)
		f.close()


func _ready() -> void:
	var scn := load("res://scenes/anomalies/Aware.tscn") as PackedScene
	var ok_load = (scn != null)
	_append("load_ok = " + str(ok_load))
	if not ok_load:
		_finish("FAIL")
		return

	_aware = scn.instantiate() as AnomalyBase
	var ok_inst = (_aware != null and _aware.is_class("Node3D"))
	_append("inst_ok = " + str(ok_inst))
	if not ok_inst:
		_finish("FAIL")
		return

	add_child(_aware)
	add_to_group("security_monitors")

	_aware._init_anomaly({})
	_aware.execute_behavior()
	_aware.monitor_viewed.connect(func(): _view_signal += 1)
	_aware.monitor_averted.connect(func(): _avert_signal += 1)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame <= 5:
		return  # warmup, not viewing
	elif _frame <= 6:
		is_viewing = true  # Aware shows the eye this frame
	elif _frame <= 8:
		if _aware.eye_root.visible:
			_viewed_ok = 1
	elif _frame == 9:
		is_viewing = false  # Aware hides the eye this frame
	else:  # _frame >= 10
		if not _aware.eye_root.visible:
			_hidden_ok = 1
		if _frame >= 11:
			_final_visible = str(_aware.eye_root.visible)
			_finish_report()


func _finish_report() -> void:
	_append("eye_visible_while_viewed = " + str(_viewed_ok))
	_append("eye_hidden_after_averted = " + str(_hidden_ok))
	_append("view_signals = " + str(_view_signal))
	_append("avert_signals = " + str(_avert_signal))
	_append("final_visible = " + _final_visible)
	var result_pass := (_viewed_ok == 1 and _hidden_ok == 1 and _view_signal == 1 and _avert_signal == 1 and _final_visible == "false")
	_append("TEST_RESULT = " + ("PASS" if result_pass else "FAIL"))
	_write()
	_finish("PASS" if result_pass else "FAIL")


func _finish(result: String) -> void:
	_write()
	if is_instance_valid(_aware):
		_aware.queue_free()
	get_tree().quit(0 if result == "PASS" else 1)
