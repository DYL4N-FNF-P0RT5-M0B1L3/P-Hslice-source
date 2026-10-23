package phslice;

import flixel.util.FlxSave;

/** Ajustes propios de P-Hslice (se guardan aparte de los de Psych/P-Slice). */
class Config
{
	static var save:FlxSave;

	public static var engine:String = "phslice";
	public static var engineApplied:String = "";

	// Controles táctiles: "hitbox" | "vslice" | "classic"
	public static var padStyle:String = "hitbox";
	public static var padAlpha:Float = 0.45;
	public static var padHeight:Float = 1.0; // hitbox / vslice: fracción de la altura de pantalla
	public static var classicScale:Float = 1.0;
	public static var classicPos:Array<Float> = null; // 4 botones x (x,y) normalizados (centro)
	public static var pauseButton:Bool = true;
	public static var haptics:Bool = true;

	// Modo patata
	public static var potatoManual:Bool = false;
	public static var autoPotato:Bool = true;
	public static var potatoBackup:Dynamic = null;

	public static var askedStorage:Bool = false;

	public static function load():Void
	{
		save = new FlxSave();
		save.bind("phslice_config");
		var d:Dynamic = save.data;
		engine = pick(d.engine, engine);
		engineApplied = pick(d.engineApplied, engineApplied);
		padStyle = pick(d.padStyle, padStyle);
		padAlpha = pick(d.padAlpha, padAlpha);
		padHeight = pick(d.padHeight, padHeight);
		classicScale = pick(d.classicScale, classicScale);
		classicPos = pick(d.classicPos, classicPos);
		pauseButton = pick(d.pauseButton, pauseButton);
		haptics = pick(d.haptics, haptics);
		potatoManual = pick(d.potatoManual, potatoManual);
		autoPotato = pick(d.autoPotato, autoPotato);
		potatoBackup = pick(d.potatoBackup, potatoBackup);
		askedStorage = pick(d.askedStorage, askedStorage);
	}

	public static function flush():Void
	{
		if (save == null) return;
		var d:Dynamic = save.data;
		d.engine = engine;
		d.engineApplied = engineApplied;
		d.padStyle = padStyle;
		d.padAlpha = padAlpha;
		d.padHeight = padHeight;
		d.classicScale = classicScale;
		d.classicPos = classicPos;
		d.pauseButton = pauseButton;
		d.haptics = haptics;
		d.potatoManual = potatoManual;
		d.autoPotato = autoPotato;
		d.potatoBackup = potatoBackup;
		d.askedStorage = askedStorage;
		save.flush();
	}

	public static function resetControls():Void
	{
		padStyle = "hitbox";
		padAlpha = 0.45;
		padHeight = 1.0;
		classicScale = 1.0;
		classicPos = null;
		pauseButton = true;
		haptics = true;
		flush();
	}

	static inline function pick(v:Dynamic, def:Dynamic):Dynamic
		return v == null ? def : v;
}
