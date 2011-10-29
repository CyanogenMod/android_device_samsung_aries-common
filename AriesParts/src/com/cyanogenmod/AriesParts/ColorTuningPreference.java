package com.cyanogenmod.AriesParts;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.preference.DialogPreference;
import android.preference.PreferenceManager;
import android.util.AttributeSet;
import android.view.View;
import android.widget.SeekBar;

/**
 * Special preference type that allows configuration of both the ring volume and
 * notification volume.
 */
public class ColorTuningPreference extends DialogPreference {

    enum Colors {
        RED,
        GREEN,
        BLUE
    };

    private static final int[] SEEKBAR_ID = new int[] {
        R.id.color_red_seekbar,
        R.id.color_green_seekbar,
        R.id.color_blue_seekbar
    };

    private static final String[] FILE_PATH = new String[] {
        "/sys/devices/virtual/misc/color_tuning/red_multiplier",
        "/sys/devices/virtual/misc/color_tuning/green_multiplier",
        "/sys/devices/virtual/misc/color_tuning/blue_multiplier"
    };

    private ColorSeekBar mSeekBars[] = new ColorSeekBar[3];

    private static final int MAX_VALUE = Integer.MAX_VALUE;

    // Track instances to know when to restore original color
    // (when the orientation changes, a new dialog is created before the old one is destroyed)
    private static int sInstances = 0;

    public ColorTuningPreference(Context context, AttributeSet attrs) {
        super(context, attrs);

        setDialogLayoutResource(R.layout.preference_dialog_color_tuning);
    }

    @Override
    protected void onBindDialogView(View view) {
        super.onBindDialogView(view);

        sInstances++;

        for (int i = 0; i < SEEKBAR_ID.length; i++) {
            SeekBar seekBar = (SeekBar) view.findViewById(SEEKBAR_ID[i]);
            mSeekBars[i] = new ColorSeekBar(seekBar, FILE_PATH[i]);
        }
    }

    @Override
    protected void onDialogClosed(boolean positiveResult) {
        super.onDialogClosed(positiveResult);

        sInstances--;

        if (positiveResult) {
            for (ColorSeekBar csb : mSeekBars) {
                csb.save();
            }
        } else if (sInstances == 0) {
            for (ColorSeekBar csb : mSeekBars) {
                csb.reset();
            }
        }
    }

    /**
     * Restore screen color tuning from SharedPreferences. (Write to kernel.)
     * @param context       The context to read the SharedPreferences from
     */
    public static void restore(Context context) {
        if (!isSupported()) {
            return;
        }

        SharedPreferences sharedPrefs = PreferenceManager.getDefaultSharedPreferences(context);
        for (String filePath : FILE_PATH) {
            int value = sharedPrefs.getInt(filePath, MAX_VALUE);
            Utils.writeColor(filePath, value);
        }
    }

    /**
     * Check whether the running kernel supports color tuning or not.
     * @return              Whether color tuning is supported or not
     */
    public static boolean isSupported() {
        boolean supported = true;
        for (String filePath : FILE_PATH) {
            if (!Utils.fileExists(filePath)) {
                supported = false;
            }
        }

        return supported;
    }

    class ColorSeekBar implements SeekBar.OnSeekBarChangeListener {

        private String mFilePath;
        private int mOriginal;
        private SeekBar mSeekBar;

        public ColorSeekBar(SeekBar seekBar, String filePath) {
            mSeekBar = seekBar;
            mFilePath = filePath;

            // Read original value
            SharedPreferences sharedPreferences = getSharedPreferences();
            mOriginal = sharedPreferences.getInt(mFilePath, MAX_VALUE);

            seekBar.setMax(MAX_VALUE);
            reset();
            seekBar.setOnSeekBarChangeListener(this);
        }

        public void reset() {
            mSeekBar.setProgress(mOriginal);
        }

        public void save() {
            Editor editor = getEditor();
            editor.putInt(mFilePath, mSeekBar.getProgress());
            editor.commit();
        }

        @Override
        public void onProgressChanged(SeekBar seekBar, int progress,
                boolean fromUser) {
            Utils.writeColor(mFilePath, progress);
        }

        @Override
        public void onStartTrackingTouch(SeekBar seekBar) {
            // Do nothing
        }

        @Override
        public void onStopTrackingTouch(SeekBar seekBar) {
            // Do nothing
        }

    }

}
