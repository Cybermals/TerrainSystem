# TerrainSystem
A terrain system for Godot.


## Instructions
1. clone this repo
2. copy the "addons" folder into your project (Note: It also includes the FlyCam plugin)
3. in your project settings, enable the "TerrainSystem" plugin
4. whenever you create a new node, there will be new terrain nodes that are based on the spatial node


## Optimization via a Thread Pool
1. enable the included "ThreadPool" plugin
2. create a new "ThreadPool" node parented to the "TerrainSystem" node
3. (optional) adjust the maximum number of worker threads for the thread pool
(the default is 2; for best results, use one thread per CPU core)
