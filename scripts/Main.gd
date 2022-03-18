extends Node

export (ShaderMaterial) var material


func _ready():
	#Load the terrain
	get_node("TerrainSystem").load_terrain("res://images/heightmap.png")
	get_node("TerrainSystem").set_material(material)
	
	#Unload terrain
	#get_node("TerrainSystem").unload_terrain()


func _on_TerrainSystem_progress(chunks_loaded, total_chunks):
	print(str(chunks_loaded) + " of " + str(total_chunks) + 
	    " loaded.")


func _on_TerrainSystem_terrain_loaded():
	print("Terrain loaded.")
