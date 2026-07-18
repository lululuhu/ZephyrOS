/*
 * ZephyrParts — ZephyrBootReceiver
 * 开机完成后启动 ZephyrBootService，应用所有自定义设置。
 */
package com.android.zephyr.parts;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class ZephyrBootReceiver extends BroadcastReceiver {

    private static final String TAG = "ZephyrParts";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            Log.i(TAG, "Boot completed, starting ZephyrBootService");
            Intent service = new Intent(context, ZephyrBootService.class);
            context.startForegroundService(service);
        }
    }
}
