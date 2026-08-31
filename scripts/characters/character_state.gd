## 角色状态基类 - 所有具体状态继承此类
class_name CharacterState
extends Node

var state_machine: StateMachine
var character: CharacterBody2D


func _ready() -> void:
	# 沿着节点树向上找到角色节点
	var node = owner
	if node is CharacterBody2D:
		character = node


## 进入此状态时调用
func enter(_params: Dictionary) -> void:
	pass


## 退出此状态时调用
func exit() -> void:
	pass


## 每帧逻辑更新
func update(_delta: float) -> void:
	pass


## 每帧物理更新
func physics_update(_delta: float) -> void:
	pass


## 输入处理
func handle_input(_event: InputEvent) -> void:
	pass
