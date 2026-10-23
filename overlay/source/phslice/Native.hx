package phslice;

import flixel.FlxG;
#if android
import lime.system.JNI;
#end

typedef Archive = { path:String, name:String, size:Float };

/** Funciones nativas de Android (JNI -> PHSliceNative.java). En otras plataformas son stubs. */
class Native
{
	#if android
	static inline var CLS:String = "org/dfpm/phslice/PHSliceNative";
	static var cache:Map<String, Dynamic> = new Map();

	static function fn(name:String, sig:String):Dynamic
	{
		var key = name + sig;
		if (cache.exists(key)) return cache.get(key);
		var f:Dynamic = null;
		try { f = JNI.createStaticMethod(CLS, name, sig); }
		catch (e:Dynamic) { trace('[P-Hslice] JNI $name falló: $e'); }
		cache.set(key, f);
		return f;
	}
	#end

	/** Audio capturable (grabación / directo) + detección de grabación. */
	public static function init():Void
	{
		#if android
		var f = fn("init", "()V");
		if (f != null) try { f(); } catch (e:Dynamic) {}
		#end
	}

	/** true si hay grabación de pantalla (Android 15+) o grabación de audio activa en el sistema. */
	public static function isBroadcasting():Bool
	{
		#if android
		var f = fn("isBroadcasting", "()Z");
		if (f != null) try { return f() == true; } catch (e:Dynamic) {}
		#end
		return false;
	}

	/** Abre una URL en Chrome (o en el navegador por defecto si no hay Chrome). */
	public static function openUrl(url:String):Void
	{
		#if android
		var f = fn("openUrl", "(Ljava/lang/String;)V");
		if (f != null)
		{
			try { f(url); return; } catch (e:Dynamic) {}
		}
		#end
		FlxG.openURL(url);
	}

	public static function hasAllFiles():Bool
	{
		#if android
		var f = fn("hasAllFilesAccess", "()Z");
		if (f != null) try { return f() == true; } catch (e:Dynamic) {}
		return false;
		#else
		return true;
		#end
	}

	public static function requestAllFiles():Void
	{
		#if android
		var f = fn("requestAllFiles", "()V");
		if (f != null) try { f(); } catch (e:Dynamic) {}
		#end
	}

	public static function externalRoot():String
		return str("externalRoot");

	public static function appFilesDir():String
		return str("appFilesDir");

	static function str(name:String):String
	{
		#if android
		var f = fn(name, "()Ljava/lang/String;");
		if (f != null)
		{
			try { var r:Dynamic = f(); return r == null ? "" : Std.string(r); } catch (e:Dynamic) {}
		}
		#end
		return "";
	}

	/** Archivos .zip/.7z/.rar de la carpeta Descargas (los más nuevos primero). */
	public static function listArchives():Array<Archive>
	{
		var out:Array<Archive> = [];
		var raw = str("listArchives");
		for (line in raw.split("\n"))
		{
			if (line.length == 0) continue;
			var parts = line.split("\t");
			if (parts.length < 2) continue;
			var p = parts[0];
			var slash = p.lastIndexOf("/");
			out.push({ path: p, name: slash >= 0 ? p.substr(slash + 1) : p, size: Std.parseFloat(parts[1]) });
		}
		return out;
	}

	public static function startUnzip(zipPath:String, destDir:String):Void
	{
		#if android
		var f = fn("startUnzip", "(Ljava/lang/String;Ljava/lang/String;)V");
		if (f != null) try { f(zipPath, destDir); } catch (e:Dynamic) {}
		#end
	}

	/** "idle" | "running:NN" | "done:NombreMod" | "error:mensaje" */
	public static function unzipStatus():String
	{
		var s = str("unzipStatus");
		return s == "" ? "idle" : s;
	}

	public static function toast(msg:String):Void
	{
		#if android
		var f = fn("toast", "(Ljava/lang/String;)V");
		if (f != null) try { f(msg); } catch (e:Dynamic) {}
		#end
	}

	public static function vibrate(ms:Int):Void
	{
		#if android
		var f = fn("vibrate", "(I)V");
		if (f != null) try { f(ms); } catch (e:Dynamic) {}
		#end
	}
}
