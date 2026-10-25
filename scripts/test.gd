extends Node

func _ready() -> void:
	# This function is simply to test if the .gdextention for cpp is working
		if ClassDB.class_exists("TestCPP"):
	
			var test_instance = TestCPP.new()
			print("C++ is working")
			test_instance.queue_free()
		else:
			print("error, need the cpp to work")
		pass
