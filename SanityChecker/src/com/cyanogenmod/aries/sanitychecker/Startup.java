package com.cyanogenmod.aries.sanitychecker;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.telephony.TelephonyManager;
import android.util.Log;

public class Startup extends BroadcastReceiver {
    private static final String TAG = "SanityChecker";
    private static final String BAD_IMEI[] = {
        "004999010640000"
    };

    @Override
    public void onReceive(final Context context, final Intent intent) {
        TelephonyManager tm = (TelephonyManager) context.getSystemService(
                Context.TELEPHONY_SERVICE);
        String id = tm.getDeviceId();
        if (tm.getPhoneType() == TelephonyManager.PHONE_TYPE_GSM && !ensureIMEISanity(id)) {
            Log.e(TAG, "Invalid IMEI!");
            warnInvalidIMEI(context);
            return;
        }
        Log.d(TAG, "Device is sane.");
    }

    private boolean ensureIMEISanity(String id) {
        Log.d(TAG, "Current IMEI: " + id);
        for (int j = 0; j < BAD_IMEI.length; j++) {
            if (BAD_IMEI[j].equals(id)) {
                return false;
            }
        }
        return true;
    }

    private void warnInvalidIMEI(Context context) {
        Intent intent = new Intent(context, WarnActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.putExtra(WarnActivity.KEY_REASON, WarnActivity.REASON_INVALID_IMEI);
        context.startActivity(intent);
    }
}
