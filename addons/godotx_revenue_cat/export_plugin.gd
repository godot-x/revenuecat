@tool
extends EditorPlugin

const PLUGIN_NAME = "Godotx RevenueCat"

var android_export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	android_export_plugin = AndroidExportPlugin.new()
	
	add_export_plugin(android_export_plugin)


func _exit_tree() -> void:
	if android_export_plugin:
		remove_export_plugin(android_export_plugin)
		android_export_plugin = null


# ============================================================================
# Android Export Plugin
# ============================================================================
class AndroidExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return PLUGIN_NAME
	
	
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid
	
	
	func _get_export_options(platform: EditorExportPlatform) -> Array[Dictionary]:
		var options: Array[Dictionary] = []
		
		if platform.get_os_name() != "Android":
			return options
		
		# Enable RevenueCat
		options.append({
			"option": {
				"name": "revenuecat/enable_revenuecat",
				"type": TYPE_BOOL
			},
			"default_value": true
		})
		
		# RevenueCat version
		options.append({
			"option": {
				"name": "revenuecat/revenuecat_version",
				"type": TYPE_STRING
			},
			"default_value": "9.13.0"
		})
		
		# RevenueCat UI version
		options.append({
			"option": {
				"name": "revenuecat/revenuecat_ui_version",
				"type": TYPE_STRING
			},
			"default_value": "9.13.0"
		})
		
		return options
	
	
	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var dependencies: PackedStringArray = []
		
		# RevenueCat
		if get_option("revenuecat/enable_revenuecat"):
			var version = get_option("revenuecat/revenuecat_version")
			dependencies.append("com.revenuecat.purchases:purchases:" + version)
			print("[RevenueCat] Adding RevenueCat dependency (v%s)" % version)
		
		# RevenueCat UI
		if get_option("revenuecat/enable_revenuecat_ui"):
			var version = get_option("revenuecat/revenuecat_ui_version")
			dependencies.append("com.revenuecat.purchases:purchases-ui:" + version)
			print("[RevenueCat] Adding RevenueCat UI dependency (v%s)" % version)
		
		return dependencies


	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var libraries: PackedStringArray = []
		var build_type: String = "debug" if debug else "release"
		
		# List of modules to check (in order)
		var modules: Array[String] = []
		
		if get_option("revenuecat/enable_revenuecat"):
			modules.append("revenue_cat")
		
		# Search for AARs in each module's directory
		for module in modules:
			var module_path: String = "res://android/" + module + "/"
			var aar_file_name: String = module + "." + build_type + ".aar"
			var aar_full_path: String = module_path + aar_file_name
			
			if FileAccess.file_exists(aar_full_path):
				# Add relative path from android/ directory
				var rel_path: String = "../android/" + module + "/" + aar_file_name
				libraries.append(rel_path)
				print("[RevenueCat] Adding Android library (%s): %s" % [build_type, aar_file_name])
			else:
				push_warning("[RevenueCat] AAR not found: " + aar_full_path)
		
		if libraries.is_empty():
			push_warning("[RevenueCat] No Android libraries found")
		else:
			print("[RevenueCat] Total Android libraries found: " + str(libraries.size()))
		
		return libraries
