/*
 * ZephyrGestureController
 * =======================
 * ZephyrOS 原创手势控制器. 注入 SystemUI (EdgeBackGestureHandler 邻接),
 * 监听 Settings.System.zephyr_gesture_* 与 SystemProperties 持久化配置.
 *
 * 设计:
 *   - 不修改 AOSP 原生 EdgeBackGestureHandler
 *   - 通过 SystemProperties 注入灵敏度参数
 *   - 三指截屏通过 InputManagerService 钩子识别
 *
 * 注入位置: frameworks/base/services/core/.../InputManagerService.java
 *           或 SystemUI 的 NavigationBarTransitions
 */
package com.android.systemui.zephyr;

import android.content.Context;
import android.os.SystemProperties;
import android.provider.Settings;
import android.util.Log;

/**
 * 应用 ZephyrGesture 设置到系统层.
 *
 * 涉及的设置项:
 *   - persist.zephyr.edge_swipe     : 边缘滑动灵敏度 (0-4)
 *   - persist.zephyr.three_finger_ss: 三指截屏开关
 *   - zephyr_gesture_one_handed_*  : 单手模式触发
 */
public class ZephyrGestureController {

    private static final String TAG = "ZephyrGesture";
    private static final boolean DEBUG = false;

    private final Context mContext;

    public ZephyrGestureController(Context context) {
        mContext = context;
    }

    /**
     * 启动控制器. 在 SystemUI 启动时调用.
     */
    public void start() {
        applyEdgeSwipeSensitivity();
        applyThreeFingerScreenshot();
        applyOneHandedMode();
    }

    // ---------------- 边缘滑动灵敏度 ----------------
    // 灵敏度档位 0-4, 影响 EdgeBackGestureHandler 的边缘检测宽度
    // 0 = 24dp (最低) ... 4 = 48dp (最高)
    private void applyEdgeSwipeSensitivity() {
        int sensitivity = SystemProperties.getInt("persist.zephyr.edge_swipe", 2);
        int widthDp;
        switch (sensitivity) {
            case 0:  widthDp = 24; break;  // 最低灵敏度 (需更靠边缘)
            case 1:  widthDp = 32; break;
            case 2:  widthDp = 40; break;  // 默认中档
            case 3:  widthDp = 48; break;
            case 4:  widthDp = 56; break;  // 最高灵敏度 (远距离即可触发)
            default: widthDp = 40;
        }
        if (DEBUG) Log.d(TAG, "Edge swipe sensitivity=" + sensitivity
                + " width=" + widthDp + "dp");
        // 通过 SystemProperties 暴露给 EdgeBackGestureHandler
        // (handler 侧需要 patch 读取该属性)
        SystemProperties.set("persist.zephyr.edge_swipe_width_dp",
                String.valueOf(widthDp));
    }

    // ---------------- 三指截屏 ----------------
    private void applyThreeFingerScreenshot() {
        boolean enabled = "1".equals(
                SystemProperties.get("persist.zephyr.three_finger_ss", "1"));
        if (DEBUG) Log.d(TAG, "Three finger screenshot: " + enabled);
        // 注册 InputManager 的手势监听器
        // 实际实现需 patch InputManagerService 识别三指下滑事件
    }

    // ---------------- 单手模式 ----------------
    private void applyOneHandedMode() {
        boolean leftEnabled = Settings.System.getInt(
                mContext.getContentResolver(),
                "zephyr_gesture_one_handed_left", 1) == 1;
        boolean rightEnabled = Settings.System.getInt(
                mContext.getContentResolver(),
                "zephyr_gesture_one_handed_right", 1) == 1;
        if (DEBUG) Log.d(TAG, "One-handed: L=" + leftEnabled + " R=" + rightEnabled);
        // 通知 OneHandedController 启用对应方向
    }
}
