## 通用状态机 - 管理角色在各动作状态间的切换
class_name StateMachine
extends Node

@export var initial_state: NodePath

var current_state: CharacterState
var states: Dictionary = {}


func _ready() -> void:
	# 收集所有子状态节点
	for child in get_children():
		if child is CharacterState:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.process_mode = Node.PROCESS_MODE_DISABLED

	# 进入初始状态
	if initial_state:
		current_state = get_node(initial_state)
	elif states.size() > 0:
		current_state = states.values()[0]

	if current_state:
		current_state.process_mode = Node.PROCESS_MODE_INHERIT
		current_state.enter({})


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func transition_to(target_state_name: String, params: Dictionary = {}) -> void:
	var target_key = target_state_name.to_lower()
	if not states.has(target_key):
		push_error("StateMachine: 状态 '%s' 不存在" % target_state_name)
		return

	var target_state = states[target_key]
	if target_state == current_state:
		return

	current_state.process_mode = Node.PROCESS_MODE_DISABLED
	current_state.exit()

	current_state = target_state
	current_state.process_mode = Node.PROCESS_MODE_INHERIT
	current_state.enter(params)
