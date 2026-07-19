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
            // 使用普通 startService 而非 startForegroundService, 因为
            // ZephyrBootService 是短任务 (< 1 秒), 不需要前台服务状态.
            // startForegroundService 要求 5 秒内调用 startForeground(),
            // 否则崩溃 ForegroundServiceDidNotStartInTimeException.
            context.startService(service);
        }
    }
}
