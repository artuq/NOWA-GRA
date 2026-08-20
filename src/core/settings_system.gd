## SettingsSystem owns persisted player-facing accessibility/UX preferences:
## reduce_motion and the player's language preference. Language is persisted as
## "system", "en", or "pl" (never as a resolved device locale), so choosing
## "system" keeps doing what it says after the device language changes.
##
## Same shape as OnboardingGate (ADR-0001 peer-module pattern): a plain
## Autoload with serialize_state()/restore_state(), registered in SaveSystem's
## boot order. No new architectural pattern here -- ADR-0001 already covers
## "every Core/Foundation module is a Godot Autoload singleton."
##
## UI never mutates reduce_motion directly (UI must not own state) -- it calls
## set_reduce_motion(), which also marks the save dirty. Reads (e.g.
## CardScreen at resolution time) go straight to the public field, matching
## this codebase's established read-directly / write-through-a-method split
## (e.g. HistoryFlagManager.get_counter() reads freely; ActionSystem.
## start_action() is the sole write path for its own state).
##
## Usage example:
##   SettingsSystem.set_reduce_motion(true)
##   SettingsSystem.set_language_preference(SettingsSystem.LANGUAGE_PL)
extends Node

## Emitted after a language preference is applied. [param preference] is the
## persisted choice ("system", "en", or "pl") and [param locale] is the
## effective TranslationServer locale ("en" or "pl_PL").
signal language_changed(preference: StringName, locale: StringName)

## Follow the operating-system language, with English as the safe fallback.
const LANGUAGE_SYSTEM: StringName = &"system"
## Force English regardless of the operating-system language.
const LANGUAGE_EN: StringName = &"en"
## Force Polish regardless of the operating-system language.
const LANGUAGE_PL: StringName = &"pl"

## Canonical runtime locale for the Polish translation catalogs. The saved
## preference intentionally remains the short, stable "pl" value.
const LOCALE_PL_PL: StringName = &"pl_PL"

const _SUPPORTED_LANGUAGE_PREFERENCES: Array[StringName] = [
	LANGUAGE_SYSTEM,
	LANGUAGE_EN,
	LANGUAGE_PL,
]

## Reduce-motion accessibility flag. Defaults false (motion effects at full
## strength) -- matches every other peer module's "first-session default"
## convention (e.g. HistoryFlagManager's empty counters).
var reduce_motion: bool = false

## Persisted language choice. The effective locale is intentionally resolved
## at runtime rather than stored, preserving "system" semantics.
var language_preference: StringName = LANGUAGE_SYSTEM
## Distinguishes automatic system-locale resolution from a real player choice.
## A fresh install starts false so BootController can show the language gate.
var language_choice_confirmed: bool = false


func _ready() -> void:
	_apply_language_preference()


## Sets [param value] and marks the save dirty. The only write path for
## reduce_motion -- UI (SettingsScreen) calls this, never sets the field
## directly, keeping "UI displays state, does not own it" true for this
## module too.
##
## Example:
##   SettingsSystem.set_reduce_motion(true)
func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	SaveSystem.mark_dirty()


## Persists and immediately applies [param preference]. Unknown values are
## sanitized to [constant LANGUAGE_SYSTEM], keeping old/corrupt saves safe.
##
## Example:
##   SettingsSystem.set_language_preference(SettingsSystem.LANGUAGE_EN)
func set_language_preference(preference: Variant) -> void:
	var sanitized: StringName = _sanitize_language_preference(preference)
	var changed: bool = language_preference != sanitized or not language_choice_confirmed
	language_preference = sanitized
	language_choice_confirmed = true
	_apply_language_preference()
	if changed:
		SaveSystem.mark_dirty()


## Resolves a persisted [param preference] against an injected
## [param system_language]. This pure seam deliberately avoids reading OS state
## so locale policy can be tested deterministically. Polish system locales map
## to canonical "pl_PL"; every other system locale maps to the English fallback.
##
## Example:
##   var locale := SettingsSystem.resolve_locale("system", "pl_PL") # "pl_PL"
static func resolve_locale(preference: Variant, system_language: String) -> StringName:
	var sanitized: StringName = _sanitize_language_preference(preference)
	if sanitized == LANGUAGE_EN:
		return LANGUAGE_EN
	if sanitized == LANGUAGE_PL:
		return LOCALE_PL_PL

	var normalized_system_language: String = system_language.strip_edges().to_lower()
	if (
		normalized_system_language == "pl"
		or normalized_system_language.begins_with("pl_")
		or normalized_system_language.begins_with("pl-")
	):
		return LOCALE_PL_PL
	return LANGUAGE_EN


## Serializes this module's state for SaveSystem.save_now()'s payload, under
## the "settings" key. Plain JSON-serializable shape (bool), matching the
## established convention (see OnboardingGate.serialize_state()).
##
## Example:
##   var snapshot: Dictionary = SettingsSystem.serialize_state()
func serialize_state() -> Dictionary:
	return {
		"reduce_motion": reduce_motion,
		"language_preference": String(language_preference),
		"language_choice_confirmed": language_choice_confirmed,
	}


## Restores from [param data] (the "settings" sub-dict, or {} on first session
## / a save predating this module) -- never crashes, falls back to the false
## default per SaveSystem's "missing key -> default" contract.
##
## Example:
##   SettingsSystem.restore_state(data.get("settings", {}))
func restore_state(data: Dictionary) -> void:
	reduce_motion = bool(data.get("reduce_motion", false))
	language_preference = _sanitize_language_preference(
		data.get("language_preference", LANGUAGE_SYSTEM)
	)
	language_choice_confirmed = bool(data.get("language_choice_confirmed", false))
	_apply_language_preference()


func _apply_language_preference() -> void:
	var locale: StringName = resolve_locale(language_preference, OS.get_locale_language())
	TranslationServer.set_locale(String(locale))
	language_changed.emit(language_preference, locale)


static func _sanitize_language_preference(preference: Variant) -> StringName:
	var normalized: StringName = StringName(String(preference).strip_edges().to_lower())
	if normalized in _SUPPORTED_LANGUAGE_PREFERENCES:
		return normalized
	return LANGUAGE_SYSTEM
