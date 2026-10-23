package phslice.ui;

import phslice.ModScanner;
import phslice.ui.Menu.Item;

/** Todas las páginas del menú P-Hslice (opciones, controles, gráficos, mods, importar). */
class Pages
{
	static var lastUnzipShown:String = "";

	static function hdr(s:Void->String):Item
		return { text: s, header: true };

	static function row(label:Void->String, ?sub:Void->String, ?tap:Void->Void):Item
		return { text: label, sub: sub, tap: tap };

	static function onoff(b:Bool):String
		return b ? "ON" : "OFF";

	static function pct(f:Float):String
		return Std.int(Math.round(f * 100)) + "%";

	static function cycle(arr:Array<Float>, cur:Float):Float
	{
		var best = 0;
		var bd = 1e9;
		for (i in 0...arr.length)
		{
			var d = Math.abs(arr[i] - cur);
			if (d < bd)
			{
				bd = d;
				best = i;
			}
		}
		return arr[(best + 1) % arr.length];
	}

	static function styleName(s:String):String
		return switch (s)
		{
			case "vslice": "V-Slice";
			case "classic": "Clásico (4 botones)";
			default: "Hitbox";
		}

	// ---------- raíz ----------

	public static function root():Array<Item>
		return [
			hdr(() -> PHSlice.APP_NAME + " " + PHSlice.VERSION + "   |   Motor: " + Engines.current().name),
			row(() -> "Motor", () -> Engines.current().name, () -> Menu.push("Motor", engines)),
			row(() -> "Controles", () -> styleName(Config.padStyle), () -> Menu.push("Controles", controls)),
			row(() -> "Gráficos / Modo patata", () -> onoff(PotatoMode.wanted()), () -> Menu.push("Gráficos", graphics, 1.0)),
			row(() -> "Mods (.P-Hslice)", null, () -> Menu.push("Mods", mods, 1.0)),
			row(() -> "Acerca de", null, () -> Menu.push("Acerca de", about)),
			row(() -> "Cerrar", null, () -> Menu.closeAll())
		];

	// ---------- motores ----------

	public static function engines():Array<Item>
	{
		var out:Array<Item> = [];
		out.push(hdr(() -> Engines.current().desc));
		for (e in Engines.list)
			out.push(row(() -> (e.id == Config.engine ? "[X] " : "[  ] ") + e.name, () -> e.short, () ->
			{
				Engines.select(e.id);
				Toast.show("Motor: " + e.name + " aplicado");
			}));
		out.push(hdr(() -> "Todos los motores usan la misma carpeta de mods. Cada perfil cambia opciones del juego (se editan en assets/shared/phslice/engines.json)."));
		return out;
	}

	// ---------- controles ----------

	static function styleRow(id:String, name:String):Item
		return row(() -> (Config.padStyle == id ? "[X] " : "[  ] ") + name, null, () -> TouchControls.setStyle(id));

	public static function controls():Array<Item>
		return [
			hdr(() -> "Elige cómo se ven y funcionan los botones durante la partida."),
			styleRow("hitbox", "Hitbox (4 zonas)"),
			styleRow("vslice", "V-Slice (4 teclas grandes)"),
			styleRow("classic", "Clásico (4 botones con flechas)"),
			row(() -> "Opacidad", () -> pct(Config.padAlpha), () ->
			{
				Config.padAlpha = cycle([0.15, 0.25, 0.35, 0.45, 0.6, 0.8, 1.0], Config.padAlpha);
				Config.flush();
				TouchControls.instance.refresh();
			}),
			row(() -> "Alto del pad (Hitbox / V-Slice)", () -> pct(Config.padHeight), () ->
			{
				Config.padHeight = cycle([0.3, 0.4, 0.5, 0.55, 0.7, 0.85, 1.0], Config.padHeight);
				Config.flush();
				TouchControls.instance.refresh();
			}),
			row(() -> "Tamaño de botones (Clásico)", () -> pct(Config.classicScale), () ->
			{
				Config.classicScale = cycle([0.7, 0.85, 1.0, 1.2, 1.4], Config.classicScale);
				Config.flush();
				TouchControls.instance.refresh();
			}),
			row(() -> "Botón de pausa", () -> onoff(Config.pauseButton), () ->
			{
				Config.pauseButton = !Config.pauseButton;
				Config.flush();
				TouchControls.instance.refresh();
			}),
			row(() -> "Vibración al tocar", () -> onoff(Config.haptics), () ->
			{
				Config.haptics = !Config.haptics;
				Config.flush();
			}),
			row(() -> "Editar posiciones (arrastrar)", null, () -> TouchControls.instance.startEditing()),
			row(() -> "Restablecer controles", null, () ->
			{
				Config.resetControls();
				TouchControls.instance.refresh();
				Toast.show("Controles restablecidos");
			}),
			hdr(() -> "Los botones envían las teclas de flechas, así que funcionan con cualquier mod. Si ves también los botones propios de P-Slice, ponles opacidad 0 en sus opciones móviles.")
		];

	// ---------- gráficos ----------

	public static function graphics():Array<Item>
		return [
			hdr(() -> "Modo patata: quita shaders y filtros y se salta eventos pesados de mods. Evita tirones y crasheos en celulares modestos."),
			row(() -> "Modo patata", () -> onoff(PotatoMode.manual()), () -> PotatoMode.setManual(!PotatoMode.manual())),
			row(() -> "Auto-patata al grabar / transmitir", () -> onoff(Config.autoPotato), () ->
			{
				Config.autoPotato = !Config.autoPotato;
				if (!Config.autoPotato) PotatoMode.autoOn = false;
				Config.flush();
				PotatoMode.refresh();
			}),
			row(() -> "Estado actual", () -> PotatoMode.active ? (PHSlice.isBroadcasting() ? "ACTIVO (grabando)" : "ACTIVO") : "apagado"),
			hdr(() -> "Eventos extra a ignorar: escribe palabras en .P-Hslice/potato_blocklist.txt (una por línea).")
		];

	// ---------- mods ----------

	public static function mods():Array<Item>
	{
		var out:Array<Item> = [];
		out.push(hdr(() -> "Carpeta de mods: " + ModPaths.modsDir()));
		if (!ModPaths.usingPublic)
			out.push(row(() -> "Dar acceso a todos los archivos", () -> "carpeta pública", () -> Native.requestAllFiles()));
		out.push(row(() -> "Abrir Chrome > GameBanana", null, () ->
		{
			Native.openUrl(PHSlice.URL_GAMEBANANA);
			Toast.show("Descarga el .zip y vuelve aquí: Importar mods");
		}));
		out.push(row(() -> "Importar mods descargados", null, () -> Menu.push("Importar mods", importer, 0.6)));
		out.push(hdr(() -> "Toca un mod para activarlo o desactivarlo (reinicia el juego para aplicar)."));
		var list = ModScanner.scan();
		if (list.length == 0) out.push(hdr(() -> "(no hay mods todavía)"));
		for (m in list)
			out.push(row(() -> (m.enabled ? "[ON]  " : "[OFF] ") + m.name, () -> m.kind, () -> ModScanner.setEnabled(m.name, !m.enabled)));
		return out;
	}

	public static function importer():Array<Item>
	{
		var out:Array<Item> = [];
		var st = Native.unzipStatus();
		if (st.indexOf("done:") == 0 && st != lastUnzipShown)
		{
			lastUnzipShown = st;
			Toast.show("Mod importado: " + st.substr(5));
		}
		if (st.indexOf("running") == 0) out.push(hdr(() -> "Importando... " + st.substr(8) + "%"));
		else if (st.indexOf("error:") == 0) out.push(hdr(() -> "Error: " + st.substr(6)));
		else if (st.indexOf("done:") == 0) out.push(hdr(() -> "Listo: " + st.substr(5)));
		out.push(hdr(() -> "Archivos de la carpeta Descargas. Solo .zip se importa solo; .7z y .rar extráelos a mano en la carpeta de mods."));
		var arch = Native.listArchives();
		if (arch.length == 0) out.push(hdr(() -> "(no hay .zip / .7z / .rar en Descargas — descarga uno desde GameBanana)"));
		for (a in arch)
		{
			var mb = Math.round(a.size / 1048576 * 10) / 10;
			var isZip = a.name.toLowerCase().indexOf(".zip") > 0;
			out.push(row(() -> a.name, () -> mb + " MB" + (isZip ? "" : "  (manual)"), () ->
			{
				if (isZip) Native.startUnzip(a.path, ModPaths.modsDir());
				else Toast.show("Formato no soportado: extráelo a mano");
			}));
		}
		return out;
	}

	// ---------- acerca de ----------

	public static function about():Array<Item>
		return [
			hdr(() -> PHSlice.APP_NAME + " " + PHSlice.VERSION + " — " + PHSlice.SPLASH_TEXT_1 + " / " + PHSlice.SPLASH_TEXT_2),
			hdr(() -> "Basado en P-Slice (Psych Engine + V-Slice). Créditos: Shadow Mario y el equipo de Psych Engine, The Funkin' Crew (Friday Night Funkin'), mikolka9144 y el equipo de P-Slice, MAJigsaw77 (extension-androidtools)."),
			hdr(() -> "Licencia del código: Apache-2.0. Los assets del juego base pertenecen a sus autores (uso no comercial)."),
			row(() -> "Página de P-Slice en GameBanana", null, () -> Native.openUrl(PHSlice.URL_PSLICE))
		];
}
