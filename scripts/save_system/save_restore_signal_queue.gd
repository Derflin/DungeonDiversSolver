class_name SaveRestoreSignalQueue
extends RefCounted


var _is_deferring = false
var _queued_signals: Array[Dictionary] = []


## Marks the signal queue state as currently deferring the signals and clears the existing signal queue.
func begin() -> void:
	# Set the deferring flag.
	_is_deferring = true
	
	# Clear the queued signals for clean initial state.
	_queued_signals.clear()


## Emits signal immediately if the deferring flag inside the queue is set or otherwise deferrs signal emit by queuing it's name and arguments for later emit.
## Uses the provided [param source] as a base object from which the sginals will be emitted from if the signal would be emitted immediately.
## Provided [param signal_name] and [param arguments] will be used for when the signal would be emitted.
func emit_or_defer(source: Object, signal_name: StringName, arguments: Array = []) -> void:
	# Emit provided signal if the queue isn't set to deferring signals currently.
	if not _is_deferring:
		_emit_signal(source, signal_name, arguments)
		return
	
	# Otherwise save provided signal parameters inside queue in order to emit them later on after the queue would change it's deferring flag.
	_queued_signals.append({
		"signal_name": signal_name,
		"arguments": arguments.duplicate(),
	})


## Marks the signal queue as no longer deferring the signals and causes the queued signals to be emitted.
## Uses the provided [param source] as a base object from which the signals will be emitted from.
func finish(source: Object) -> void:
	# Unset the deferring flag.
	_is_deferring = false
	
	# Make copy of the currently queued signals.
	var queued_signals := _queued_signals.duplicate()
	
	# Clear the queued signals to left the queue in clean state.
	_queued_signals.clear()
	
	# Emit each signal that was queued based on the copied queued signals.
	for queued_signal: Dictionary in queued_signals:
		_emit_signal(source, queued_signal["signal_name"], queued_signal["arguments"])


## Immediately emits signal using the [param source] object as caller emitting the provided [param signal_name] along with it's [param arguments] assigned to it.
func _emit_signal(source: Object, signal_name: StringName, arguments: Array) -> void:
	# Prepare signal call arguments.
	var call_arguments: Array = [signal_name]
	call_arguments.append_array(arguments)
	
	# Call signal emit from the source object.
	source.callv(&"emit_signal", call_arguments)
