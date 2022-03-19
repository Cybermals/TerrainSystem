extends Camera

export var speed = 8
export var rot = Vector3()


func _ready():
	#Enable event processing
	set_process(true)
	
	
func _process(delta):
	#Handle camera movement
	var transform = get_transform()
	var inc = Vector3()
	
	if Input.is_action_pressed("move_forward"):
		inc.z = -speed * delta
		
	elif Input.is_action_pressed("move_backward"):
		inc.z = speed * delta
		
	if Input.is_action_pressed("move_left"):
		inc.x = -speed * delta
		
	elif Input.is_action_pressed("move_right"):
		inc.x = speed * delta
		
	if Input.is_action_pressed("move_up"):
		inc.y = speed * delta
		
	elif Input.is_action_pressed("move_down"):
		inc.y = -speed * delta
		
	if Input.is_action_pressed("turn_left"):
		rot.y += speed * 16 * delta
		
	elif Input.is_action_pressed("turn_right"):
		rot.y += -speed * 16 * delta
		
	if Input.is_action_pressed("look_up"):
		rot.x += speed * 16 * delta
		
	elif Input.is_action_pressed("look_down"):
		rot.x += -speed * 16 * delta
		
	transform.origin += inc.rotated(Vector3(0.0, -1.0, 0.0), deg2rad(rot.y))
	transform.basis = Matrix3()
	set_transform(transform)
	rotate(Vector3(0.0, -1.0, 0.0), deg2rad(rot.y))
	rotate(Vector3(-1.0, 0.0, 0.0), deg2rad(rot.x))
