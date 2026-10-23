package phslice.ui;

import flixel.FlxG;
import openfl.Lib;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import phslice.ui.Pointers.PointerListener;
import phslice.ui.Pointers.Ptr;

typedef Rect = { x:Float, y:Float, w:Float, h:Float };
private typedef Tool = { label:String, r:Rect, act:Void->Void };

/**
 * Controles táctiles propios para la partida: Hitbox / V-Slice / Clásico (4 botones), con edición.
 * Envían las teclas de flecha (←↓↑→) y Escape (pausa) como eventos de teclado, así que funcionan con
 * cualquier mod de Psych / V-Slice sin tocar PlayState.
 */
class TouchControls extends Sprite implements PointerListener
{
	public static var instance:TouchControls;
	public static var editing(default, null):Bool = false;

	static final KEYS:Array<Int> = [37, 40, 38, 39]; // izquierda, abajo, arriba, derecha
	static final PAUSE_KEY:Int = 27;
	static final COLORS:Array<Int> = [0xC24B99, 0x00FFFF, 0x12FA05, 0xF9393F];
	static final ANGLES:Array<Float> = [0, 270, 90, 180];

	public static function init():Void
	{
		if (instance != null) return;
		instance = new TouchControls();
		Lib.current.stage.addChild(instance);
		Pointers.add(instance, 10);
		instance.visible = false;
		Lib.current.stage.addEventListener(Event.RESIZE, (_) -> instance.refresh());
	}

	public static function setStyle(id:String):Void
	{
		Config.padStyle = id;
		Config.padHeight = id == "vslice" ? 0.55 : 1.0;
		Config.flush();
		instance.refresh();
	}

	var rects:Array<Rect> = [for (i in 0...4) ({ x: 0, y: 0, w: 0, h: 0 } : Rect)];
	var pauseRect:Rect = { x: 0, y: 0, w: 0, h: 0 };
	var down:Array<Bool> = [false, false, false, false];
	var pauseDown:Bool = false;
	var shown:Bool = false;
	var tools:Array<Tool> = [];
	var pendingTool:Tool = null;
	var dragIdx:Int = -1;
	var dragDX:Float = 0;
	var dragDY:Float = 0;
	var bk:Dynamic = null;

	function new()
	{
		super();
	}

	// ---------- visibilidad ----------

	public function tick():Void
	{
		var state = FlxG.state;
		var want = editing || (PHSlice.inGameplay() && state != null && state.subState == null);
		if (want != shown)
		{
			shown = want;
			visible = want;
			if (!want) releaseAll();
			else refresh();
		}
	}

	function releaseAll():Void
	{
		for (i in 0...4)
			if (down[i])
			{
				down[i] = false;
				key(KEYS[i], false);
			}
		if (pauseDown)
		{
			pauseDown = false;
			key(PAUSE_KEY, false);
		}
	}

	// ---------- layout y dibujo ----------

	static function defaultClassic():Array<Float>
		return [0.20, 0.80, 0.36, 0.80, 0.64, 0.80, 0.80, 0.80];

	public function refresh():Void
	{
		relayout();
		draw();
	}

	function relayout():Void
	{
		var W = Kit.sw();
		var H = Kit.sh();
		var s = Kit.s();
		if (Config.padStyle == "classic")
		{
			var size = 150 * s * Config.classicScale;
			var pos = (Config.classicPos != null && Config.classicPos.length == 8) ? Config.classicPos : defaultClassic();
			for (i in 0...4)
				rects[i] = { x: pos[i * 2] * W - size / 2, y: pos[i * 2 + 1] * H - size / 2, w: size, h: size };
		}
		else
		{
			var h = Config.padHeight * H;
			for (i in 0...4)
				rects[i] = { x: i * W / 4, y: H - h, w: W / 4, h: h };
		}
		pauseRect = { x: W - 76 * s, y: 14 * s, w: 60 * s, h: 60 * s };
		buildTools();
	}

	function buildTools():Void
	{
		tools = [];
		if (!editing) return;
		var s = Kit.s();
		var classic = Config.padStyle == "classic";
		var defs:Array<{ l:String, a:Void->Void }> = [
			{ l: classic ? "Tam -" : "Alto -", a: () -> adjust(classic ? 0 : 1, -1) },
			{ l: classic ? "Tam +" : "Alto +", a: () -> adjust(classic ? 0 : 1, 1) },
			{ l: "Opac -", a: () -> adjust(2, -1) },
			{ l: "Opac +", a: () -> adjust(2, 1) },
			{ l: "Reset", a: () -> { Config.resetControls(); refresh(); } },
			{ l: "Cancelar", a: () -> stopEditing(false) },
			{ l: "Guardar", a: () -> stopEditing(true) }
		];
		var bw = 126 * s;
		var gap = 10 * s;
		var total = defs.length * bw + (defs.length - 1) * gap;
		var x0 = (Kit.sw() - total) / 2;
		for (i in 0...defs.length)
			tools.push({ label: defs[i].l, r: { x: x0 + i * (bw + gap), y: 96 * s, w: bw, h: 52 * s }, act: defs[i].a });
	}

	function adjust(what:Int, dir:Int):Void
	{
		switch (what)
		{
			case 0: Config.classicScale = Kit.clamp(Config.classicScale + dir * 0.1, 0.5, 1.8);
			case 1: Config.padHeight = Kit.clamp(Config.padHeight + dir * 0.05, 0.3, 1.0);
			default: Config.padAlpha = Kit.clamp(Config.padAlpha + dir * 0.05, 0.1, 1.0);
		}
		refresh();
	}

	function draw():Void
	{
		removeChildren();
		var g = graphics;
		g.clear();
		var a = Config.padAlpha;
		var s = Kit.s();
		if (editing) Kit.rect(g, 0, 0, Kit.sw(), Kit.sh(), 0x000000, 0.5);

		switch (Config.padStyle)
		{
			case "classic":
				for (i in 0...4)
				{
					var r = rects[i];
					var d = down[i];
					Kit.rect(g, r.x, r.y, r.w, r.h, 0x000000, d ? a * 0.9 : a * 0.35, 20 * s);
					arrow(g, r.x + r.w / 2, r.y + r.h / 2, r.w * 0.34, ANGLES[i], COLORS[i], d ? 1 : Math.min(1, a + 0.3));
				}
			case "vslice":
				for (i in 0...4)
				{
					var r = rects[i];
					var d = down[i];
					var m = 8 * s;
					Kit.rect(g, r.x + m, r.y + m, r.w - 2 * m, r.h - 2 * m, d ? COLORS[i] : 0x101018, d ? a * 0.75 : a * 0.55, 22 * s);
					g.lineStyle(3 * s, COLORS[i], Math.min(1, a + 0.35));
					g.drawRoundRect(r.x + m, r.y + m, r.w - 2 * m, r.h - 2 * m, 44 * s, 44 * s);
					g.lineStyle();
					arrow(g, r.x + r.w / 2, r.y + r.h * 0.5, Math.min(r.w, r.h) * 0.22, ANGLES[i], d ? 0xFFFFFF : COLORS[i], Math.min(1, a + 0.4));
				}
			default: // hitbox
				for (i in 0...4)
				{
					var r = rects[i];
					Kit.rect(g, r.x, r.y, r.w, r.h, COLORS[i], down[i] ? a * 0.8 : a * 0.16);
					if (i > 0) Kit.rect(g, r.x - 1, r.y, 2, r.h, 0xFFFFFF, a * 0.4);
				}
		}

		if (Config.pauseButton || editing)
		{
			var p = pauseRect;
			Kit.rect(g, p.x, p.y, p.w, p.h, 0x000000, pauseDown ? 0.8 : 0.4, 14 * s);
			Kit.rect(g, p.x + p.w * 0.30, p.y + p.h * 0.24, p.w * 0.14, p.h * 0.52, 0xFFFFFF, 0.9, 2 * s);
			Kit.rect(g, p.x + p.w * 0.56, p.y + p.h * 0.24, p.w * 0.14, p.h * 0.52, 0xFFFFFF, 0.9, 2 * s);
		}

		if (editing)
		{
			for (t in tools)
			{
				Kit.rect(g, t.r.x, t.r.y, t.r.w, t.r.h, Kit.ROW_HI, 1, 10 * s);
				var tf = Kit.label(t.label, 22 * s, Kit.TEXT, true);
				tf.x = t.r.x + (t.r.w - tf.width) / 2;
				tf.y = t.r.y + (t.r.h - tf.height) / 2;
				addChild(tf);
			}
			var hint = Kit.label(Config.padStyle == "classic" ? "Arrastra cada botón a donde quieras" : "Ajusta alto y opacidad con los botones", 24 * s, Kit.TEXT, true);
			hint.x = (Kit.sw() - hint.width) / 2;
			hint.y = 40 * s;
			addChild(hint);
		}
	}

	static function arrow(g:Graphics, cx:Float, cy:Float, u:Float, deg:Float, color:Int, alpha:Float):Void
	{
		var pts = [-1.0, 0.0, 0.0, -1.0, 0.0, -0.45, 1.0, -0.45, 1.0, 0.45, 0.0, 0.45, 0.0, 1.0];
		var th = deg * Math.PI / 180;
		var c = Math.cos(th);
		var sn = Math.sin(th);
		g.beginFill(color, alpha);
		g.lineStyle(Math.max(2, u * 0.12), 0x000000, alpha);
		var i = 0;
		while (i < pts.length)
		{
			var x = pts[i] * u;
			var y = pts[i + 1] * u;
			var rx = cx + x * c - y * sn;
			var ry = cy + x * sn + y * c;
			if (i == 0) g.moveTo(rx, ry);
			else g.lineTo(rx, ry);
			i += 2;
		}
		g.endFill();
		g.lineStyle();
	}

	// ---------- edición ----------

	public function startEditing():Void
	{
		Menu.closeAll();
		editing = true;
		bk = { a: Config.padAlpha, h: Config.padHeight, sc: Config.classicScale, pos: Config.classicPos == null ? null : Config.classicPos.copy(), st: Config.padStyle };
		if (Config.classicPos == null) Config.classicPos = defaultClassic();
		shown = true;
		visible = true;
		Lib.current.stage.addChild(this);
		if (Drawer.instance != null) Drawer.instance.refreshVisibility();
		refresh();
	}

	function stopEditing(save:Bool):Void
	{
		editing = false;
		if (save) Config.flush();
		else if (bk != null)
		{
			Config.padAlpha = bk.a;
			Config.padHeight = bk.h;
			Config.classicScale = bk.sc;
			Config.classicPos = bk.pos;
			Config.padStyle = bk.st;
		}
		bk = null;
		dragIdx = -1;
		shown = false;
		visible = false;
		tools = [];
		refresh();
		if (Drawer.instance != null) Drawer.instance.refreshVisibility();
		Menu.open("Controles", Pages.controls);
	}

	// ---------- entrada ----------

	static function hit(r:Rect, x:Float, y:Float):Bool
		return x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;

	static function key(code:Int, isDown:Bool):Void
	{
		Lib.current.stage.dispatchEvent(new KeyboardEvent(isDown ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, 0, code));
	}

	public function onPointerDown(p:Ptr):Bool
	{
		if (!shown) return false;
		if (editing)
		{
			pendingTool = null;
			dragIdx = -1;
			for (t in tools)
				if (hit(t.r, p.x, p.y))
				{
					pendingTool = t;
					return true;
				}
			if (Config.padStyle == "classic")
				for (i in 0...4)
					if (hit(rects[i], p.x, p.y))
					{
						dragIdx = i;
						dragDX = p.x - rects[i].x;
						dragDY = p.y - rects[i].y;
						break;
					}
			return true;
		}
		var inside = hit(pauseRect, p.x, p.y) && Config.pauseButton;
		for (i in 0...4)
			if (hit(rects[i], p.x, p.y)) inside = true;
		if (!inside) return false;
		update();
		return true;
	}

	public function onPointerMove(p:Ptr):Void
	{
		if (editing)
		{
			if (dragIdx >= 0 && p.moved)
			{
				var r = rects[dragIdx];
				r.x = Kit.clamp(p.x - dragDX, 0, Kit.sw() - r.w);
				r.y = Kit.clamp(p.y - dragDY, 0, Kit.sh() - r.h);
				var pos = Config.classicPos;
				pos[dragIdx * 2] = (r.x + r.w / 2) / Kit.sw();
				pos[dragIdx * 2 + 1] = (r.y + r.h / 2) / Kit.sh();
				draw();
			}
			return;
		}
		update();
	}

	public function onPointerUp(p:Ptr):Void
	{
		if (editing)
		{
			if (pendingTool != null && !p.moved)
			{
				var t = pendingTool;
				pendingTool = null;
				t.act();
			}
			dragIdx = -1;
			return;
		}
		update();
	}

	/** Recalcula qué botones están pulsados según los dedos que nos pertenecen y envía las teclas. */
	function update():Void
	{
		var now = [false, false, false, false];
		var pz = false;
		for (p in Pointers.active)
		{
			if (p.owner != this) continue;
			for (i in 0...4)
				if (hit(rects[i], p.x, p.y)) now[i] = true;
			if (Config.pauseButton && hit(pauseRect, p.x, p.y)) pz = true;
		}
		var changed = false;
		for (i in 0...4)
			if (now[i] != down[i])
			{
				down[i] = now[i];
				key(KEYS[i], now[i]);
				if (now[i] && Config.haptics) Native.vibrate(8);
				changed = true;
			}
		if (pz != pauseDown)
		{
			pauseDown = pz;
			key(PAUSE_KEY, pz);
			changed = true;
		}
		if (changed) draw();
	}
}
