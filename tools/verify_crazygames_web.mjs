import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const presetText = fs.readFileSync("export_presets.cfg", "utf8");
const headMatch = presetText.match(/html\/head_include="([\s\S]*?)"\n\n\[preset\.1\]/);
assert(headMatch, "Web html/head_include was not found before the Android preset");

const scripts = [...headMatch[1].matchAll(/<script>([\s\S]*?)<\/script>/g)];
assert.equal(scripts.length, 1, "Expected exactly one inline Web bootstrap script");

let injectedSdkScript;
const context = {
	console,
	devicePixelRatio: 1,
	innerHeight: 1280,
	innerWidth: 720,
	history: { pushState() {} },
	document: {
		addEventListener() {},
		getElementById() { return null; },
		createElement(tag) {
			assert.equal(tag, "script");
			return {};
		},
		head: {
			appendChild(node) { injectedSdkScript = node; },
		},
	},
	addEventListener() {},
};
context.window = context;
vm.createContext(context);
new vm.Script(scripts[0][1], { filename: "crazygames-web-bootstrap.js" }).runInContext(context);

assert(injectedSdkScript, "CrazyGames SDK script was not injected");
assert.equal(injectedSdkScript.src, "https://sdk.crazygames.com/crazygames-sdk-v3.js");

// GDScript can reach boot and gameplay before the asynchronous SDK init.
// The adapter must remember both events, then replay them in portal order.
context.kocSDK.loadingComplete();
context.kocSDK.setGameplay(true);
assert.equal(context.kocSDK.ready, false);
assert.equal(context.kocSDK._desiredPlaying, true);

const events = [];
const cloudData = new Map();
context.CrazyGames = {
	SDK: {
		environment: "local",
		async init() { events.push("init"); },
		data: {
			getItem(key) {
				events.push(`dataGet:${key}`);
				return cloudData.get(key) ?? null;
			},
			setItem(key, value) {
				events.push(`dataSet:${key}`);
				cloudData.set(key, value);
			},
		},
		game: {
			loadingStart() { events.push("loadingStart"); },
			loadingStop() { events.push("loadingStop"); },
			gameplayStart() { events.push("gameplayStart"); },
			gameplayStop() { events.push("gameplayStop"); },
			happytime() { events.push("happytime"); },
		},
	},
};
await injectedSdkScript.onload();
assert.deepEqual(events, ["init", "loadingStart", "loadingStop", "gameplayStart"]);
assert.equal(context.kocSDK.dataStatus, "enabled");

// Progress saves use one account-aware Data Module key. The adapter must
// round-trip the exact JSON string expected by Godot's existing save schema.
assert.equal(context.kocSDK.getSave(), null);
assert.equal(context.kocSDK.setSave('{"schema_version":1,"resources":{}}'), true);
assert.equal(context.kocSDK.getSave(), '{"schema_version":1,"resources":{}}');
assert.deepEqual(events.slice(4, 7), [
	"dataGet:king_of_cringe_save_v1",
	"dataSet:king_of_cringe_save_v1",
	"dataGet:king_of_cringe_save_v1",
]);

// Repeated scene notifications must be idempotent; real state transitions
// still produce one matching gameplay event each.
context.kocSDK.loadingComplete();
context.kocSDK.setGameplay(true);
assert.equal(events.filter((event) => event === "loadingStop").length, 1);
assert.equal(events.filter((event) => event === "gameplayStart").length, 1);
context.kocSDK.setGameplay(false);
context.kocSDK.setGameplay(false);
context.kocSDK.setGameplay(true);
context.kocSDK.setGameplay(true);
context.kocSDK.happytime();
assert.deepEqual(events.slice(7), ["gameplayStop", "gameplayStart", "happytime"]);

const androidSection = presetText.split("\n[preset.1]\n")[1];
assert(androidSection, "Android preset is missing");
assert.match(androidSection, /name="Android AAB"/);
assert.doesNotMatch(androidSection, /CrazyGames|kocSDK|JavaScriptBridge/);

const bootSource = fs.readFileSync("src/core/boot_controller.gd", "utf8");
assert.match(
	bootSource,
	/if OS\.has_feature\("web"\):\s+await SaveSystem\.prepare_web_data\(\)\s+JavaScriptBridge\.eval\("window\.kocSDK && window\.kocSDK\.loadingComplete\(\);", true\)/,
);
const saveSource = fs.readFileSync("src/core/save_system.gd", "utf8");
assert.match(saveSource, /func prepare_web_data\(\) -> bool:/);
assert.match(saveSource, /window\.kocSDK && window\.kocSDK\.setSave/);
assert.match(saveSource, /if OS\.has_feature\("web"\) and _web_data_enabled:/);
const actionSource = fs.readFileSync("src/ui/action_screen.gd", "utf8");
assert.match(actionSource, /if OS\.has_feature\("web"\):\s+_web_arm_back_trap\(\)/);
assert.match(actionSource, /window\.kocSDK && window\.kocSDK\.setGameplay/);

console.log("CrazyGames Web verification: PASS");
