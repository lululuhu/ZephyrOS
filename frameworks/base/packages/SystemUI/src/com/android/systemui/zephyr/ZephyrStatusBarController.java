/*
 * ZephyrStatusBarController
 * =========================
 * ZephyrOS 原创状态栏控制器. 注入 SystemUI CentralSurfaces,
 * 监听 Settings.System.zephyr_status_* 变化并应用配置.
 *
 * 设计:
 *   - 不修改 AOSP 原生 StatusBar / CentralSurfaces 类
 *   - 作为独立 controller 通过 CentralSurfaces 注入
 *   - 通过 SettingsObserver 实时响应设置变化
 *
 * 注入位置: frameworks/base/packages/SystemUI/.../CentralSurfaces.java
 *           在 startCoreServices() 中 new ZephyrStatusBarController(mContext)
 */
package com.android.systemui.zephyr;

import android.content.Context;
import android.database.ContentObserver;
import android.net.Uri;
import android.os.Handler;
import android.os.UserHandle;
import android.provider.Settings;
import android.util.Log;

/**
 * 监听 ZephyrOS 状态栏设置并应用到 SystemUI.
 *
 * 监听的设置项:
 *   - zephyr_status_net_speed     : 网速胶囊开关
 *   - zephyr_status_capsule       : 清风胶囊通知预览开关
 *   - zephyr_status_clock_pos     : 时钟位置 (0=左/1=中/2=右)
 *   - zephyr_status_battery_style : 电池样式 (0=横/1=圆/2=隐藏)
 */
public class ZephyrStatusBarController {

    private static final String TAG = "ZephyrStatusBar";
    private static final boolean DEBUG = false;

    private final Context mContext;
    private final Handler mHandler;

    public ZephyrStatusBarController(Context context) {
        mContext = context;
        mHandler = new Handler(mContext.getMainLooper());
    }

    /**
     * 启动监听. 由 CentralSurfaces.startCoreServices() 调用.
     */
    public void start() {
        if (DEBUG) Log.d(TAG, "ZephyrStatusBarController starting...");

        ZephyrSettingsObserver observer = new ZephyrSettingsObserver(mHandler);
        for (String key : new String[]{
                "zephyr_status_net_speed",
                "zephyr_status_capsule",
                "zephyr_status_clock_pos",
                "zephyr_status_battery_style",
        }) {
            mContext.getContentResolver().registerContentObserver(
                    Settings.System.getUriFor(key),
                    false, observer, UserHandle.USER_ALL);
        }

        // 应用初始配置
        applyAll();
    }

    private void applyAll() {
        applyNetSpeedChip();
        applyCapsule();
        applyClockPosition();
        applyBatteryStyle();
    }

    // ---------------- 网速胶囊 ----------------
    private void applyNetSpeedChip() {
        boolean enabled = Settings.System.getInt(
                mContext.getContentResolver(),
                "zephyr_status_net_speed", 1) == 1;
        if (DEBUG) Log.d(TAG, "Net speed chip: " + enabled);
        // TODO: 注入到 StatusBarIconController 的左侧 slot
        // 实际实现需在 StatusBarIconList 中注册一个 ZephyrNetSpeedChip
    }

    // ---------------- 清风胶囊 ----------------
    private void applyCapsule() {
        boolean enabled = Settings.System.getInt(
                mContext.getContentResolver(),
                "zephyr_status_capsule", 1) == 1;
        if (DEBUG) Log.d(TAG, "Capsule notify: " + enabled);
        // TODO: 注入 HeadsUpManager 的预览层
    }

    // ---------------- 时钟位置 ----------------
    private void applyClockPosition() {
        int pos = Settings.System.getInt(
                mContext.getContentResolver(),
                "zephyr_status_clock_pos", 1);
        if (DEBUG) Log.d(TAG, "Clock position: " + pos);
        // TODO: 通过 ClockController 调整 LayoutGravity
    }

    // ---------------- 电池样式 ----------------
    private void applyBatteryStyle() {
        int style = Settings.System.getInt(
                mContext.getContentResolver(),
                "zephyr_status_battery_style", 0);
        if (DEBUG) Log.d(TAG, "Battery style: " + style);
        // TODO: 切换 BatteryMeterView 的 drawable
    }

    private class ZephyrSettingsObserver extends ContentObserver {
        ZephyrSettingsObserver(Handler handler) {
            super(handler);
        }

        @Override
        public void onChange(boolean selfChange, Uri uri) {
            String key = uri == null ? null : uri.getLastPathSegment();
            if (DEBUG) Log.d(TAG, "Setting changed: " + key);
            if (key == null) {
                applyAll();
                return;
            }
            switch (key) {
                case "zephyr_status_net_speed":     applyNetSpeedChip(); break;
                case "zephyr_status_capsule":       applyCapsule(); break;
                case "zephyr_status_clock_pos":     applyClockPosition(); break;
                case "zephyr_status_battery_style": applyBatteryStyle(); break;
            }
        }
    }
}
