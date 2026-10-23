package phslice;

import flixel.FlxState;

/**
 * Estado original del juego (el que P-Slice arrancaba antes de P-Hslice).
 * scripts/apply_overlay.py reemplaza este archivo por uno con la referencia exacta.
 */
class BootTarget
{
	public static function create():FlxState
	{
		for (n in ["states.TitleState", "mikolka.vslice.TitleState"])
		{
			var c = Type.resolveClass(n);
			if (c != null) return Type.createInstance(c, []);
		}
		throw "P-Hslice: no se encontró el estado inicial. Ejecuta scripts/apply_overlay.py";
	}
}
