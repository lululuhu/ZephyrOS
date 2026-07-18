/*
 * ZephyrParts — ZephyrPartsFragment
 * 清风系统主菜单 Fragment。展示 8 大原创功能模块卡片。
 * 点击任一卡片导航到对应子模块的偏好设置页。
 *
 * 所有原创功能入口在此集中，避免与 AOSP 设置应用混淆。
 */
package com.android.zephyr.parts;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.preference.Preference;
import android.preference.PreferenceFragment;
import android.preference.PreferenceScreen;
import android.provider.Settings;
import android.widget.Toast;

public class ZephyrPartsFragment extends PreferenceFragment {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        addPreferencesFromResource(R.xml.preferences);

        // 显示当前清风版本号
        Preference about = findPreference("zephyr_about");
        if (about != null) {
            about.setSummary("ZephyrOS 1.0 · Android 14");
        }
    }

    @Override
    public boolean onPreferenceTreeClick(PreferenceScreen screen, Preference preference) {
        String key = preference.getKey();
        if (key == null) {
            return super.onPreferenceTreeClick(screen, preference);
        }

        int xmlRes = 0;
        int titleRes = 0;

        switch (key) {
            case "zephyr_status":
                xmlRes = R.xml.zephyr_status_prefs;
                titleRes = R.string.zephyr_status_title;
                break;
            case "flow_notify":
                xmlRes = R.xml.flow_notify_prefs;
                titleRes = R.string.flow_notify_title;
                break;
            case "zephyr_gesture":
                xmlRes = R.xml.zephyr_gesture_prefs;
                titleRes = R.string.zephyr_gesture_title;
                break;
            case "immersive_flow":
                xmlRes = R.xml.immersive_flow_prefs;
                titleRes = R.string.immersive_flow_title;
                break;
            case "app_vault":
                xmlRes = R.xml.app_vault_prefs;
                titleRes = R.string.app_vault_title;
                break;
            case "power_core":
                xmlRes = R.xml.power_core_prefs;
                titleRes = R.string.power_core_title;
                break;
            case "privacy_guard":
                xmlRes = R.xml.privacy_guard_prefs;
                titleRes = R.string.privacy_guard_title;
                break;
            case "theme_studio":
                xmlRes = R.xml.theme_studio_prefs;
                titleRes = R.string.theme_studio_title;
                break;
            default:
                return super.onPreferenceTreeClick(screen, preference);
        }

        if (xmlRes != 0 && titleRes != 0) {
            ZephyrSubFragment sub = ZephyrSubFragment.newInstance(xmlRes, titleRes);
            ((SettingsActivity) getActivity()).navigateToSubFragment(sub);
            return true;
        }
        return super.onPreferenceTreeClick(screen, preference);
    }

    /**
     * 子 Fragment 中点击壁纸 / 字体等外部入口时回调.
     * 通过 Intent 调起 ZephyrWallpapers / ZephyrFonts.
     */
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
    }
}
