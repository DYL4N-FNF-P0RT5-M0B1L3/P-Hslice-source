package phslice;

import flixel.FlxG;
import haxe.Timer;
import openfl.Lib;
import openfl.events.Event;
import phslice.ui.Drawer;
import phslice.ui.Menu;
import phslice.ui.Pointers;
import phslice.ui.Toast;
import phslice.ui.TouchControls;

using StringTools;

/** Punto de entrada de la capa P-Hslice. SplashState llama a PHSlice.start() al abrir la app. */
class PHSlice
{
	public static inline var APP_NAME:String = "P-Hslice";
	public static inline var ENGINE_NAME:String = "PHSLICE";
	public static inline var VERSION:String = "1.0.0";
	public static inline var FOLDER:String = ".P-Hslice";

	// Textos de las animaciones de entrada (cámbialos aquí)
	public static inline var SPLASH_TEXT_1:String = "DYLAN-FNF-PORTS-MOBILE";
	public static inline var SPLASH_TEXT_2:String = "DF' -PM -Projects";

	public static inline var URL_GAMEBANANA:String = "https://gamebanana.com/";
	public static inline var URL_PSLICE:String = "https://gamebanana.com/mods/535203";

	/** Estados donde aparece la pestaña lateral (coincide si el nombre de la clase contiene el texto). */
	public static var drawerStates:Array<String> = ["TitleState", "MainMenuState"];

	/** SplashState ya entregó el control al juego. */
	public static var handedOff:Bool = false;

	static var started:Bool = false;
	static var prefsReady:Bool = false;
	static var last:Float = 0;
	static var secAcc:Float = 0;
	static var watchAcc:Float = 0;
	static var lastBroadcast:Bool = false;

	public static function start():Void
	{
		if (started) return;
		started = true;
		safe("config", Config.load);
		safe("native", Native.init);
		safe("rutas", ModPaths.apply);
		safe("motores", Engines.load);
		safe("punteros", Pointers.init);
		safe("toast", Toast.init);
		safe("controles", TouchControls.init);
		safe("pestaña", Drawer.init);
		Lib.current.stage.addEventListener(Event.ENTER_FRAME, onFrame);
		FlxG.signals.postStateSwitch.add(onStateSwitch);
		log('$APP_NAME $VERSION iniciado. Carpeta: ' + ModPaths.root());
	}

	static function safe(name:String, f:Void->Void):Void
	{
		try { f(); } catch (e:Dynamic) { log('error en "$name": $e'); }
	}

	/** SplashState llama a esto justo antes de cambiar al estado original. */
	public static function handOff():Void
	{
		handedOff = true;
	}

	static function onStateSwitch():Void
	{
		// Primer cambio de estado tras el splash: P-Slice ya cargó sus opciones.
		if (handedOff && !prefsReady)
		{
			prefsReady = true;
			safe("motor", Engines.applyOnce);
			safe("patata-restaurar", PotatoMode.restoreIfStale);
		}
		safe("patata", PotatoMode.refresh);
		safe("patata-strip", PotatoMode.strip);
		if (Drawer.instance != null) Drawer.instance.refreshVisibility();
	}

	static function onFrame(_:Event):Void
	{
		var now = Timer.stamp();
		var dt = last == 0 ? 0 : now - last;
		last = now;
		if (dt > 0.25) dt = 0.25;

		Menu.tick(dt);
		Drawer.instance.tick(dt);
		Toast.tick(dt);
		TouchControls.instance.tick();

		secAcc += dt;
		if (secAcc >= 1)
		{
			secAcc = 0;
			safe("patata", PotatoMode.refresh);
			safe("patata-sweep", PotatoMode.sweep);
		}
		watchAcc += dt;
		if (watchAcc >= 2)
		{
			watchAcc = 0;
			safe("grabacion", checkBroadcast);
		}
	}

	/** Si se graba o transmite en directo, activa el modo patata automáticamente. */
	static function checkBroadcast():Void
	{
		var b = Native.isBroadcasting();
		if (b == lastBroadcast) return;
		lastBroadcast = b;
		if (!Config.autoPotato) return;
		PotatoMode.autoOn = b;
		PotatoMode.refresh();
		Toast.show(b ? "Grabación / directo detectado: Modo Patata ACTIVADO" : "Grabación terminada: Modo Patata (auto) apagado");
		log("broadcast=" + b);
	}

	public static function isBroadcasting():Bool
		return lastBroadcast;

	// ---------- utilidades de estado ----------

	public static function stateName():String
	{
		var s = FlxG.state;
		return s == null ? "" : Type.getClassName(Type.getClass(s));
	}

	public static function inGameplay():Bool
	{
		var n = stateName();
		return n == "PlayState" || n.endsWith(".PlayState");
	}

	public static function drawerAllowed():Bool
	{
		var n = stateName();
		for (k in drawerStates)
			if (n.indexOf(k) >= 0) return true;
		return false;
	}

	public static function needsStoragePrompt():Bool
	{
		#if android
		return !Config.askedStorage && !Native.hasAllFiles();
		#else
		return false;
		#end
	}

	public static function log(msg:String):Void
	{
		trace('[P-Hslice] $msg');
		#if sys
		try
		{
			var f = sys.io.File.append(ModPaths.root() + "phslice.log", false);
			f.writeString(msg + "\n");
			f.close();
		}
		catch (e:Dynamic) {}
		#end
	}
}
