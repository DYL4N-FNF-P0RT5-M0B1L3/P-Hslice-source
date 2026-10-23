package phslice.ui;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.text.TextFormatAlign;

/** Aviso corto abajo en pantalla. */
class Toast extends Sprite
{
	static var inst:Toast;
	var life:Float = 0;

	public static function init():Void
	{
		if (inst != null) return;
		inst = new Toast();
		inst.mouseEnabled = false;
		inst.visible = false;
		Lib.current.stage.addChild(inst);
	}

	public static function show(text:String, secs:Float = 2.8):Void
	{
		init();
		inst.display(text, secs);
	}

	public static function tick(dt:Float):Void
	{
		if (inst != null && inst.visible) inst.update(dt);
	}

	function display(text:String, secs:Float):Void
	{
		removeChildren();
		graphics.clear();
		var s = Kit.s();
		var tf = Kit.label(text, 22 * s, Kit.TEXT, true, TextFormatAlign.CENTER, Math.min(Kit.sw() * 0.8, 760 * s));
		var w = tf.width + 44 * s;
		var h = tf.height + 28 * s;
		Kit.rect(graphics, 0, 0, w, h, 0x120E1C, 0.92, 14 * s);
		tf.x = 22 * s;
		tf.y = 14 * s;
		addChild(tf);
		x = (Kit.sw() - w) / 2;
		y = Kit.sh() - h - 36 * s;
		life = secs;
		alpha = 1;
		visible = true;
		Lib.current.stage.addChild(this);
	}

	function update(dt:Float):Void
	{
		life -= dt;
		if (life < 0.4) alpha = Math.max(0, life / 0.4);
		if (life <= 0) visible = false;
	}
}
