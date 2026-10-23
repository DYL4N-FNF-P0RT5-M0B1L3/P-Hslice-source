package phslice.options;

import flixel.FlxSubState;
import phslice.ui.Menu;
import phslice.ui.Pages;

/**
 * Entrada "P-Hslice" del menú Options de P-Slice. Solo es un cascarón de Flixel:
 * abre el menú táctil de P-Hslice y se cierra cuando éste se cierra.
 */
class PHSliceOptionsSubState extends FlxSubState
{
	override function create():Void
	{
		super.create();
		Menu.open("P-Hslice", Pages.root, () -> close());
	}
}
