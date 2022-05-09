extends Spatial

signal progress(chunks_loaded, total_chunks)
signal terrain_loaded

export var chunk_size = 64

onready var thread_pool = get_node("ThreadPool")

var uv_inc
var texture
var _material = null
var chunks_loaded
var total_chunks


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
	
	#Create chunks
	#Note: Heightmaps should always have a width and height
	#that are powers of 2 plus one. The extra row and column
	#enable this terrain system to be more highly optimized
	#by making it easy to divide the heightmap into equal
	#chunks that have exactly one row and one column of
	#overlap. The overlap prevents ugly gaps in the terrain
	#that would appear at the seams where chunks meet.
	if thread_pool:
		for z in range(0, size.y - 1, chunk_size):
			for x in range(0, size.x - 1, chunk_size):
				#Queue chunk load job
				thread_pool.queue_job(
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
				#Load the chunk
				load_chunk([
				    heightmap.get_rect(Rect2(
				        x, z, 
				        chunk_size + 1, chunk_size + 1)), 
				    Vector2(x, z),
				    uv_inc
				])
			
	return true
	
	
func load_chunk(data):
	#Fetch params
	var heightmap = data[0]
	var pos = data[1]
	var uv_inc = data[2]
	#print("Loading chunk at " + str(pos))
	
	#Create chunk
	var chunk = MeshInstance.new()
	chunk.set_name("TerrainChunk")
	chunk.add_to_group("TerrainChunks")
	chunk.set_translation(Vector3(pos.x, 0, pos.y))
	
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
	
	#Finish the terrain mesh
	#Note: We cannot do this in a background thread because
	#SurfaceTool.commit is not thread-safe.
	call_deferred("finish_mesh", chunk, st)
	
	
func finish_mesh(chunk, st):
	#Assign mesh and material to chunk
	var mesh = st.commit()
	chunk.set_mesh(mesh)
	chunk.set_material_override(_material)
	
	#Create collider
	#Note: Generating collision shapes is resource intensive.
	#Therefore we will let the thread pool handle this part.
	if thread_pool:
		#Queue collider generation job
		thread_pool.queue_job(
		    funcref(self, "generate_collider"),
		    [
		        chunk,
		        mesh.get_faces()
		    ]
		)
		
	else:
		#Generate collider
		generate_collider(chunk, mesh.get_faces())
		

func generate_collider(data):
	#Fetch params
	var chunk = data[0]
	var faces = data[1]
	
	#Generate collider
	var shape = ConcavePolygonShape.new()
	shape.set_faces(faces)
	var collider = StaticBody.new()
	collider.add_shape(shape)
	chunk.add_child(collider)
	
	#Finish the chunk
	#Note: Yet again, we cannot do this in a background
	#thread. This time because adding a node to the scene
	#tree isn't thread-safe.
	call_deferred("finish_chunk", chunk)
	
	
func finish_chunk(chunk):
	#Add the chunk to the scene
	add_child(chunk)
	
	#Update chunk load progress
	chunks_loaded += 1
	emit_signal("progress", chunks_loaded, total_chunks)
	
	if chunks_loaded == total_chunks:
		emit_signal("terrain_loaded")

	
func set_material(material):
	#Set the material for all of the chunks and set the
	#UV increment for the shader
	_material = material
	get_tree().call_deferred("call_group", 
	    get_tree().GROUP_CALL_DEFAULT, "TerrainChunks",
	    "set_material_override", material)
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
