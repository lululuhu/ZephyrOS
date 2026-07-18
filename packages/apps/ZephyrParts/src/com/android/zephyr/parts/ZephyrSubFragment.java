/*
 * ZephyrParts — ZephyrSubFragment
 * 通用子模块 PreferenceFragment。
 * 接收一个 XML 资源 ID 与标题，加载对应偏好设置。
 *
 * 通过工厂模式避免为每个模块写一个 Fragment 类。
 * 同时处理跨应用跳转入口（如壁纸）。
 */
package com.android.zephyr.parts;

import android.app.ActionBar;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.preference.Preference;
import android.preference.PreferenceFragment;
import android.preference.PreferenceScreen;
import android.widget.Toast;

public class ZephyrSubFragment extends PreferenceFragment {

    private static final String ARG_XML = "xml_res";
    private static final String ARG_TITLE = "title_res";

    public static ZephyrSubFragment newInstance(int xmlRes, int titleRes) {
        ZephyrSubFragment f = new ZephyrSubFragment();
        Bundle args = new Bundle();
        args.putInt(ARG_XML, xmlRes);
        args.putInt(ARG_TITLE, titleRes);
        f.setArguments(args);
        return f;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Bundle args = getArguments();
        if (args == null) return;

        int titleRes = args.getInt(ARG_TITLE, 0);
        if (titleRes != 0) {
            Activity activity = getActivity();
            if (activity != null) {
                ActionBar ab = activity.getActionBar();
                if (ab != null) ab.setTitle(titleRes);
            }
        }

        int xmlRes = args.getInt(ARG_XML, 0);
        if (xmlRes != 0) {
            addPreferencesFromResource(xmlRes);
        }
    }

    @Override
    public boolean onPreferenceTreeClick(PreferenceScreen screen, Preference preference) {
        String key = preference.getKey();
        if (key == null) return super.onPreferenceTreeClick(screen, preference);

        // 拦截 ThemeStudio 内的壁纸入口, 调起 ZephyrWallpapers
        if ("theme_studio_wallpapers".equals(key)) {
            Intent intent = new Intent("android.intent.action.SET_WALLPAPER");
            intent.setPackage("com.android.zephyr.wallpapers");
            try {
                startActivity(intent);
            } catch (Exception e) {
                // 回退到通用壁纸选择器
                Intent fallback = Intent.createChooser(
                        new Intent(Intent.ACTION_SET_WALLPAPER),
                        getString(R.string.zephyr_wallpapers_entry_title));
                try {
                    startActivity(fallback);
                } catch (Exception ex) {
                    Toast.makeText(getActivity(),
                            "ZephyrWallpapers not available",
                            Toast.LENGTH_SHORT).show();
                }
            }
            return true;
        }
        return super.onPreferenceTreeClick(screen, preference);
    }

    @Override
    public void onResume() {
        super.onResume();
        Bundle args = getArguments();
        if (args != null) {
            int titleRes = args.getInt(ARG_TITLE, 0);
            if (titleRes != 0 && getActivity() != null && getActivity().getActionBar() != null) {
                getActivity().getActionBar().setTitle(titleRes);
            }
        }
    }
}
