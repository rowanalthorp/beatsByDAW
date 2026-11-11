class_name EffectData
extends Resource
## one effect in a track's chain. just its settings for now, the actual sound processing
## comes from rowan's engine later. setters call emit_changed() like the other data

## which settings each effect type gets. placeholders until the engine says what it needs
const PARAM_NAMES := {
	"EQ": ["Low", "High"],
	"Delay": ["Time", "Feedback", "Mix"],
	"Reverb": ["Size", "Mix"],
	"Noise Reduction": ["Amount"],
}

@export var kind: String = "EQ"
@export var enabled: bool = true:
	set(value):
		enabled = value
		emit_changed()
## setting name -> slider value from 0 to 1
@export var params: Dictionary = {}


## a new effect of this type with every setting in the middle
static func create(effect_kind: String) -> EffectData:
	var effect := EffectData.new()
	effect.kind = effect_kind
	for param_name: String in PARAM_NAMES[effect_kind]:
		effect.params[param_name] = 0.5
	return effect
