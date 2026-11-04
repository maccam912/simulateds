package dev.godotiroh.template;

import android.app.Activity;
import android.content.Context;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

public final class IrohAndroid extends GodotPlugin {
    public IrohAndroid(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "IrohAndroid"; }
    private static native boolean initializeNative(Context context);
    @UsedByGodot public boolean initializeIroh() {
        Activity activity = getActivity();
        if (activity == null) return false;
        try {
            System.loadLibrary("template_iroh.android.arm64");
            return initializeNative(activity.getApplicationContext());
        } catch (LinkageError | RuntimeException error) {
            android.util.Log.e("IrohAndroid", "Unable to initialize Iroh", error);
            return false;
        }
    }
}
