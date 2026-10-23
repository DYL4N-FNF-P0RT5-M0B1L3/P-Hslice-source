package phslice;

/**
 * Puente (por reflexión) hacia backend.ClientPrefs de Psych/P-Slice.
 * Así P-Hslice compila aunque P-Slice cambie nombres de opciones: si una opción
 * no existe simplemente se ignora (y queda anotada en .P-Hslice/phslice.log).
 */
class Prefs
{
	static var cls:Class<Dynamic> = null;
	static var tried:Bool = false;

	static function resolve():Class<Dynamic>
	{
		if (!tried)
		{
			tried = true;
			cls = Type.resolveClass("backend.ClientPrefs");
		}
		return cls;
	}

	public static function data():Dynamic
	{
		var c = resolve();
		if (c == null) return null;
		try { return Reflect.field(c, "data"); } catch (e:Dynamic) {}
		return null;
	}

	public static function has(name:String):Bool
	{
		var d = data();
		return d != null && Reflect.hasField(d, name);
	}

	public static function get(name:String):Dynamic
	{
		var d = data();
		if (d != null && Reflect.hasField(d, name)) return Reflect.field(d, name);
		return null;
	}

	public static function set(name:String, value:Dynamic):Bool
	{
		var d = data();
		if (d == null || !Reflect.hasField(d, name)) return false;
		try { Reflect.setField(d, name, value); return true; } catch (e:Dynamic) {}
		return false;
	}

	public static function save():Void
	{
		var c = resolve();
		if (c == null) return;
		try
		{
			var f = Reflect.field(c, "saveSettings");
			if (f != null) Reflect.callMethod(c, f, []);
		}
		catch (e:Dynamic) {}
	}
}
