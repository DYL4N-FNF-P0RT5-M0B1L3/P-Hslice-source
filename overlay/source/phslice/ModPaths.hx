package phslice;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Carpeta de datos de P-Hslice.
 *   Android (con "Acceso a todos los archivos"): /storage/emulated/0/.P-Hslice/
 *   Android (sin permiso):                       Android/data/<paquete>/files/.P-Hslice/
 *   Escritorio (pruebas):                        carpeta actual
 * Los mods van en  <root>/mods/
 */
class ModPaths
{
	static var _root:String = null;
	public static var usingPublic(default, null):Bool = false;
	public static var lastError:String = "";

	public static function reset():Void
	{
		_root = null;
	}

	/** Ruta raíz con "/" al final. */
	public static function root():String
	{
		if (_root != null) return _root;
		#if android
		var pub = Native.externalRoot() + "/" + PHSlice.FOLDER + "/";
		if (tryDir(pub))
		{
			_root = pub;
			usingPublic = true;
		}
		else
		{
			var priv = Native.appFilesDir() + "/" + PHSlice.FOLDER + "/";
			tryDir(priv);
			_root = priv;
			usingPublic = false;
		}
		#elseif sys
		_root = Sys.getCwd();
		usingPublic = true;
		#else
		_root = "";
		#end
		return _root;
	}

	public static function modsDir():String
		return root() + "mods/";

	/** Crea carpetas y apunta el directorio de trabajo del juego a .P-Hslice. */
	public static function apply():Void
	{
		#if sys
		var r = root();
		try
		{
			if (!FileSystem.exists(r)) FileSystem.createDirectory(r);
			var m = modsDir();
			if (!FileSystem.exists(m)) FileSystem.createDirectory(m);
			var readme = m + "LEEME.txt";
			if (!FileSystem.exists(readme))
				File.saveContent(readme, "Pon aqui tus mods (una carpeta por mod).\nTambien puedes importar .zip desde el menu lateral del juego.\n");
			#if android
			Sys.setCwd(r);
			#end
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
		}
		#end
	}

	static function tryDir(p:String):Bool
	{
		#if sys
		try
		{
			if (!FileSystem.exists(p)) FileSystem.createDirectory(p);
			var t = p + ".phslice_test";
			File.saveContent(t, "ok");
			FileSystem.deleteFile(t);
			return true;
		}
		catch (e:Dynamic)
		{
			lastError = Std.string(e);
		}
		#end
		return false;
	}
}
