extends Node

export (ShaderMaterial) var material


func _ready():
	#Load the terrain
	get_node("TerrainSystem").load_terrain("res://images/heightmap.png")
	get_node("TerrainSystem").set_material(material)
	
	#Unload terrain
	#get_node("TerrainSystem").unload_terrain()
