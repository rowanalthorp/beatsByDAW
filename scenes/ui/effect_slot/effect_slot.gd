class_name EffectSlot
extends PanelContainer
## one effect in the sidebar: its name, an on/off switch, a remove button and a slider per setting

signal remove_requested(effect: EffectData)

var effect: EffectData


func setup(new_effect: EffectData) -> void:
	effect = new_effect
	%EffectName.text = effect.kind
	# no_signal so showing the saved value doesnt write it straight back
	%BypassButton.set_pressed_no_signal(effect.enabled)
	%BypassButton.toggled.connect(_on_enabled_toggled)
	%RemoveButton.pressed.connect(_on_remove_pressed)
	# every effect type has different settings, so the rows get made here instead of in the scene
	for param_name: String in effect.params:
		_add_param_row(param_name)


func _add_param_row(param_name: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = param_name
	label.custom_minimum_size.x = 70 # same width on every label so the sliders line up
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01 # sliders default to steps of 1, which would only allow 0 or 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.set_value_no_signal(effect.params[param_name])
	# every row sets a different setting, so a little inline function remembers which one this is
	slider.value_changed.connect(func(value: float) -> void: effect.params[param_name] = value)
	row.add_child(label)
	row.add_child(slider)
	%VBox.add_child(row)


func _on_enabled_toggled(on: bool) -> void:
	effect.enabled = on


func _on_remove_pressed() -> void:
	remove_requested.emit(effect)
