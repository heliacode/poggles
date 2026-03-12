extends Node

# Viewport
const VIEWPORT_WIDTH := 1280
const VIEWPORT_HEIGHT := 720
const VIEWPORT_SIZE := Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)

# Ball
const BALL_RADIUS := 7.0
const BALL_MAX_SPEED := 1500.0
const BALL_CLEANUP_Y := 850.0
const BALL_TRAIL_LENGTH := 20
const BALL_BOUNCE := 0.5
const BALL_FRICTION := 0.1
const BALL_COLOR := Color(0.6, 0.9, 1.0)

# Cannon
const CANNON_LAUNCH_POWER := 800.0
const CANNON_BARREL_LENGTH := 45.0
const CANNON_BARREL_WIDTH := 8.0
const CANNON_BASE_RADIUS := 18.0
const CANNON_COLOR := Color(0.5, 0.7, 1.0)
const CANNON_POSITION := Vector2(640, 30)

# Pegs
const PEG_RADIUS := 14.0
const STARTING_BALLS := 10

const PEG_NEON_COLORS := {
	"blue": Color(0.2, 0.6, 1.0),
	"orange": Color(1.0, 0.4, 0.05),
	"green": Color(0.1, 1.0, 0.3),
	"purple": Color(0.8, 0.2, 1.0),
}

const PEG_HIT_COLORS := {
	"blue": Color(0.5, 0.85, 1.0),
	"orange": Color(1.0, 0.75, 0.2),
	"green": Color(0.4, 1.0, 0.6),
	"purple": Color(1.0, 0.5, 1.0),
}

const PEG_SCORES := {
	"orange": 100,
	"blue": 10,
	"green": 50,
	"purple": 500,
}

const SCORE_POPUP_COLORS := {
	"orange": Color(1.0, 0.85, 0.3),
	"blue": Color(0.6, 0.8, 1.0),
	"green": Color(0.4, 1.0, 0.6),
	"purple": Color(0.9, 0.5, 1.0),
}

# Bucket
const BUCKET_SPEED := 120.0
const BUCKET_LEFT_BOUND := 200.0
const BUCKET_RIGHT_BOUND := 1080.0
const BUCKET_WIDTH := 120.0
const BUCKET_HEIGHT := 14.0
const BUCKET_WALL_HEIGHT := 22.0
const BUCKET_COLOR := Color(0.2, 1.0, 0.4)
const BUCKET_POSITION := Vector2(640, 700)

# Background
const BG_GRID_SPACING := 60.0
const BG_COLOR := Color(0.01, 0.01, 0.03)

# Scene paths
const BALL_SCENE_PATH := "res://scenes/ball.tscn"
const SCORE_POPUP_PATH := "res://scripts/score_popup.gd"
const GAMEPLAY_SCENE_PATH := "res://scenes/gameplay.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const LEVEL_SELECT_SCENE_PATH := "res://scenes/level_select.tscn"
const RESULTS_SCENE_PATH := "res://scenes/results.tscn"
const SETTINGS_SCENE_PATH := "res://scenes/settings.tscn"
const ROUTE_MAP_SCENE_PATH := "res://scenes/route_map.tscn"
const RUN_RESULTS_SCENE_PATH := "res://scenes/run_results.tscn"
const ACT_INTRO_SCENE_PATH := "res://scenes/act_intro.tscn"
const EVENT_SCENE_PATH := "res://scenes/event_screen.tscn"
const RELIC_REWARD_SCENE_PATH := "res://scenes/relic_reward.tscn"
const SHOP_SCENE_PATH := "res://scenes/shop.tscn"
const UNLOCK_SCENE_PATH := "res://scenes/unlock_screen.tscn"
const CHARACTER_SELECT_SCENE_PATH := "res://scenes/character_select.tscn"

# Star thresholds (percentage of max possible score)
const STAR_THRESHOLDS := [0.25, 0.50, 0.80]

# Transitions
const FADE_DURATION := 0.3

# Total levels (practice mode)
const TOTAL_LEVELS := 5

# Special peg types
const SPECIAL_PEG_COLORS := {
	"bomb": Color(1.0, 0.15, 0.05),
	"armored": Color(0.7, 0.75, 0.8),
	"multiplier": Color(1.0, 0.85, 0.0),
	"chain": Color(0.0, 1.0, 1.0),
	"gravity": Color(0.6, 0.2, 0.9),
	"moving": Color(0.0, 0.9, 0.7),
}

const BOMB_RADIUS := 120.0
const CHAIN_RADIUS := 200.0
const CHAIN_MAX_TARGETS := 2
const GRAVITY_WELL_DURATION := 4.0
const GRAVITY_WELL_RADIUS := 180.0
const GRAVITY_WELL_FORCE := 8000.0
const GRAVITY_WELL_MAX_ACCEL := 200.0
const MOVING_PEG_SPEED := 70.0
const MOVING_PEG_RANGE := 60.0  # ±60px patrol from start position
