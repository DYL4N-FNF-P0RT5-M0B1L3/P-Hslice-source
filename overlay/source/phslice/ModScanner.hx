package phslice;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef ModInfo = { name:String, kind:String, enabled:Bool };

/** Lista los mods de .P-Hslice/mods y activa/desactiva (modsList.txt, formato de Psych). */
class ModScanner
{
	public static function scan():Array<ModInfo>
	{
		var out:Array<ModInfo> = [];
		#if sys
		var dir = ModPaths.modsDir();
		try
		{
			if (!FileSystem.exists(dir)) return out;
			var enabled = readList();
			for (n in FileSystem.readDirectory(dir))
			{
				var p = dir + n;
				if (n.startsWith(".") || !FileSystem.isDirectory(p)) continue;
				var kind = "Psych";
				if (FileSystem.exists(p + "/_polymod_meta.json")) kind = "V-Slice";
				else if (FileSystem.exists(p + "/pack.json") || FileSystem.exists(p + "/weeks") || FileSystem.exists(p + "/data")) kind = "Psych";
				else kind = "?";
				out.push({ name: n, kind: kind, enabled: enabled.exists(n) ? enabled.get(n) : true });
			}
		}
		catch (e:Dynamic) {}
		out.sort((a, b) -> a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1);
		#end
		return out;
	}

	public static function setEnabled(name:String, on:Bool):Void
	{
		#if sys
		var all = scan();
		var sb = new StringBuf();
		for (m in all)
			sb.add(m.name + "|" + ((m.name == name ? on : m.enabled) ? "1" : "0") + "\n");
		try { File.saveContent(ModPaths.root() + "modsList.txt", sb.toString()); } catch (e:Dynamic) {}
		#end
	}

	static function readList():Map<String, Bool>
	{
		var m = new Map<String, Bool>();
		#if sys
		var f = ModPaths.root() + "modsList.txt";
		try
		{
			if (FileSystem.exists(f))
				for (line in File.getContent(f).split("\n"))
				{
					var parts = line.trim().split("|");
					if (parts.length >= 2) m.set(parts[0], parts[1] == "1");
				}
		}
		catch (e:Dynamic) {}
		#end
		return m;
	}
}
