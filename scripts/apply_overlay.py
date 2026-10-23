#!/usr/bin/env python3
"""
Aplica la capa P-Hslice sobre una copia de P-Slice (Psych Engine + V-Slice).

  python3 scripts/apply_overlay.py --target pslice

1) Copia overlay/ (código, assets, ícono, Java, llave de firma) dentro de P-Slice.
2) Parchea unos pocos archivos de P-Slice con inserciones pequeñas e idempotentes (marca [PHSLICE]).
   Los parches CRITICOS (Project.xml, Main.hx) hacen fallar el build si no se pueden aplicar.
   Los demás son opcionales: si no encuentran su ancla se avisa y P-Hslice sigue funcionando
   (el README explica cómo aplicarlos a mano).
"""
import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OVERLAY = ROOT / "overlay"
MARK = "[PHSLICE]"
report = []
critical_failed = False


def ok(name, detail=""):
    report.append(("OK   ", name, detail))


def skip(name, detail):
    report.append(("AVISO", name, detail))


def fail(name, detail):
    global critical_failed
    critical_failed = True
    report.append(("ERROR", name, detail))


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, s):
    p.write_text(s, encoding="utf-8", newline="\n")


def find_one(target, pattern):
    hits = sorted((target / "source").glob(pattern))
    return hits[0] if hits else None


# ----------------------------------------------------------------- 1. copiar overlay
def copy_overlay(t):
    shutil.copytree(OVERLAY / "source", t / "source", dirs_exist_ok=True)
    shutil.copytree(OVERLAY / "assets", t / "assets", dirs_exist_ok=True)
    (t / "art").mkdir(exist_ok=True)
    shutil.copytree(OVERLAY / "art", t / "art", dirs_exist_ok=True)
    shutil.copytree(OVERLAY / "java", t / "phslice_java", dirs_exist_ok=True)
    shutil.copy2(OVERLAY / "phslice.keystore", t / "phslice.keystore")
    ok("overlay copiado", "source/phslice, assets, art, phslice_java, keystore")


# ----------------------------------------------------------------- 2. Project.xml (critico)
PROJECT_BLOCK = """
	<!-- {mark} P-Hslice -->
	<haxedef name="PHSLICE" />
	<java path="phslice_java" if="android" />
	<config:android permission="android.permission.MANAGE_EXTERNAL_STORAGE" if="android" />
	<config:android permission="android.permission.READ_EXTERNAL_STORAGE" if="android" />
	<config:android permission="android.permission.WRITE_EXTERNAL_STORAGE" if="android" />
	<config:android permission="android.permission.DETECT_SCREEN_RECORDING" if="android" />
	<config:android permission="android.permission.MODIFY_AUDIO_SETTINGS" if="android" />
	<config:android permission="android.permission.VIBRATE" if="android" />
"""

CERT = ('<certificate path="phslice.keystore" password="phslice2026" alias="phslice" '
        'alias-password="phslice2026" if="android" unless="debug" />')


def set_attr(xml, attr, value):
    return re.sub(r'(<app\b[^>]*?\b%s=")[^"]*(")' % attr, r"\g<1>%s\g<2>" % value, xml, count=1)


def patch_project(t):
    p = t / "Project.xml"
    if not p.exists():
        return fail("Project.xml", "no existe")
    x = read(p)
    if MARK in x:
        return ok("Project.xml", "ya estaba parcheado")
    for attr, val in [("title", "P-Hslice"), ("file", "PHSlice"), ("packageName", "com.dfpm.phslice"),
                      ("package", "com.dfpm.phslice"), ("company", "DYLAN-FNF-PORTS-MOBILE")]:
        x = set_attr(x, attr, val)
    if re.search(r"<certificate\b[^>]*?/>", x):
        x = re.sub(r"<certificate\b[^>]*?/>", CERT, x)
    else:
        x = x.replace("</project>", "\t" + CERT + "\n</project>")
    x = x.replace("</project>", PROJECT_BLOCK.format(mark=MARK) + "</project>")
    write(p, x)
    ok("Project.xml", "nombre P-Hslice, paquete com.dfpm.phslice, permisos, Java, firma")


# ----------------------------------------------------------------- 3. Main.hx (critico)
def patch_main(t):
    p = t / "source" / "Main.hx"
    if not p.exists():
        return fail("Main.hx", "no existe source/Main.hx")
    s = read(p)
    if "phslice.states.SplashState" in s:
        return ok("Main.hx", "ya estaba parcheado")
    m = re.search(r"initialState\s*:\s*([A-Za-z_][\w\.]*)", s)
    if not m:
        return fail("Main.hx", "no encontré 'initialState:' (ver README, parche manual)")
    orig = m.group(1)
    imp = None
    if "." not in orig:
        im = re.search(r"import\s+([\w\.]+\.%s)\s*;" % re.escape(orig), s)
        if im:
            imp = im.group(1)
    s = re.sub(r"(initialState\s*:\s*)[A-Za-z_][\w\.]*", r"\g<1>phslice.states.SplashState", s)
    write(p, s)
    boot = "package phslice;\n\n"
    if imp:
        boot += "import %s;\n\n" % imp
    boot += ("/** Generado por apply_overlay.py: estado original de P-Slice ({o}). */\n"
             "class BootTarget\n{{\n\tpublic static function create():flixel.FlxState\n"
             "\t\treturn new {o}();\n}}\n").format(o=orig)
    write(t / "source" / "phslice" / "BootTarget.hx", boot)
    ok("Main.hx", "initialState %s -> SplashState (BootTarget apunta a %s)" % (orig, orig))


# ----------------------------------------------------------------- 4. opcionales
def patch_storage(t):
    p = find_one(t, "**/StorageUtil.hx")
    if not p:
        return skip("StorageUtil", "no existe; la carpeta .P-Hslice se fija igual desde SplashState (Sys.setCwd)")
    s = read(p)
    if MARK in s:
        return ok("StorageUtil", "ya parcheado")
    rx = re.compile(r"((?:public\s+)?(?:inline\s+)?static\s+(?:inline\s+)?function\s+)getStorageDirectory(\s*\(([^)]*)\)\s*:\s*String)")
    m = rx.search(s)
    if not m:
        return skip("StorageUtil", "no encontré getStorageDirectory():String")
    new = (m.group(1) + "getStorageDirectory" + m.group(2) + " return phslice.ModPaths.root(); // " + MARK + "\n\t"
           + m.group(1) + "getStorageDirectory_original" + m.group(2))
    write(p, s[:m.start()] + new + s[m.end():])
    ok("StorageUtil", "getStorageDirectory() -> .P-Hslice")


def patch_clientprefs(t):
    p = find_one(t, "**/backend/ClientPrefs.hx")
    if not p:
        return skip("ClientPrefs", "no encontrado")
    s = read(p)
    if MARK in s:
        return ok("ClientPrefs", "ya parcheado")
    m = re.search(r"class\s+SaveVariables\s*\{", s)
    if not m:
        return skip("ClientPrefs", "no encontré 'class SaveVariables {' (modo patata usará su propio guardado)")
    ins = "\n\t// %s\n\tpublic var potatoMode:Bool = false;\n" % MARK
    write(p, s[:m.end()] + ins + s[m.end():])
    ok("ClientPrefs", "opción potatoMode")


def patch_graphics(t):
    p = find_one(t, "**/GraphicsSettingsSubState.hx")
    if not p:
        return skip("Graphics", "no encontrado (usa Options > P-Hslice > Gráficos)")
    s = read(p)
    if MARK in s:
        return ok("Graphics", "ya parcheado")
    if "new Option(" not in s or "addOption(" not in s:
        return skip("Graphics", "formato distinto al de Psych")
    m = re.search(r"\n([ \t]*)super\(\);", s)
    if not m:
        return skip("Graphics", "no encontré super();")
    ind = m.group(1)
    block = ("\n%s// %s modo patata\n%svar potatoOpt:Option = new Option('Potato Mode (P-Hslice)',\n"
             "%s\t'Removes shaders and heavy mod events to prevent lag and crashes.',\n%s\t'potatoMode',\n%s\tBOOL);\n"
             "%saddOption(potatoOpt);\n") % (ind, MARK, ind, ind, ind, ind, ind)
    write(p, s[:m.start()] + block + s[m.start():])
    ok("Graphics", "opción Modo patata")


def patch_options(t):
    p = find_one(t, "**/OptionsState.hx")
    if not p:
        return skip("OptionsState", "no encontrado")
    s = read(p)
    if MARK in s or "PHSliceOptionsSubState" in s:
        return ok("OptionsState", "ya parcheado")
    a = re.search(r"(Array<String>\s*=\s*\[)", s)
    b = re.search(r"(switch\s*\(\s*label\s*\)\s*\{)", s)
    if not a or not b:
        return skip("OptionsState", "no encontré la lista de opciones o switch(label)")
    # insertar primero lo de más abajo para no mover posiciones
    first, second = (b, a) if b.start() > a.start() else (a, b)
    ins = {a: "'P-Hslice', ", b: "\n\t\t\tcase 'P-Hslice': openSubState(new phslice.options.PHSliceOptionsSubState()); // %s" % MARK}
    s = s[:first.end()] + ins[first] + s[first.end():]
    s = s[:second.end()] + ins[second] + s[second.end():]
    write(p, s)
    ok("OptionsState", "entrada 'P-Hslice' en Options")


def patch_playstate(t):
    p = find_one(t, "**/states/PlayState.hx")
    if not p:
        return skip("PlayState", "no encontrado")
    s = read(p)
    if MARK in s:
        return ok("PlayState", "ya parcheado")
    m = re.search(r"function\s+triggerEvent\s*\(\s*(\w+)\s*:\s*String[^)]*\)\s*(?::\s*Void\s*)?\{", s)
    if not m:
        return skip("PlayState", "no encontré triggerEvent(...):Void (modo patata solo quitará shaders)")
    ins = "\n\t\tif (phslice.PotatoMode.shouldSkipEvent(%s)) return; // %s" % (m.group(1), MARK)
    write(p, s[:m.end()] + ins + s[m.end():])
    ok("PlayState", "triggerEvent ignora eventos pesados en modo patata")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True, help="carpeta de P-Slice")
    t = Path(ap.parse_args().target).resolve()
    if not (t / "source").is_dir():
        sys.exit("No parece una carpeta de P-Slice: " + str(t))
    copy_overlay(t)
    patch_project(t)
    patch_main(t)
    for f in (patch_storage, patch_clientprefs, patch_graphics, patch_options, patch_playstate):
        try:
            f(t)
        except Exception as e:  # un parche opcional nunca rompe el build
            skip(f.__name__, "excepción: %s" % e)
    print("\n=== P-Hslice: resumen de parches ===")
    for st, name, detail in report:
        print("%s %-14s %s" % (st, name, detail))
    if critical_failed:
        sys.exit("\nFallaron parches críticos. Revisa el README (sección 'Parches manuales').")


if __name__ == "__main__":
    main()
