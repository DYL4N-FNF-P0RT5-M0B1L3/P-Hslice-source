package phslice.ui;

import haxe.Timer;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;

typedef Ptr = { id:Int, x:Float, y:Float, sx:Float, sy:Float, owner:PointerListener, moved:Bool };

interface PointerListener
{
	/** true = este componente se queda con el toque (Flixel no lo recibe). */
	public function onPointerDown(p:Ptr):Bool;
	public function onPointerMove(p:Ptr):Void;
	public function onPointerUp(p:Ptr):Void;
}

private typedef Entry = { l:PointerListener, prio:Int };

/** Hub único de toques/ratón. Escucha con prioridad alta para poder "consumir" toques antes que Flixel. */
class Pointers
{
	public static var active:Map<Int, Ptr> = new Map();

	static var entries:Array<Entry> = [];
	static var inited:Bool = false;
	static var lastTouch:Float = -1000;
	static var lastConsumed:Float = -1000;

	public static function init():Void
	{
		if (inited) return;
		inited = true;
		var st = Lib.current.stage;
		st.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 1000);
		st.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, false, 1000);
		st.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 1000);
		st.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin, false, 1000);
		st.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove, false, 1000);
		st.addEventListener(TouchEvent.TOUCH_END, onTouchEnd, false, 1000);
		st.addEventListener(Event.DEACTIVATE, onDeactivate, false, 1000);
	}

	public static function add(l:PointerListener, prio:Int):Void
	{
		remove(l);
		entries.push({ l: l, prio: prio });
		entries.sort((a, b) -> b.prio - a.prio);
	}

	public static function remove(l:PointerListener):Void
	{
		entries = entries.filter(e -> e.l != l);
	}

	// ---------- núcleo ----------

	static function down(id:Int, x:Float, y:Float, e:Event):Void
	{
		var p:Ptr = { id: id, x: x, y: y, sx: x, sy: y, owner: null, moved: false };
		active.set(id, p);
		for (en in entries.copy())
		{
			if (en.l.onPointerDown(p))
			{
				p.owner = en.l;
				lastConsumed = Timer.stamp();
				e.stopImmediatePropagation();
				return;
			}
		}
	}

	static function move(id:Int, x:Float, y:Float, e:Event):Void
	{
		var p = active.get(id);
		if (p == null) return;
		p.x = x;
		p.y = y;
		if (!p.moved && Math.abs(x - p.sx) + Math.abs(y - p.sy) > 14 * Kit.s()) p.moved = true;
		if (p.owner != null)
		{
			p.owner.onPointerMove(p);
			lastConsumed = Timer.stamp();
			e.stopImmediatePropagation();
		}
	}

	static function up(id:Int, x:Float, y:Float, e:Event):Void
	{
		var p = active.get(id);
		if (p == null) return;
		active.remove(id);
		p.x = x;
		p.y = y;
		if (p.owner != null)
		{
			p.owner.onPointerUp(p);
			lastConsumed = Timer.stamp();
			e.stopImmediatePropagation();
		}
	}

	static function onDeactivate(_:Event):Void
	{
		for (p in active)
		{
			active.remove(p.id);
			if (p.owner != null) p.owner.onPointerUp(p);
		}
	}

	// ---------- toque ----------

	static function onTouchBegin(e:TouchEvent):Void { lastTouch = Timer.stamp(); down(e.touchPointID, e.stageX, e.stageY, e); }
	static function onTouchMove(e:TouchEvent):Void { lastTouch = Timer.stamp(); move(e.touchPointID, e.stageX, e.stageY, e); }
	static function onTouchEnd(e:TouchEvent):Void { lastTouch = Timer.stamp(); up(e.touchPointID, e.stageX, e.stageY, e); }

	// ---------- ratón (también es el "ratón emulado" del toque principal en Android) ----------

	static function emulated(e:MouseEvent):Bool
	{
		if (Timer.stamp() - lastTouch < 1.0)
		{
			var anyOwned = false;
			for (p in active) if (p.owner != null) anyOwned = true;
			if (anyOwned || Timer.stamp() - lastConsumed < 0.6) e.stopImmediatePropagation();
			return true;
		}
		return false;
	}

	static function onMouseDown(e:MouseEvent):Void { if (!emulated(e)) down(-1, e.stageX, e.stageY, e); }
	static function onMouseMove(e:MouseEvent):Void { if (!emulated(e)) move(-1, e.stageX, e.stageY, e); }
	static function onMouseUp(e:MouseEvent):Void { if (!emulated(e)) up(-1, e.stageX, e.stageY, e); }
}
