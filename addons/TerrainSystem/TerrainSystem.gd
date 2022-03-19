extends Spatial

signal progress(chunks_loaded, total_chunks)
signal terrain_loaded

export var chunk_size = 64
var uv_inc
var texture
var _material = null
var chunks_loaded
var total_chunks
var progress_mutex = Mutex.new()


func _ready():
	pass
	
	
func load_terrain(path):
	#Unload previous terrain
	unload_terrain()
	
	#Load heightmap
	texture = load(path)
	
	if not texture:
		return false
	
	var heightmap = texture.get_data()
	var size = Vector2(
	    heightmap.get_width(),
	    heightmap.get_height()
	)
	uv_inc = Vector2(
	    1.0 / size.x,
	    1.0 / size.y
	)
	chunks_loaded = 0
	total_chunks = (((size.x - 1) / chunk_size) * 
	    ((size.y - 1) / chunk_size))
	
	#Get thread pool
	var pool = get_node("ThreadPool")
	
	#Create chunks
	#Note: Heightmaps should always have a width and height
	#that are powers of 2 plus one. The extra row and column
	#enable this terrain system to be more highly optimized
	#by making it easy to divide the heightmap into equal
	#chunks that have exactly one row and one column of
	#overlap. The overlap prevents ugly gaps in the terrain
	#that would appear at the seams where chunks meet.
	if pool:
		for z in range(0, size.y - 1, chunk_size):
			for x in range(0, size.x - 1, chunk_size):
				pool.queue_job(
				    funcref(self, "load_chunk"),
				    [
				        heightmap.get_rect(Rect2(
				            x, z, 
				            chunk_size + 1, chunk_size + 1)), 
				        Vector2(x, z), 
				        uv_inc
					]
				)
				
	else:
		for z in range(0, size.y - 1, chunk_size):
			for x in range(0, size.x - 1, chunk_size):
				load_chunk([
				    heightmap.get_rect(Rect2(
				        x, z, 
				        chunk_size + 1, chunk_size + 1)), 
				    Vector2(x, z), 
				    uv_inc
				])
			
	return true
	
	
func load_chunk(data):
	#Create new mesh instance
	var heightmap = data[0]
	var pos = data[1]
	var uv_inc = data[2]
	#print("Loading chunk at " + str(pos))
	var chunk = MeshInstance.new()
	chunk.set_name("TerrainChunk")
	chunk.add_to_group("TerrainChunks")
	chunk.set_translation(Vector3(pos.x, 0.0, pos.y))
	call_deferred("add_child", chunk)
	
	#Generate geometry data
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_smooth_group(true)
	
	for z in range(chunk_size + 1):
		for x in range(chunk_size + 1):
			#Generate next vertex
			st.add_uv((pos + Vector2(x, z)) * uv_inc)
			st.add_vertex(Vector3(x, 
			    heightmap.get_pixel(x, z).r, z))
			
	for z in range(chunk_size):
		for x in range(chunk_size):
			#Generate next tile
			st.add_index(z * (chunk_size + 1) + x)
			st.add_index(z * (chunk_size + 1) + x + 1)
			st.add_index((z + 1) * (chunk_size + 1) + x + 1)
			
			st.add_index((z + 1) * (chunk_size + 1) + x + 1)
			st.add_index((z + 1) * (chunk_size + 1) + x)
			st.add_index(z * (chunk_size + 1) + x)
	
	st.generate_normals()
	var mesh = st.commit()
	
	#Assign mesh to chunk, set its material, and generate 
	#collision shape
	chunk.set_mesh(mesh)
	chunk.set_material_override(_material)
	chunk.create_trimesh_collision()
	
	#Update chunk load progress
	progress_mutex.lock()
	chunks_loaded += 1
	emit_signal("progress", chunks_loaded, total_chunks)
	
	if chunks_loaded == total_chunks:
		emit_signal("terrain_loaded")
		
	progress_mutex.unlock()
	
	
func set_material(material):
	#Set the material for all of the chunks and set the
	#UV increment for the shader
	_material = material
	get_tree().call_group(get_tree().GROUP_CALL_DEFAULT, 
	    "TerrainChunks", "set_material_override", material)
	material.set_shader_param("uv_inc", uv_inc)
	
	
func get_height(x, z):
	#Calculate sub-pixel coordinates
	var scale = get_scale()
	var u = x / scale.x
	var v = z / scale.z
	
	#Get nearest pixels
	var heightmap = texture.get_data()
	var h1 = heightmap.get_pixel(floor(u), floor(v)).r
	var h2 = heightmap.get_pixel(ceil(u), floor(v)).r
	var h3 = heightmap.get_pixel(floor(u), ceil(v)).r
	var h4 = heightmap.get_pixel(ceil(u), ceil(v)).r
	
	#Calculate interpolated height
	var u_factor = u - floor(u)
	var v_factor = v - floor(v)
	var uh1 = h1 + abs(h2 - h1) * u_factor
	var uh2 = h3 + abs(h4 - h3) * u_factor
	var uh3 = uh1 + abs(uh2 - uh1) * v_factor
	return uh3 * scale.y
	
	
func unload_terrain():
	#Mark all terrain chunks to be freed
	get_tree().call_group(get_tree().GROUP_CALL_DEFAULT,
	    "TerrainChunks", "queue_free")
