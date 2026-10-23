package phslice.ui;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.geom.Rectangle;
import phslice.ui.Pointers.PointerListener;
import phslice.ui.Pointers.Ptr;

typedef Item = {
	var text:Void->String;
	@:optional var sub:Void->String;
	@:optional var tap:Void->Void;
	@:optional var header:Bool;
}

private typedef Page = { title:String, items:Void->Array<Item>, refresh:Float };
private typedef Geom = { y:Float, h:Float, item:Item };

/** Menú modal táctil (lista con scroll por arrastre, páginas apiladas, botón Volver). */
class Menu extends Sprite implements PointerListener
{
	static var _inst:Menu;
	public static var isOpen(get, never):Bool;

	static function get_isOpen():Bool
		return _inst != null && _inst.opened;

	static function inst():Menu
	{
		if (_inst == null) _inst = new Menu();
		return _inst;
	}

	/** Abre un menú nuevo. onClose se llama al cerrar todo. refresh = segundos entre actualizaciones (0 = solo al tocar). */
	public static function open(title:String, items:Void->Array<Item>, ?onClose:Void->Void, refresh:Float = 0):Void
	{
		var m = inst();
		if (m.opened) m.closeAll();
		m.stack = [{ title: title, items: items, refresh: refresh }];
		m.onClose = onClose;
		m.show();
	}

	public static function push(title:String, items:Void->Array<Item>, refresh:Float = 0):Void
	{
		var m = inst();
		m.stack.push({ title: title, items: items, refresh: refresh });
		m.scrollY = 0;
		m.rebuild();
	}

	public static function back():Void
	{
		if (isOpen) _inst.goBack();
	}

	public static function closeAll():Void
	{
		if (isOpen) _inst.closeAllInternal();
	}

	public static function tick(dt:Float):Void
	{
		if (!isOpen) return;
		var m = _inst;
		var pg = m.stack[m.stack.length - 1];
		if (pg.refresh > 0)
		{
			m.acc += dt;
			if (m.acc >= pg.refresh)
			{
				m.acc = 0;
				if (!m.scrolling) m.rebuild();
			}
		}
	}

	// ---------- instancia ----------

	var opened:Bool = false;
	var stack:Array<Page> = [];
	var onClose:Void->Void;
	var acc:Float = 0;
	var scrollY:Float = 0;
	var maxScroll:Float = 0;
	var dragStartScroll:Float = 0;
	var scrolling:Bool = false;
	var content:Sprite;
	var geoms:Array<Geom> = [];
	var listL:Float;
	var listT:Float;
	var listW:Float;
	var listH:Float;
	var backR:Rectangle;
	var listenersOn:Bool = false;

	function new()
	{
		super();
	}

	function show():Void
	{
		opened = true;
		scrollY = 0;
		acc = 0;
		var st = Lib.current.stage;
		if (!listenersOn)
		{
			listenersOn = true;
			st.addEventListener(KeyboardEvent.KEY_DOWN, onKey, false, 1000);
			st.addEventListener(Event.RESIZE, onResize);
		}
		Pointers.add(this, 100);
		st.addChild(this);
		rebuild();
	}

	function onKey(e:KeyboardEvent):Void
	{
		if (!opened) return;
		if (e.keyCode == 27 || e.keyCode == 0x01000016) // ESC / botón Atrás de Android
		{
			e.stopImmediatePropagation();
			goBack();
		}
	}

	function onResize(_:Event):Void
	{
		if (opened) rebuild();
	}

	function goBack():Void
	{
		stack.pop();
		if (stack.length == 0) closeAllInternal();
		else
		{
			scrollY = 0;
			rebuild();
		}
	}

	function closeAllInternal():Void
	{
		opened = false;
		stack = [];
		Pointers.remove(this);
		if (parent != null) parent.removeChild(this);
		var cb = onClose;
		onClose = null;
		if (cb != null) cb();
		if (Drawer.instance != null) Drawer.instance.refreshVisibility();
	}

	function rebuild():Void
	{
		if (!opened || stack.length == 0) return;
		removeChildren();
		graphics.clear();
		geoms = [];
		var s = Kit.s();
		var W = Kit.sw();
		var H = Kit.sh();
		Kit.rect(graphics, 0, 0, W, H, 0x000000, 0.68);

		var pw = Math.min(W * 0.92, 980 * s);
		var ph = H * 0.92;
		var px = (W - pw) / 2;
		var py = (H - ph) / 2;
		var panel = new Sprite();
		Kit.rect(panel.graphics, px, py, pw, ph, Kit.PANEL, 1, 18 * s);
		panel.graphics.lineStyle(3 * s, Kit.ACCENT, 1);
		panel.graphics.drawRoundRect(px, py, pw, ph, 36 * s, 36 * s);
		addChild(panel);

		var page = stack[stack.length - 1];
		backR = new Rectangle(px + 16 * s, py + 14 * s, 170 * s, 54 * s);
		Kit.rect(panel.graphics, backR.x, backR.y, backR.width, backR.height, Kit.ROW_HI, 1, 12 * s);
		var bt = Kit.label(stack.length > 1 ? "< Volver" : "< Cerrar", 24 * s, Kit.TEXT, true);
		bt.x = backR.x + (backR.width - bt.width) / 2;
		bt.y = backR.y + (backR.height - bt.height) / 2;
		addChild(bt);
		var tt = Kit.label(page.title, 30 * s, Kit.TEXT, true);
		tt.x = backR.right + 22 * s;
		tt.y = py + 18 * s;
		addChild(tt);

		listL = px + 16 * s;
		listT = py + 88 * s;
		listW = pw - 32 * s;
		listH = ph - 88 * s - 16 * s;

		content = new Sprite();
		var cy = 0.0;
		for (it in page.items())
		{
			if (it.header == true)
			{
				var tf = Kit.label(it.text(), 20 * s, Kit.DIM, false, null, listW - 24 * s);
				tf.x = 12 * s;
				tf.y = cy + 6 * s;
				content.addChild(tf);
				cy += tf.height + 16 * s;
				continue;
			}
			var rh = 66 * s;
			var tappable = it.tap != null;
			Kit.rect(content.graphics, 0, cy, listW, rh, tappable ? Kit.ROW : 0x1B1527, 1, 12 * s);
			var lt = Kit.label(it.text(), 26 * s, Kit.TEXT, true);
			lt.x = 18 * s;
			lt.y = cy + (rh - lt.height) / 2;
			content.addChild(lt);
			if (it.sub != null)
			{
				var st = Kit.label(it.sub(), 22 * s, Kit.DIM);
				st.x = listW - st.width - 18 * s;
				st.y = cy + (rh - st.height) / 2;
				content.addChild(st);
			}
			geoms.push({ y: cy, h: rh, item: it });
			cy += rh + 10 * s;
		}
		maxScroll = Math.max(0, cy - listH);
		scrollY = Kit.clamp(scrollY, 0, maxScroll);
		content.x = listL;
		content.y = listT;
		content.scrollRect = new Rectangle(0, scrollY, listW, listH);
		addChild(content);
	}

	function applyScroll():Void
	{
		if (content != null) content.scrollRect = new Rectangle(0, scrollY, listW, listH);
	}

	function inList(x:Float, y:Float):Bool
		return x >= listL && x <= listL + listW && y >= listT && y <= listT + listH;

	// ---------- toques ----------

	public function onPointerDown(p:Ptr):Bool
	{
		if (!opened) return false;
		dragStartScroll = scrollY;
		scrolling = inList(p.x, p.y);
		return true;
	}

	public function onPointerMove(p:Ptr):Void
	{
		if (scrolling && p.moved)
		{
			scrollY = Kit.clamp(dragStartScroll - (p.y - p.sy), 0, maxScroll);
			applyScroll();
		}
	}

	public function onPointerUp(p:Ptr):Void
	{
		var wasScrolling = scrolling;
		scrolling = false;
		if (p.moved || !opened) return;
		if (backR != null && backR.contains(p.x, p.y))
		{
			goBack();
			return;
		}
		if (wasScrolling)
		{
			var yy = p.y - listT + scrollY;
			for (g in geoms)
			{
				if (yy >= g.y && yy <= g.y + g.h)
				{
					if (g.item.tap != null)
					{
						g.item.tap();
						if (opened) rebuild();
					}
					break;
				}
			}
		}
	}
}
