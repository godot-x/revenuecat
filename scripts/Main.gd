extends Control

const REVENUECAT_PLUGIN_NAME = "GodotxRevenueCat"
var revenuecat = null

@onready var api_key_edit = $VBoxContainer/ScrollContainer/Content/SectionInitialize/SectionInitializeVBox/ApiKeyEdit
@onready var user_id_edit = $VBoxContainer/ScrollContainer/Content/SectionInitialize/SectionInitializeVBox/UserIdEdit
@onready var debug_check = $VBoxContainer/ScrollContainer/Content/SectionInitialize/SectionInitializeVBox/DebugCheck
@onready var purchases_product_id_edit = $VBoxContainer/ScrollContainer/Content/SectionPurchases/SectionPurchasesVBox/PurchasesProductId
@onready var fetch_products_ids_edit = $VBoxContainer/ScrollContainer/Content/SectionProducts/SectionProductsVBox/FetchProductsHBox/FetchProductsIds
@onready var login_user_id_edit = $VBoxContainer/ScrollContainer/Content/SectionLogin/SectionLoginVBox/LoginHBox/LoginUserId
@onready var has_entitlement_id_edit = $VBoxContainer/ScrollContainer/Content/SectionEntitlements/SectionEntitlementsVBox/HasEntitlementHBox/HasEntitlementId
@onready var paywall_offering_id_edit = $VBoxContainer/ScrollContainer/Content/SectionPaywall/SectionPaywallVBox/PaywallHBox/PaywallOfferingId
@onready var log_output = $VBoxContainer/ScrollContainer/Content/LogOutput


# =======================================================
# UTILS
# =======================================================

func get_api_key() -> String:
	var os_name := OS.get_name()
	if os_name == "Android":
		return "goog_xyz"
	if os_name == "iOS":
		return "appl_xyz";
	return ""


func log_message(message: String) -> void:
	log_output.text += message + "\n"
	log_output.scroll_vertical = log_output.get_v_scroll_bar().max_value


func dict_to_string(dict: Dictionary) -> String:
	var out := "{\n"
	for key in dict.keys():
		out += "  %s: %s\n" % [key, dict[key]]
	out += "}"
	return out


func array_to_string(arr: Array) -> String:
	var out := "[\n"
	for item in arr:
		if typeof(item) == TYPE_DICTIONARY:
			out += "  %s,\n" % dict_to_string(item).replace("\n", "\n  ")
		else:
			out += "  %s,\n" % [item]
	out += "]"
	return out


# =======================================================
# READY
# =======================================================

func _ready():
	api_key_edit.text = get_api_key()

	if Engine.has_singleton(REVENUECAT_PLUGIN_NAME):
		revenuecat = Engine.get_singleton(REVENUECAT_PLUGIN_NAME)
		log_message("✅ GodotxRevenueCat plugin loaded")
		connect_signals()
	else:
		log_message("❌ GodotxRevenueCat plugin not found")


# =======================================================
# SIGNALS
# =======================================================

func connect_signals() -> void:
	if revenuecat == null:
		return

	revenuecat.customer_info_changed.connect(_on_customer_info_changed)
	revenuecat.customer_info.connect(_on_customer_info_received)
	revenuecat.purchase_result.connect(_on_purchase_result)
	revenuecat.offerings.connect(_on_offerings_received)
	revenuecat.products.connect(_on_products_received)
	revenuecat.login_finished.connect(_on_login_finished)
	revenuecat.logout_finished.connect(_on_logout_finished)
	revenuecat.subscriber.connect(_on_subscriber_result)
	revenuecat.entitlement.connect(_on_entitlement_result)
	revenuecat.paywall_result.connect(_on_paywall_result)
	revenuecat.restore_result.connect(_on_restore_result)

	log_message("🔌 Connected all RevenueCat signals")


# =======================================================
# BUTTON HANDLERS
# =======================================================

func _on_initialize_pressed():
	if revenuecat == null:
		return

	var api_key = api_key_edit.text
	var user_id = user_id_edit.text
	var debug_mode = debug_check.button_pressed

	if api_key.is_empty():
		log_message("⚠️ API Key required")
		return

	revenuecat.initialize(api_key, user_id, debug_mode)
	log_message("➡️ initialize(api_key=%s, user_id=%s)" % [api_key, user_id])


func _on_get_customer_info_pressed():
	if revenuecat == null:
		return
	revenuecat.get_customer_info()
	log_message("➡️ get_customer_info()")


func _on_purchase_pressed():
	if revenuecat == null:
		return

	var product_id = purchases_product_id_edit.text.strip_edges()
	if product_id.is_empty():
		log_message("⚠️ Product ID required")
		return

	revenuecat.purchase(product_id)
	log_message("➡️ purchase(%s)" % product_id)


func _on_fetch_offerings_pressed():
	if revenuecat == null:
		return
	revenuecat.fetch_offerings()
	log_message("➡️ fetch_offerings()")


func _on_fetch_products_pressed():
	if revenuecat == null:
		return

	var ids_text = fetch_products_ids_edit.text.strip_edges()
	if ids_text.is_empty():
		log_message("⚠️ IDs required")
		return

	var ids_list = ids_text.split(",", false)
	for i in range(ids_list.size()):
		ids_list[i] = ids_list[i].strip_edges()

	revenuecat.fetch_products(ids_list)
	log_message("➡️ fetch_products(%s)" % [ids_list])


func _on_login_pressed():
	if revenuecat == null:
		return

	var uid = login_user_id_edit.text.strip_edges()
	if uid.is_empty():
		log_message("⚠️ User ID required")
		return

	revenuecat.login(uid)
	log_message("➡️ login(%s)" % uid)


func _on_logout_pressed():
	if revenuecat == null:
		return
	revenuecat.logout()
	log_message("➡️ logout()")


func _on_is_subscriber_pressed():
	if revenuecat == null:
		return
	revenuecat.is_subscriber()
	log_message("➡️ is_subscriber()")


func _on_has_entitlement_pressed():
	if revenuecat == null:
		return

	var eid = has_entitlement_id_edit.text.strip_edges()
	if eid.is_empty():
		log_message("⚠️ Entitlement ID required")
		return

	var result = revenuecat.has_entitlement(eid)
	log_message("➡️ has_entitlement(%s) = %s" % [eid, result])


func _on_check_entitlement_pressed():
	if revenuecat == null:
		return

	var eid = has_entitlement_id_edit.text.strip_edges()
	if eid.is_empty():
		log_message("⚠️ Entitlement ID required")
		return

	revenuecat.check_entitlement(eid)
	log_message("➡️ check_entitlement(%s)" % eid)


func _on_present_paywall_pressed():
	if revenuecat == null:
		return
	var off_id = paywall_offering_id_edit.text.strip_edges()
	revenuecat.present_paywall(off_id)
	log_message("➡️ present_paywall(%s)" % off_id)


func _on_restore_purchases_pressed():
	if revenuecat == null:
		return
	revenuecat.restore_purchases()
	log_message("➡️ restore_purchases()")


func _on_clear_log_pressed():
	log_output.text = ""


# =======================================================
# SIGNAL CALLBACKS
# =======================================================

func _on_customer_info_changed(data):
	log_message("🔔 SIGNAL: customer_info_changed")
	log_message(dict_to_string(data))


func _on_customer_info_received(data):
	log_message("🔔 SIGNAL: customer_info")
	log_message(dict_to_string(data))


func _on_purchase_result(data):
	log_message("🔔 SIGNAL: purchase_result")

	if data.has("error"):
		log_message("   ❌ Error: %s" % data["error"])
	elif data.has("cancelled") and data["cancelled"] == true:
		log_message("   🚫 User cancelled")
	else:
		log_message("   ✅ Purchase OK")

	log_message(dict_to_string(data))


func _on_offerings_received(data):
	log_message("🔔 SIGNAL: offerings")
	log_message(dict_to_string(data))


func _on_products_received(data):
	log_message("🔔 SIGNAL: products")
	log_message(array_to_string(data))


func _on_login_finished(data):
	log_message("🔔 SIGNAL: login_finished")
	log_message(dict_to_string(data))


func _on_logout_finished(data):
	log_message("🔔 SIGNAL: logout_finished")
	log_message(dict_to_string(data))


func _on_subscriber_result(value):
	log_message("🔔 SIGNAL: subscriber")
	log_message("   Subscriber: %s" % value)


func _on_entitlement_result(ent_id, active):
	log_message("🔔 SIGNAL: entitlement")
	log_message("   %s active: %s" % [ent_id, active])


func _on_paywall_result(data):
	log_message("🔔 SIGNAL: paywall_result")
	log_message(dict_to_string(data))


func _on_restore_result(data):
	log_message("🔔 SIGNAL: restore_result")
	log_message(dict_to_string(data))
