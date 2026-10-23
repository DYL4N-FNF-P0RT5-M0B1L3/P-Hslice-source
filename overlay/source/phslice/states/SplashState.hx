package phslice.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.Assets;
import phslice.ui.Menu;

/**
 * Animaciones de entrada:
 *   1) imagen 1 + "DYLAN-FNF-PORTS-MOBILE"
 *   2) imagen 2 + "DF' -PM -Projects"
 * y luego entrega el control al estado original de P-Slice. Tocar la pantalla salta la animación.
 */
class SplashState extends FlxState
{
	static inline var IMG1:String = "assets/shared/images/phslice/logo_dylan.png";
	static inline var IMG2:String = "assets/shared/images/phslice/logo_dfpm.png";

	var phase:Int = 0; // 0 permiso, 1 anim 1, 2 anim 2, 3 saliendo
	var layer1:FlxGroup;
	var layer2:FlxGroup;
	var logo1:FlxSprite;
	var logo2:FlxSprite;
	var txt1:FlxText;
	var txt2:FlxText;
	var base1:Float = 1;
	var permAcc:Float = 0;

	override function create():Void
	{
		super.create();
		PHSlice.start();
		FlxG.mouse.visible = false;
		FlxG.camera.bgColor = FlxColor.BLACK;
		buildAnim1();
		buildAnim2();
		if (PHSlice.needsStoragePrompt()) showPermissionMenu();
		else startAnim1();
	}

	// ---------- permiso de almacenamiento (solo Android, una vez) ----------

	function showPermissionMenu():Void
	{
		phase = 0;
		Menu.open("Permiso de almacenamiento", () -> [
			{ text: () -> "Para guardar tus mods en la carpeta pública .P-Hslice, Android necesita el permiso \"Acceso a todos los archivos\".", header: true },
			{ text: () -> "Conceder permiso", sub: () -> Native.hasAllFiles() ? "CONCEDIDO" : "pendiente", tap: () -> Native.requestAllFiles() },
			{ text: () -> "Continuar sin permiso (carpeta interna de la app)", tap: () ->
				{
					Config.askedStorage = true;
					Config.flush();
					Menu.closeAll();
				} },
			{ text: () -> "Podrás conceder el permiso más tarde desde Opciones > Mods.", header: true }
		], () -> if (phase == 0) startAnim1(), 0.5);
	}

	// ---------- construcción ----------

	function font():String
		return Assets.exists("assets/fonts/vcr.ttf") ? "assets/fonts/vcr.ttf" : null;

	function makeText(text:String, size:Int, color:FlxColor, border:FlxColor):FlxText
	{
		var t = new FlxText(0, 0, FlxG.width, text, size);
		t.setFormat(font(), size, color, CENTER, OUTLINE, border);
		t.borderSize = 3;
		return t;
	}

	function fit(s:FlxSprite, h:Float):Void
	{
		s.setGraphicSize(0, Std.int(h));
		s.updateHitbox();
	}

	function buildAnim1():Void
	{
		layer1 = new FlxGroup();
		add(layer1);
		logo1 = new FlxSprite(0, 0, IMG1);
		logo1.antialiasing = true;
		fit(logo1, FlxG.height * 0.56);
		logo1.screenCenter();
		logo1.y -= 46;
		logo1.alpha = 0;
		base1 = logo1.scale.x;
		txt1 = makeText(PHSlice.SPLASH_TEXT_1, 44, FlxColor.WHITE, 0xFF6B4FD1);
		txt1.y = logo1.y + logo1.height + 10;
		txt1.text = "";
		layer1.add(logo1);
		layer1.add(txt1);
	}

	function buildAnim2():Void
	{
		layer2 = new FlxGroup();
		layer2.visible = false;
		add(layer2);
		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFFFCF104);
		logo2 = new FlxSprite(0, 0, IMG2);
		logo2.antialiasing = true;
		fit(logo2, FlxG.height * 0.62);
		logo2.screenCenter();
		logo2.y -= 34;
		txt2 = makeText(PHSlice.SPLASH_TEXT_2, 46, 0xFFFF1A2B, 0xFF4B22D6);
		txt2.y = logo2.y + logo2.height + 4;
		layer2.add(bg);
		layer2.add(logo2);
		layer2.add(txt2);
	}

	// ---------- animación 1 ----------

	function startAnim1():Void
	{
		phase = 1;
		FlxTween.tween(logo1, {alpha: 1}, 0.35);
		logo1.scale.set(base1 * 0.35, base1 * 0.35);
		FlxTween.tween(logo1.scale, {x: base1, y: base1}, 0.9, {ease: FlxEase.elasticOut});
		new FlxTimer().start(0.6, function(_)
		{
			if (phase != 1) return;
			var full = PHSlice.SPLASH_TEXT_1;
			new FlxTimer().start(0.045, function(t:FlxTimer)
			{
				if (phase == 1) txt1.text = full.substr(0, t.elapsedLoops);
			}, full.length);
		});
		new FlxTimer().start(2.9, function(_)
		{
			if (phase == 1) fadeOut(layer1, startAnim2);
		});
	}

	function fadeOut(g:FlxGroup, then:Void->Void):Void
	{
		for (m in g.members)
			if (m != null) FlxTween.tween(cast(m, FlxSprite), {alpha: 0}, 0.4);
		new FlxTimer().start(0.45, function(_) then());
	}

	// ---------- animación 2 ----------

	function startAnim2():Void
	{
		if (phase >= 2) return;
		phase = 2;
		FlxTimer.globalManager.clear();
		FlxTween.globalManager.clear();
		layer1.visible = false;
		layer2.visible = true;
		var targetY = logo2.y;
		logo2.y = targetY + 320;
		logo2.alpha = 0;
		logo2.angle = -10;
		FlxTween.tween(logo2, {y: targetY, alpha: 1}, 0.8, {ease: FlxEase.backOut});
		FlxTween.tween(logo2, {angle: 0}, 1.0, {ease: FlxEase.elasticOut});
		txt2.scale.set(0, 0);
		new FlxTimer().start(0.5, function(_)
		{
			FlxTween.tween(txt2.scale, {x: 1, y: 1}, 0.7, {ease: FlxEase.elasticOut});
		});
		new FlxTimer().start(3.0, function(_) finish());
	}

	function finish():Void
	{
		if (phase == 3) return;
		phase = 3;
		FlxG.camera.fade(FlxColor.BLACK, 0.3, false, function()
		{
			PHSlice.handOff();
			FlxG.switchState(BootTarget.create());
		});
	}

	// ---------- bucle ----------

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (phase == 0)
		{
			permAcc += elapsed;
			if (permAcc > 0.5)
			{
				permAcc = 0;
				if (Native.hasAllFiles())
				{
					ModPaths.reset();
					ModPaths.apply();
					Config.askedStorage = true;
					Config.flush();
					Menu.closeAll();
				}
			}
			return;
		}
		if (tapped())
		{
			if (phase == 1)
			{
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				startAnim2();
			}
			else if (phase == 2) finish();
		}
	}

	function tapped():Bool
	{
		if (FlxG.mouse.justPressed) return true;
		#if FLX_TOUCH
		for (t in FlxG.touches.list)
			if (t.justPressed) return true;
		#end
		return false;
	}
}
