tool
extends EditorPlugin


func _enter_tree():
	#Add custom types here
	add_custom_type(
	    "ThreadPool", 
	    "Node", 
	    preload("ThreadPool.gd"), 
	    preload("icon.png")
	)
	
	
func _exit_tree():
	#Remove custom types here
	remove_custom_type("ThreadPool")
