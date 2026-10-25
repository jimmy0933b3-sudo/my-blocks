@tool
extends SceneTree

func _initialize() -> void:
	var java_path = OS.get_environment("JAVA_HOME")
	var sdk_path = OS.get_environment("ANDROID_HOME")
	if sdk_path.is_empty():
		sdk_path = OS.get_environment("ANDROID_SDK_ROOT")
	if java_path.is_empty() or sdk_path.is_empty():
		push_error("JAVA_HOME and ANDROID_HOME must be set for Android export")
		quit(1)
		return
	EditorInterface.get_editor_settings().set_setting("export/android/java_sdk_path", java_path)
	EditorInterface.get_editor_settings().set_setting("export/android/android_sdk_path", sdk_path)
	quit(0)
