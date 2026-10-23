package org.dfpm.phslice;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.AudioRecordingConfiguration;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.Vibrator;
import android.util.Log;
import android.view.WindowManager;
import android.widget.Toast;

import org.haxe.extension.Extension;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.Executor;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/**
 * Puente JNI de P-Hslice (se llama desde phslice/Native.hx):
 *  - Audio: permite que otras apps (grabadores / OBS / directos) capturen el audio del juego y
 *    nunca pausa ni silencia el juego cuando otra app toma el foco de audio.
 *  - Detección de grabación (Android 15+: grabación de pantalla; antes: grabación de audio activa).
 *  - Abrir Chrome, permisos de almacenamiento, listar Descargas y descomprimir mods.
 */
public class PHSliceNative {
	private static final String TAG = "P-Hslice";

	private static volatile boolean screenRecording = false;
	private static volatile boolean audioRecording = false;
	private static volatile String unzipState = "idle";
	private static boolean inited = false;
	private static AudioManager.OnAudioFocusChangeListener focusListener;
	private static Object focusRequest;

	// ------------------------------------------------------------------ init

	public static void init() {
		if (inited) return;
		inited = true;
		final Activity a = Extension.mainActivity;
		if (a == null) return;
		a.runOnUiThread(new Runnable() {
			public void run() {
				try { setupAudio(a); } catch (Throwable t) { Log.w(TAG, "audio: " + t); }
				try { setupRecordingDetection(a); } catch (Throwable t) { Log.w(TAG, "deteccion: " + t); }
			}
		});
	}

	@SuppressLint("NewApi")
	private static void setupAudio(Context c) {
		AudioManager am = (AudioManager) c.getSystemService(Context.AUDIO_SERVICE);
		if (am == null) return;

		// Permite que otras apps capturen el audio de este juego (ALLOW_CAPTURE_BY_ALL = 1, API 29+).
		if (Build.VERSION.SDK_INT >= 29) {
			try {
				Method m = AudioManager.class.getMethod("setAllowedCapturePolicy", int.class);
				m.invoke(am, 1);
			} catch (Throwable t) { Log.w(TAG, "capturePolicy: " + t); }
		}

		// Foco de audio: lo pedimos como juego y IGNORAMOS cualquier pérdida de foco,
		// así el sonido del juego no se corta cuando empieza una grabación o directo.
		focusListener = new AudioManager.OnAudioFocusChangeListener() {
			public void onAudioFocusChange(int change) { /* no pausar ni silenciar */ }
		};
		if (Build.VERSION.SDK_INT >= 26) {
			AudioAttributes attrs = new AudioAttributes.Builder()
					.setUsage(AudioAttributes.USAGE_GAME)
					.setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
					.build();
			AudioFocusRequest req = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
					.setAudioAttributes(attrs)
					.setOnAudioFocusChangeListener(focusListener)
					.setWillPauseWhenDucked(false)
					.setAcceptsDelayedFocusGain(true)
					.build();
			focusRequest = req;
			am.requestAudioFocus(req);
		} else {
			am.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
		}
	}

	@SuppressLint("NewApi")
	private static void setupRecordingDetection(Activity a) {
		if (Build.VERSION.SDK_INT >= 24) {
			final AudioManager am = (AudioManager) a.getSystemService(Context.AUDIO_SERVICE);
			if (am != null) {
				am.registerAudioRecordingCallback(new AudioManager.AudioRecordingCallback() {
					@Override
					public void onRecordingConfigChanged(List<AudioRecordingConfiguration> configs) {
						audioRecording = configs != null && !configs.isEmpty();
					}
				}, new Handler(Looper.getMainLooper()));
				List<AudioRecordingConfiguration> now = am.getActiveRecordingConfigurations();
				audioRecording = now != null && !now.isEmpty();
			}
		}
		if (Build.VERSION.SDK_INT >= 35) registerScreenRecordingCallback(a);
	}

	/** Android 15+: WindowManager.addScreenRecordingCallback (por reflexión para compilar con cualquier SDK). */
	@SuppressLint("NewApi")
	private static void registerScreenRecordingCallback(Activity a) {
		try {
			WindowManager wm = (WindowManager) a.getSystemService(Context.WINDOW_SERVICE);
			Method m = WindowManager.class.getMethod("addScreenRecordingCallback", Executor.class, java.util.function.Consumer.class);
			final Handler h = new Handler(Looper.getMainLooper());
			Executor ex = new Executor() {
				public void execute(Runnable r) { h.post(r); }
			};
			java.util.function.Consumer<Integer> cb = new java.util.function.Consumer<Integer>() {
				public void accept(Integer state) { screenRecording = (state != null && state == 1); }
			};
			Object initial = m.invoke(wm, ex, cb);
			if (initial instanceof Integer) screenRecording = ((Integer) initial) == 1;
		} catch (Throwable t) {
			Log.w(TAG, "screenRecording: " + t);
		}
	}

	public static boolean isBroadcasting() {
		return screenRecording || audioRecording;
	}

	// ------------------------------------------------------------------ navegador

	public static void openUrl(final String url) {
		final Activity a = Extension.mainActivity;
		if (a == null) return;
		a.runOnUiThread(new Runnable() {
			public void run() {
				try {
					Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
					i.setPackage("com.android.chrome");
					i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
					a.startActivity(i);
				} catch (Throwable chromeMissing) {
					try {
						Intent i2 = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
						i2.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
						a.startActivity(i2);
					} catch (Throwable t) { Log.w(TAG, "openUrl: " + t); }
				}
			}
		});
	}

	// ------------------------------------------------------------------ almacenamiento

	public static String externalRoot() {
		return Environment.getExternalStorageDirectory().getAbsolutePath();
	}

	public static String appFilesDir() {
		Context c = Extension.mainContext;
		File f = c.getExternalFilesDir(null);
		return (f != null ? f : c.getFilesDir()).getAbsolutePath();
	}

	@SuppressLint("NewApi")
	public static boolean hasAllFilesAccess() {
		if (Build.VERSION.SDK_INT >= 30) {
			try {
				Method m = Environment.class.getMethod("isExternalStorageManager");
				return (Boolean) m.invoke(null);
			} catch (Throwable t) { return false; }
		}
		if (Build.VERSION.SDK_INT >= 23) {
			return Extension.mainContext.checkSelfPermission("android.permission.WRITE_EXTERNAL_STORAGE") == PackageManager.PERMISSION_GRANTED;
		}
		return true;
	}

	@SuppressLint("NewApi")
	public static void requestAllFiles() {
		final Activity a = Extension.mainActivity;
		if (a == null) return;
		a.runOnUiThread(new Runnable() {
			public void run() {
				try {
					if (Build.VERSION.SDK_INT >= 30) {
						try {
							Intent i = new Intent("android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION", Uri.parse("package:" + a.getPackageName()));
							a.startActivity(i);
						} catch (Throwable t) {
							a.startActivity(new Intent("android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION"));
						}
					} else if (Build.VERSION.SDK_INT >= 23) {
						a.requestPermissions(new String[] {
								"android.permission.READ_EXTERNAL_STORAGE",
								"android.permission.WRITE_EXTERNAL_STORAGE" }, 7777);
					}
				} catch (Throwable t) { Log.w(TAG, "requestAllFiles: " + t); }
			}
		});
	}

	/** Líneas "ruta\ttamaño" de .zip/.7z/.rar en Descargas (las más nuevas primero). */
	@SuppressWarnings("deprecation")
	public static String listArchives() {
		StringBuilder sb = new StringBuilder();
		try {
			File dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
			File[] files = dir.listFiles();
			if (files == null) return "";
			Arrays.sort(files, new Comparator<File>() {
				public int compare(File x, File y) { return Long.compare(y.lastModified(), x.lastModified()); }
			});
			int n = 0;
			for (File f : files) {
				String name = f.getName().toLowerCase(Locale.ROOT);
				if (f.isFile() && (name.endsWith(".zip") || name.endsWith(".7z") || name.endsWith(".rar"))) {
					sb.append(f.getAbsolutePath()).append('\t').append(f.length()).append('\n');
					if (++n >= 40) break;
				}
			}
		} catch (Throwable t) { Log.w(TAG, "listArchives: " + t); }
		return sb.toString();
	}

	// ------------------------------------------------------------------ descomprimir mods

	public static void startUnzip(final String zipPath, final String modsDir) {
		unzipState = "running:0";
		new Thread(new Runnable() {
			public void run() {
				try {
					String mod = unzip(zipPath, modsDir);
					unzipState = "done:" + mod;
				} catch (Throwable t) {
					unzipState = "error:" + t.getMessage();
				}
			}
		}, "PHSlice-unzip").start();
	}

	public static String unzipStatus() {
		return unzipState;
	}

	private static String sanitize(String s) {
		return s.replaceAll("[^A-Za-z0-9 _\\-\\.]", "_").trim();
	}

	private static String unzip(String zipPath, String modsDir) throws IOException {
		ZipFile zf = new ZipFile(zipPath);
		try {
			HashSet<String> tops = new HashSet<String>();
			boolean rootFiles = false;
			int total = 0;
			for (Enumeration<? extends ZipEntry> e = zf.entries(); e.hasMoreElements();) {
				ZipEntry z = e.nextElement();
				String n = z.getName().replace('\\', '/');
				if (n.startsWith("__MACOSX/")) continue;
				total++;
				int s = n.indexOf('/');
				if (s < 0) {
					if (!z.isDirectory()) rootFiles = true;
					tops.add(n);
				} else {
					tops.add(n.substring(0, s));
				}
			}
			String base = new File(zipPath).getName();
			int dot = base.lastIndexOf('.');
			if (dot > 0) base = base.substring(0, dot);

			boolean stripMods = !rootFiles && tops.size() == 1 && tops.contains("mods");
			String prefix;
			String modName;
			if (stripMods) {
				prefix = "";
				modName = "(varios)";
			} else if (!rootFiles && tops.size() == 1) {
				prefix = "";
				modName = tops.iterator().next();
			} else {
				modName = sanitize(base);
				prefix = modName + "/";
			}

			File out = new File(modsDir);
			out.mkdirs();
			String outCanon = out.getCanonicalPath() + File.separator;
			byte[] buf = new byte[64 * 1024];
			int done = 0;
			for (Enumeration<? extends ZipEntry> e = zf.entries(); e.hasMoreElements();) {
				ZipEntry z = e.nextElement();
				String n = z.getName().replace('\\', '/');
				if (n.startsWith("__MACOSX/") || n.endsWith(".DS_Store")) continue;
				if (stripMods) {
					if (n.equals("mods/") || n.equals("mods")) continue;
					n = n.substring(5);
				}
				File dest = new File(out, prefix + n);
				if (!dest.getCanonicalPath().startsWith(outCanon)) continue; // protección zip-slip
				if (z.isDirectory()) {
					dest.mkdirs();
				} else {
					File p = dest.getParentFile();
					if (p != null) p.mkdirs();
					InputStream in = zf.getInputStream(z);
					FileOutputStream fo = new FileOutputStream(dest);
					try {
						int r;
						while ((r = in.read(buf)) > 0) fo.write(buf, 0, r);
					} finally {
						fo.close();
						in.close();
					}
				}
				done++;
				if ((done & 15) == 0) unzipState = "running:" + (total == 0 ? 0 : (done * 100 / total));
			}
			return modName;
		} finally {
			zf.close();
		}
	}

	// ------------------------------------------------------------------ varios

	public static void toast(final String msg) {
		final Activity a = Extension.mainActivity;
		if (a == null) return;
		a.runOnUiThread(new Runnable() {
			public void run() { Toast.makeText(a, msg, Toast.LENGTH_SHORT).show(); }
		});
	}

	@SuppressWarnings("deprecation")
	public static void vibrate(int ms) {
		try {
			Vibrator v = (Vibrator) Extension.mainContext.getSystemService(Context.VIBRATOR_SERVICE);
			if (v != null) v.vibrate(ms);
		} catch (Throwable t) { /* sin permiso o sin vibrador */ }
	}
}
