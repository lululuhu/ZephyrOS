/*
 * ZephyrParts — ZephyrBootService
 * 开机后应用所有清风自定义设置到 SystemUI 与 Framework。
 *
 * 此服务读取 SharedPreferences（由各 PreferenceFragment 写入），
 * 通过 SystemUI 钩子接口下发配置。具体框架层钩子位于
 * frameworks/base/patches/ 中的 SystemUI 补丁。
 *
 * 本服务仅负责"读偏好 → 调钩子"的编排，不包含具体功能实现。
 */
package com.android.zephyr.parts;

import android.app.Service;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.IBinder;
import android.os.SystemProperties;
import android.provider.Settings;
import android.util.Log;

public class ZephyrBootService extends Service {

    private static final String TAG = "ZephyrParts";
    private static final String PREFS = "zephyr_prefs";

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i(TAG, "Applying ZephyrOS customizations...");

        SharedPreferences prefs = getSharedPreferences(PREFS, 0);

        applyStatusBarSettings(prefs);
        applyGestureSettings(prefs);
        applyPrivacySettings(prefs);

        Log.i(TAG, "ZephyrOS customizations applied.");
        stopSelf();
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    // ---------------- 状态栏 ----------------
    private void applyStatusBarSettings(SharedPreferences prefs) {
        // 网速胶囊开关
        boolean netSpeed = prefs.getBoolean("zephyr_status_net_speed", true);
        Settings.System.putInt(getContentResolver(),
                "zephyr_status_net_speed", netSpeed ? 1 : 0);

        // 清风胶囊
        boolean capsule = prefs.getBoolean("zephyr_status_capsule", true);
        Settings.System.putInt(getContentResolver(),
                "zephyr_status_capsule", capsule ? 1 : 0);

        // 时钟位置
        int clockPos = prefs.getInt("zephyr_status_clock_pos", 1);
        Settings.System.putInt(getContentResolver(),
                "zephyr_status_clock_pos", clockPos);

        Log.i(TAG, "Status bar settings applied.");
    }

    // ---------------- 手势 ----------------
    private void applyGestureSettings(SharedPreferences prefs) {
        // 边缘滑动灵敏度 0-4
        int sensitivity = prefs.getInt("zephyr_gesture_edge_swipe", 2);
        SystemProperties.set("persist.zephyr.edge_swipe", String.valueOf(sensitivity));

        // 三指截屏
        boolean threeFinger = prefs.getBoolean("zephyr_gesture_three_finger_screenshot", true);
        SystemProperties.set("persist.zephyr.three_finger_ss",
                threeFinger ? "1" : "0");

        Log.i(TAG, "Gesture settings applied.");
    }

    // ---------------- 隐私 ----------------
    private void applyPrivacySettings(SharedPreferences prefs) {
        // 摄像头/麦克风指示器
        boolean camInd = prefs.getBoolean("privacy_guard_cam_indicator", true);
        Settings.System.putInt(getContentResolver(),
                "zephyr_privacy_cam_indicator", camInd ? 1 : 0);

        // 剪贴板访问提醒
        boolean clipAlert = prefs.getBoolean("privacy_guard_clipboard_alert", true);
        Settings.System.putInt(getContentResolver(),
                "zephyr_privacy_clipboard_alert", clipAlert ? 1 : 0);

        Log.i(TAG, "Privacy settings applied.");
    }
}
