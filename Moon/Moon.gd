extends KinematicBody2D

const DEFAULT_SPEED = 500.0
#const DEFAULT_DASH_SPEED = 1.0
const Y_AXIS_SPEED = 0.75
const RUN_SPEED = 1.5

const ATTACK_WIDTH = 100

# TODO: Should move this in the project settings
const DASH_INPUT = "ui_right_click"
const ATTACK_INPUT = "ui_left_click"

# TODO: This seems ugly, should research if there's a cleaner way to do this
export (NodePath) var camera

enum {
	IDLE,
	MOVING,
	CHARGING,
	DASHING,
	ATTACKING
}
var state = MOVING

var input_vector = Vector2.ZERO
var movement_vector = Vector2.ZERO
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
	
	animation_tree.active = true;
	
	

func _physics_process(delta):
	# Calculating the input vector
	input_vector.x = Input.get_action_strength("ui_right")-Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down")-Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	
	if input_vector != Vector2.ZERO:
		last_input_vector = input_vector
	
	
	# Finite state machine
	match state:
		MOVING:
			move()
			
			if input_vector != Vector2.ZERO:
				animation_state.travel("Run")
				animation_tree.set("parameters/Run/blend_position", last_input_vector)
			else:
				animation_state.travel("Idle")
				animation_tree.set("parameters/Idle/blend_position", last_input_vector)
			
			# Charging for dash while moving
			if Input.is_action_just_pressed(DASH_INPUT):
				state = CHARGING
				
				# Defines the center of the screen depending on the camera
				# position in the world
				# TODO: maybe change the name of the variable
				# TODO: Poses issue when we use the drag margins with the camera
				screen_center = get_node(camera).global_position
				
				print(screen_center)
				# We recenter the mouse cursor at the center of the screen
				# so we have as much range as possible for dashing
				get_viewport().warp_mouse(get_viewport_rect().size/2)
				
			
			if Input.is_action_just_pressed(ATTACK_INPUT):
				line2d.visible = false
				state = ATTACKING
			
		CHARGING:
			move() # Ability to move while charging
			charge()
			# Release dash
			if Input.is_action_just_released(DASH_INPUT):
				line2d.visible = false
				state = DASHING
			
			# Cancel charging with attack
			if Input.is_action_just_pressed(ATTACK_INPUT):
				line2d.visible = false
				state = ATTACKING
			
		DASHING:
			dash()
			# Cancel dash with attack
			if Input.is_action_just_pressed(ATTACK_INPUT):
				state = ATTACKING
			
			state = MOVING
		
		ATTACKING:
			attack()
			state = MOVING

func charge():
	# Defining the vector of the dash
	# TODO: Study if the "slingshot" mechanic is better than the "point" mechanic
	dash_vector = screen_center - get_global_mouse_position()
	#line2d.points[0] = screen_center
	line2d.points[1] = dash_vector
	line2d.visible = true


func dash():
	# Moves the player the the new position
	global_position += dash_vector
	
	
	# Sets the hurtbox shape and position
	hurtbox_dash_collision.polygon[0].x = -dash_vector.length()
	hurtbox_dash_collision.polygon[1].x = -dash_vector.length()
	
	# Rotate the collision shape so it matches the player's trajectory
	hurtbox_dash_collision.rotation = dash_vector.angle()
	
	hurtbox_dash_collision.disabled = false
	hurtbox_dash_collision.visible = true
	
	hurtbox_attack_collision.disabled = false
	hurtbox_attack_collision.visible = true
	
	dash_timer.start()
	

# TODO: Adding a cooldown !
func attack():
	# TODO: Maybe change the hurtbox shape. It doesn't really make sense for it
	# to be a circle
	hurtbox_attack_collision.disabled = false
	hurtbox_attack_collision.visible = true
	attack_timer.start()
	

# Allows the player to move around
func move():
	movement_vector = DEFAULT_SPEED * input_vector
	
	# Is running really necessary ?
	if Input.is_action_pressed("ui_shift"):
		movement_vector *= RUN_SPEED
	
	movement_vector.y *= Y_AXIS_SPEED
	
	move_and_slide(movement_vector, Vector2.ZERO)


# When the dash_timer is done hurtbox should be disabled
func _on_DashTimer_timeout():
	hurtbox_dash_collision.disabled = true
	hurtbox_dash_collision.visible = false
	
	if attack_timer.is_stopped():
		hurtbox_attack_collision.disabled = true
		hurtbox_attack_collision.visible = false


func _on_AttackTimer_timeout():
	hurtbox_attack_collision.disabled = true
	hurtbox_attack_collision.visible = false
