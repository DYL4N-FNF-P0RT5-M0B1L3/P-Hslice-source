package phslice;

import haxe.Json;
import openfl.Assets;

typedef EngineDef = { id:String, name:String, short:String, desc:String, ?padStyle:String, ?prefs:Dynamic };

/**
 * Perfiles de motor (PHSLICE / Psych Engine / V-Slice / P-Slice).
 * P-Slice ya contiene el código de Psych Engine y de V-Slice en un solo binario, así que un "motor"
 * es un perfil: un conjunto de opciones (assets/shared/phslice/engines.json) que se aplican a ClientPrefs.
 */
class Engines
{
	public static var list:Array<EngineDef> = [];

	public static function load():Void
	{
		try
		{
			var j:Dynamic = Json.parse(Assets.getText("assets/shared/phslice/engines.json"));
			list = j.engines;
		}
		catch (e:Dynamic)
		{
			PHSlice.log("engines.json: " + e);
		}
		if (list == null || list.length == 0)
			list = [{ id: "phslice", name: "PHSLICE", short: "Psych + V-Slice + P-Slice", desc: "Motor por defecto." }];
	}

	public static function current():EngineDef
	{
		for (e in list) if (e.id == Config.engine) return e;
		return list[0];
	}

	public static function select(id:String):Void
	{
		Config.engine = id;
		applyProfile(current());
		Config.flush();
	}

	/** Se llama una vez que P-Slice ya cargó sus opciones. Solo aplica si cambió el motor elegido. */
	public static function applyOnce():Void
	{
		if (Config.engineApplied != Config.engine)
		{
			applyProfile(current());
			Config.flush();
		}
	}

	static function applyProfile(d:EngineDef):Void
	{
		if (d.padStyle != null)
		{
			Config.padStyle = d.padStyle;
			Config.padHeight = d.padStyle == "vslice" ? 0.55 : 1.0;
		}
		if (d.prefs != null)
		{
			var n = 0;
			for (k in Reflect.fields(d.prefs))
			{
				if (Prefs.set(k, Reflect.field(d.prefs, k))) n++;
				else PHSlice.log('perfil ${d.id}: la opcion "$k" no existe en ClientPrefs (se ignora)');
			}
			if (n > 0) Prefs.save();
		}
		Config.engineApplied = d.id;
		PHSlice.log("motor aplicado: " + d.id);
	}
}
