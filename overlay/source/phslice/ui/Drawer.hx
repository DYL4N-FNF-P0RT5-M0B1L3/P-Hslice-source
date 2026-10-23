package phslice.ui;

import openfl.Lib;
import openfl.display.Sprite;
import phslice.ui.Pointers.PointerListener;
import phslice.ui.Pointers.Ptr;

private typedef Btn = { label:Void->String, act:Void->Void, y:Float, h:Float };

/**
 * Pestaña pequeña en el borde derecho del inicio. Al jalarla hacia la izquierda se abre un panel con:
 * abrir Chrome en GameBanana, importar mods, mis mods, modo patata y opciones de P-Hslice.
 */
class Drawer extends Sprite implements PointerListener
{
	public static var instance:Drawer;

	public static function init():Void
	{
		if (instance != null) return;
		instance = new Drawer();
		Lib.current.stage.addChild(instance);
		Pointers.add(instance, 50);
		instance.visible = false;
	}

	var veil:Sprite;
	var box:Sprite;
	var openAmt:Float = 0;
	var target:Float = 0;
	var dragging:Bool = false;
	var dragStartOpen:Float = 0;
	var downOnHandle:Bool = false;
	var handleW:Float;
	var handleH:Float;
	var handleY:Float;
	var panelW:Float;
	var panelY:Float;
	var panelH:Float;
	var btns:Array<Btn> = [];
	var relabel:Float = 0;
	var lastW:Float = 0;
	var lastH:Float = 0;

	function new()
	{
		super();
		veil = new Sprite();
		box = new Sprite();
		addChild(veil);
		addChild(box);
	}

	public function refreshVisibility():Void
	{
		var show = PHSlice.drawerAllowed() && !Menu.isOpen && !TouchControls.editing;
		if (!show)
		{
			openAmt = target = 0;
			dragging = false;
		}
		visible = show;
		if (show) build();
	}

	function build():Void
	{
		var s = Kit.s();
		var W = Kit.sw();
		var H = Kit.sh();
		lastW = W;
		lastH = H;
		handleW = 26 * s;
		handleH = 120 * s;
		handleY = (H - handleH) / 2;
		panelW = Math.min(W * 0.46, 470 * s);
		panelY = H * 0.08;
		panelH = H * 0.84;

		veil.graphics.clear();
		Kit.rect(veil.graphics, 0, 0, W, H, 0x000000, 1);
		box.removeChildren();
		box.graphics.clear();

		// pestaña
		Kit.rect(box.graphics, 0, handleY, handleW + 6 * s, handleH, Kit.ACCENT, 0.92, 12 * s);
		for (i in 0...3) Kit.rect(box.graphics, 8 * s, handleY + 38 * s + i * 14 * s, 10 * s, 4 * s, 0xFFFFFF, 0.9, 2 * s);

		// panel
		var px = handleW;
		Kit.rect(box.graphics, px, panelY, panelW, panelH, Kit.PANEL, 0.97, 16 * s);
		box.graphics.lineStyle(3 * s, Kit.ACCENT, 1);
		box.graphics.drawRoundRect(px, panelY, panelW, panelH, 32 * s, 32 * s);
		box.graphics.lineStyle();

		var title = Kit.label(PHSlice.APP_NAME, 32 * s, Kit.TEXT, true);
		title.x = px + 20 * s;
		title.y = panelY + 14 * s;
		box.addChild(title);
		var eng = Kit.label("Motor: " + Engines.current().name, 20 * s, Kit.DIM);
		eng.x = px + 22 * s;
		eng.y = panelY + 56 * s;
		box.addChild(eng);

		btns = [
			{ label: () -> "Abrir Chrome > GameBanana", act: () ->
				{
					Native.openUrl(PHSlice.URL_GAMEBANANA);
					Toast.show("Descarga el .zip y vuelve: Importar mods");
				}, y: 0, h: 0 },
			{ label: () -> "Importar mods descargados", act: () -> { target = 0; Menu.open("Importar mods", Pages.importer, null, 0.6); }, y: 0, h: 0 },
			{ label: () -> "Mis mods", act: () -> { target = 0; Menu.open("Mods", Pages.mods, null, 1.0); }, y: 0, h: 0 },
			{ label: () -> "Modo patata: " + (PotatoMode.wanted() ? "ON" : "OFF"), act: () -> PotatoMode.setManual(!PotatoMode.manual()), y: 0, h: 0 },
			{ label: () -> "Opciones P-Hslice", act: () -> { target = 0; Menu.open("P-Hslice", Pages.root); }, y: 0, h: 0 }
		];
		var by = panelY + 96 * s;
		var bh = 68 * s;
		for (b in btns)
		{
			b.y = by;
			b.h = bh;
			Kit.rect(box.graphics, px + 14 * s, by, panelW - 28 * s, bh, Kit.ROW, 1, 12 * s);
			var t = Kit.label(b.label(), 23 * s, Kit.TEXT, true);
			t.x = px + 28 * s;
			t.y = by + (bh - t.height) / 2;
			box.addChild(t);
			by += bh + 12 * s;
		}
		var path = Kit.label("Mods: " + ModPaths.modsDir(), 15 * s, Kit.DIM, false, null, panelW - 36 * s);
		path.x = px + 18 * s;
		path.y = panelY + panelH - path.height - 12 * s;
		box.addChild(path);
		place();
	}

	function place():Void
	{
		box.x = Kit.sw() - handleW - openAmt * panelW;
		veil.alpha = openAmt * 0.5;
	}

	public function tick(dt:Float):Void
	{
		if (!visible) return;
		if (lastW != Kit.sw() || lastH != Kit.sh()) build();
		if (!dragging)
		{
			openAmt += (target - openAmt) * Math.min(1, dt * 14);
			if (Math.abs(target - openAmt) < 0.01) openAmt = target;
		}
		place();
		if (openAmt > 0.3)
		{
			relabel += dt;
			if (relabel > 0.5)
			{
				relabel = 0;
				build();
			}
		}
		else relabel = 0;
	}

	// ---------- toques ----------

	public function onPointerDown(p:Ptr):Bool
	{
		if (!visible || Menu.isOpen) return false;
		var s = Kit.s();
		var hx = box.x;
		var onHandle = p.x >= hx - 14 * s && p.x <= hx + handleW + 10 * s && p.y >= handleY - 10 * s && p.y <= handleY + handleH + 10 * s;
		var onPanel = openAmt > 0.02 && p.x >= hx + handleW && p.y >= panelY && p.y <= panelY + panelH;
		if (onHandle || onPanel)
		{
			dragging = false;
			dragStartOpen = openAmt;
			downOnHandle = onHandle;
			return true;
		}
		if (openAmt > 0.5)
		{
			target = 0;
			return true;
		}
		return false;
	}

	public function onPointerMove(p:Ptr):Void
	{
		if (p.moved)
		{
			dragging = true;
			openAmt = Kit.clamp(dragStartOpen + (p.sx - p.x) / panelW, 0, 1);
			place();
		}
	}

	public function onPointerUp(p:Ptr):Void
	{
		if (p.moved)
		{
			dragging = false;
			target = openAmt > 0.5 ? 1 : 0;
			return;
		}
		dragging = false;
		if (downOnHandle)
		{
			target = openAmt > 0.5 ? 0 : 1;
			return;
		}
		for (b in btns)
		{
			if (p.y >= b.y && p.y <= b.y + b.h)
			{
				b.act();
				build();
				break;
			}
		}
	}
}
