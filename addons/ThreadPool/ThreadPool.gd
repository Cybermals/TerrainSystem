extends Node

export (int) var max_threads = 2

var threads = []
var queue = []
var job_mutex = Mutex.new()


func _ready():
	#Start worker threads
	for i in range(max_threads):
		var thread = Thread.new()
		thread.start(self, "worker_thread")
		threads.append(thread)
		
		
func queue_job(func_ref, data):
	#Lock job mutex
	job_mutex.lock()
	
	#Queue new job
	queue.push_back([func_ref, data])
	
	#Unlock job mutex
	job_mutex.unlock()
		
		
func worker_thread(data):
	#Main loop
	while true:
		#Lock job mutex
		job_mutex.lock()
		
		#Fetch next job
		var job = null
		
		if queue.empty():
			job_mutex.unlock()
			OS.delay_msec(1000)
			continue
			
		job = queue.front()
		queue.pop_front()
		
		#Unlock job mutex
		job_mutex.unlock()
		
		#Execute job
		job[0].call_func(job[1])
