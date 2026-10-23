package phslice;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Modo patata: quita shaders / filtros y se salta eventos pesados de mods para evitar tirones y crasheos.
 * Se activa a mano (Opciones > Gráficos) o solo cuando se detecta grabación / directo.
 */
class PotatoMode
{
	public static var active(default, null):Bool = false;
	public static var autoOn:Bool = false; // lo pone BroadcastWatcher (PHSlice.checkBroadcast)

	// Opciones de Psych que se fuerzan mientras el modo está activo.
	static var forced:Map<String, Dynamic> = [
		"shaders" => false,
		"lowQuality" => true,
		"antialiasing" => false
	];

	// Eventos cuyo nombre contenga alguna de estas palabras se ignoran. Editable en .P-Hslice/potato_blocklist.txt
	static var blocklist:Array<String> = [
		"shader", "chrom", "aberration", "abberation", "bloom", "blur", "glitch", "distort", "vhs",
		"mosaic", "scanline", "fisheye", "filter", "video", "wavy", "lagtrain", "3d"
	];
	static var loadedList:Bool = false;

	/** ¿Debe estar encendido ahora? */
	public static function wanted():Bool
		return manual() || autoOn;

	public static function manual():Bool
	{
		var v = Prefs.get("potatoMode"); // opción añadida a ClientPrefs por el parche
		return v != null ? v == true : Config.potatoManual;
	}

	public static function setManual(on:Bool):Void
	{
		Config.potatoManual = on;
		Prefs.set("potatoMode", on);
		Prefs.save();
		Config.flush();
		refresh();
	}

	/** Aplica / quita el modo según wanted(). Barato: se llama cada segundo. */
	public static function refresh():Void
	{
		var w = wanted();
		if (w && !active) turnOn();
		else if (!w && active) turnOff();
		else if (active) enforce();
	}

	public static function sweep():Void
	{
		if (active) strip();
	}

	/** Tras un cierre forzado con el modo activo, restaura las opciones originales. */
	public static function restoreIfStale():Void
	{
		if (!active && Config.potatoBackup != null && !wanted()) restore();
	}

	static function turnOn():Void
	{
		if (Config.potatoBackup == null)
		{
			var b:Dynamic = {};
			for (k in forced.keys())
				if (Prefs.has(k)) Reflect.setField(b, k, Prefs.get(k));
			Config.potatoBackup = b;
			Config.flush();
		}
		active = true;
		enforce();
		strip();
		PHSlice.log("modo patata: ON");
	}

	static function turnOff():Void
	{
		active = false;
		restore();
		PHSlice.log("modo patata: OFF");
	}

	static function restore():Void
	{
		var b:Dynamic = Config.potatoBackup;
		if (b != null)
			for (k in Reflect.fields(b)) Prefs.set(k, Reflect.field(b, k));
		Config.potatoBackup = null;
		Config.flush();
		Prefs.save();
	}

	static function enforce():Void
	{
		for (k => v in forced) Prefs.set(k, v);
	}

	/** Quita filtros de cámara y shaders de los sprites del estado actual. */
	public static function strip():Void
	{
		try
		{
			FlxG.game.setFilters([]);
			for (c in FlxG.cameras.list) if (c != null) c.setFilters([]);
			walk(FlxG.state, 0);
		}
		catch (e:Dynamic) {}
	}

	static function walk(g:Dynamic, depth:Int):Void
	{
		if (g == null || depth > 6) return;
		var members:Array<Dynamic> = g.members;
		if (members == null) return;
		for (m in members)
		{
			if (m == null) continue;
			if (Std.isOfType(m, FlxSprite))
			{
				var s:FlxSprite = cast m;
				if (s.shader != null) s.shader = null;
			}
			else if (Std.isOfType(m, FlxBasic))
			{
				var mm:Dynamic = m;
				if (mm.members != null) walk(mm, depth + 1);
			}
		}
	}

	/** Gancho para PlayState.triggerEvent (lo inserta scripts/apply_overlay.py). */
	public static function shouldSkipEvent(name:String):Bool
	{
		if (!active || name == null) return false;
		loadList();
		var n = name.toLowerCase();
		for (k in blocklist)
			if (n.indexOf(k) >= 0) return true;
		return false;
	}

	static function loadList():Void
	{
		if (loadedList) return;
		loadedList = true;
		#if sys
		try
		{
			var f = ModPaths.root() + "potato_blocklist.txt";
			if (FileSystem.exists(f))
			{
				for (line in File.getContent(f).split("\n"))
				{
					var w = line.trim().toLowerCase();
					if (w.length > 0 && !w.startsWith("#") && blocklist.indexOf(w) < 0) blocklist.push(w);
				}
			}
			else
				File.saveContent(f, "# Palabras extra: los eventos de mods cuyo nombre las contenga se ignoran en modo patata.\n# Una por linea. Ejemplo:\n# rain\n");
		}
		catch (e:Dynamic) {}
		#end
	}
}
