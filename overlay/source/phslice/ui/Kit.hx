package phslice.ui;

import openfl.Assets;
import openfl.Lib;
import openfl.display.Graphics;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

/** Pequeño kit de dibujo en OpenFL (independiente de Flixel, funciona sobre cualquier estado). */
class Kit
{
	public static inline var PANEL:Int = 0x211A30;
	public static inline var ROW:Int = 0x2E2543;
	public static inline var ROW_HI:Int = 0x44366A;
	public static inline var ACCENT:Int = 0x8E6FE0;
	public static inline var TEXT:Int = 0xFFFFFF;
	public static inline var DIM:Int = 0xB8AED0;
	public static inline var GOOD:Int = 0x6BE07A;

	static var fontName:String = null;

	/** Escala de interfaz respecto a 720p de alto. */
	public static function s():Float
		return Lib.current.stage.stageHeight / 720.0;

	public static function sw():Float
		return Lib.current.stage.stageWidth;

	public static function sh():Float
		return Lib.current.stage.stageHeight;

	public static function font():String
	{
		if (fontName == null)
		{
			fontName = "_sans";
			try
			{
				for (p in ["assets/fonts/vcr.ttf", "assets/fonts/pixel.otf"])
					if (Assets.exists(p))
					{
						fontName = Assets.getFont(p).fontName;
						break;
					}
			}
			catch (e:Dynamic) {}
		}
		return fontName;
	}

	/** Texto. Si w > 0 hace salto de línea a ese ancho. */
	public static function label(text:String, size:Float, color:Int = 0xFFFFFF, bold:Bool = false, align:TextFormatAlign = null, w:Float = 0):TextField
	{
		var t = new TextField();
		t.defaultTextFormat = new TextFormat(font(), Std.int(size), color, bold, null, null, null, null, align == null ? TextFormatAlign.LEFT : align);
		t.selectable = false;
		t.mouseEnabled = false;
		t.multiline = true;
		if (w > 0)
		{
			t.wordWrap = true;
			t.width = w;
		}
		t.autoSize = TextFieldAutoSize.LEFT;
		t.text = text;
		return t;
	}

	public static function rect(g:Graphics, x:Float, y:Float, w:Float, h:Float, color:Int, alpha:Float = 1, radius:Float = 0):Void
	{
		g.beginFill(color, alpha);
		if (radius > 0) g.drawRoundRect(x, y, w, h, radius * 2, radius * 2);
		else g.drawRect(x, y, w, h);
		g.endFill();
	}

	public static function clamp(v:Float, lo:Float, hi:Float):Float
		return v < lo ? lo : (v > hi ? hi : v);
}
