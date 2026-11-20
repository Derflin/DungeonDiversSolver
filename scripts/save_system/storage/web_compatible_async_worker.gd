extends "res://addons/easystore/subsystems/async_worker.gd"


var _web_queue: Array[Dictionary] = []


## Initializes worker processing according to available thread support.
func _ready() -> void:
	# Disable per-frame processing until operations are queued.
	set_process(false)
	
	# Process storage operations while the scene tree is paused.
	if OS.has_feature("nothreads"):
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	
	# Initialize the threaded worker.
	super._ready()


## Stops worker processing and clears pending operations.
func _exit_tree() -> void:
	# Clear operations on platforms without thread support.
	if OS.has_feature("nothreads"):
		set_process(false)
		_web_queue.clear()
		return
	
	# Shut down the threaded worker.
	super._exit_tree()


## Queues a storage operation and its completion callback.
## Uses provided [param work] callable as the operation that will be queued that returns a Variant result.
## Uses provided [param on_complete] callable as the callback that will receive the operation result.
func dispatch(work: Callable, on_complete: Callable = Callable()) -> void:
	# Dispatch operations to the threaded worker when supported.
	if not OS.has_feature("nothreads"):
		super.dispatch(work, on_complete)
		return
	
	# Add operation to the queue.
	_web_queue.append({
		"work": work,
		"on_complete": on_complete
	})
	
	# Enable processing of pending operations.
	set_process(true)


## Executes the next queued storage operation.
func _process(_delta: float) -> void:
	# Disable processing when no operations are available.
	if _web_queue.is_empty():
		set_process(false)
		return
	
	# Retrieve the next queued operation.
	var job: Dictionary = _web_queue.pop_front()
	var work: Callable = job["work"]
	var on_complete: Callable = job["on_complete"]
	
	# Execute the operation and schedule its completion callback.
	var result: Variant = work.call()
	if on_complete.is_valid():
		on_complete.call_deferred(result)
	
	# Disable processing after completing the final operation.
	if _web_queue.is_empty():
		set_process(false)
