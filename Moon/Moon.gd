extends KinematicBody2D

const DEFAULT_SPEED = 200.0
#const DEFAULT_DASH_SPEED = 1.0
const Y_AXIS_SPEED = 0.75
const RUN_SPEED = 1.5

const ATTACK_WIDTH = 50

# TODO: Should move this in the project settings
const DASH_INPUT = "ui_right_click"
const ATTACK_INPUT = "ui_left_click"

# TODO: This seems ugly, should research if there's a cleaner way to do this
export (NodePath) var camera

enum {
	MOVING,
	CHARGING,
	DASHING,
	ATTACKING
}
var state = MOVING

var input_vector = Vector2.ZERO
var movement_vector = Vector2.ZERO
# The input_vector of the previous cycle
var last_input_vector = Vector2.DOWN


var dash_vector = Vector2.ZERO

var screen_center = Vector2.ZERO


onready var line2d = $Line2D

onready var hurtbox = $Hurtbox
onready var hurtbox_dash_collision = $Hurtbox/DashCollision
onready var hurtbox_attack_collision = $Hurtbox/AttackCollision
onready var dash_timer = $DashTimer
onready var attack_timer = $AttackTimer

onready var animation_tree = $AnimationTree
onready var animation_state = animation_tree.get("parameters/playback")


# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Initialize the hurtbox shape
	# TODO: Would be better if we skewed the hurtbox_dash depending on the angle
	# of the dash
	hurtbox_dash_collision.polygon[0] = Vector2(0, -ATTACK_WIDTH)
	hurtbox_dash_collision.polygon[1] = Vector2(0, ATTACK_WIDTH)
	hurtbox_dash_collision.polygon[2] = Vector2(0, ATTACK_WIDTH)
	hurtbox_dash_collision.polygon[3] = Vector2(0, -ATTACK_WIDTH)
	
	# Sets the radius of the attack collision shape to the attack width
	# TODO: Like with the hurtbox, skew the shape depending on the attack angle
	hurtbox_attack_collision.shape.radius = ATTACK_WIDTH
	
	animation_tree.active = true;
	
	

func _physics_process(delta):
	# Calculating the input vector
	input_vector.x = Input.get_action_strength("ui_right")-Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down")-Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	
	# Sets the last_input_vector only if the input_vector is not (0, 0)
	if input_vector != Vector2.ZERO:
		last_input_vector = input_vector
	
	
	# Finite state machine
	match state:
		MOVING:
			move()
			
			# Sets the sprite orientation depending on the previous input_vector
			if input_vector != Vector2.ZERO:
				animation_state.travel("Run")
				animation_tree.set("parameters/Run/blend_position", input_vector)
			else:
				animation_state.travel("Idle")
				animation_tree.set("parameters/Idle/blend_position", last_input_vector)
			
			# Charging for dash while moving
			if Input.is_action_just_pressed(DASH_INPUT):
				state = CHARGING
				
				# Defines the center of the screen depending on the camera
				# position in the world
				# TODO: maybe change the name of the variable
				screen_center = get_node(camera).global_position
				
				print(screen_center)
				# We recenter the mouse cursor at the center of the screen
				# so we have as much range as possible for dashing
				get_viewport().warp_mouse(get_viewport_rect().size/2)
				
			
			if Input.is_action_just_pressed(ATTACK_INPUT):
				line2d.visible = false
				state = ATTACKING
			
		CHARGING:
			# Ability to move while charging
			move()
			charge()
				
			# Allows animations either if moving or idle while charging
			if input_vector != Vector2.ZERO:
				animation_state.travel("Run")
				animation_tree.set("parameters/Run/blend_position", last_input_vector)
			else:
				animation_state.travel("Idle")
				animation_tree.set("parameters/Idle/blend_position", dash_vector)

			# Release dash
			if Input.is_action_just_released(DASH_INPUT):
				line2d.visible = false
				
				# Makes sure the player faces the direction of the dash vector
				last_input_vector = dash_vector
				dash_timer.start()
				state = DASHING
			
			# Cancel charging with attack
			if Input.is_action_just_pressed(ATTACK_INPUT):
				line2d.visible = false
				state = ATTACKING
			
		DASHING:
			# Cancel dash with attack
			if Input.is_action_just_pressed(ATTACK_INPUT):
				state = ATTACKING
			
			if dash_timer.is_stopped():
				if dash_timer.is_stopped():
					state = MOVING
			else:
				dash()
			
		
		ATTACKING:
			attack()
			state = MOVING


func charge():
	# Defining the vector of the dash
	# TODO: Check why the dash vector changes when the player moves within
	#		the camera's drag margin
	# TODO: Study if the "slingshot" mechanic is better than the "point" mechanic
	dash_vector = get_node(camera).global_position - get_global_mouse_position()
	#line2d.points[0] = screen_center
	line2d.points[1] = dash_vector
	line2d.visible = true


func dash():
	
	# Moves the player to the the new position
	# TODO: Move that magic number somewhere
	# TODO: Is there a cleaner way to do this ????
	global_position += dash_vector/10
	
	
	# Sets the hurtbox shape and position
	hurtbox_dash_collision.polygon[0].x = -dash_vector.length()
	hurtbox_dash_collision.polygon[1].x = -dash_vector.length()
	
	# Rotate the collision shape so it matches the player's trajectory
	hurtbox_dash_collision.rotation = dash_vector.angle()
	
	set_hurtbox_dash_collision(true)
	set_hurtbox_attack_collision(true)
	

# TODO: Adding a cooldown !
func attack():
	# TODO: Maybe change the hurtbox shape. It doesn't really make sense for it
	# to be a circle
	set_hurtbox_attack_collision(true)
	attack_timer.start()
	

# Allows the player to move around
func move():
	movement_vector = DEFAULT_SPEED * input_vector
	
	# Is running really necessary ?
	#if Input.is_action_pressed("ui_shift"):
	#	movement_vector *= RUN_SPEED
	
	movement_vector.y *= Y_AXIS_SPEED
	
	move_and_slide(movement_vector, Vector2.ZERO)

# Sets the attack hurtbox collision
func set_hurtbox_attack_collision(is_enabled:bool):
	hurtbox_attack_collision.disabled = !is_enabled
	hurtbox_attack_collision.visible = is_enabled # Debug

# Sets the dash hurtbox collision
func set_hurtbox_dash_collision(is_enabled:bool):
	hurtbox_dash_collision.disabled = !is_enabled
	hurtbox_dash_collision.visible = is_enabled # Debug


# When the dash_timer is done, hurtbox_dash and hurtbox_attack are disabled
func _on_DashTimer_timeout():
	set_hurtbox_dash_collision(false)
	
	if attack_timer.is_stopped():
		set_hurtbox_attack_collision(false)


# When the attack_timer is done, hurtbox is disabled
func _on_AttackTimer_timeout():
	set_hurtbox_attack_collision(false)
