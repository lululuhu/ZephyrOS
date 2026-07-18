/*
 * ZephyrParts — SettingsActivity
 * 清风系统自定义设置主入口。
 * 承载主菜单 Fragment 与子 Fragment 之间的导航。
 *
 * 设计原则：
 *   - 单 Activity + 多 Fragment，符合 AOSP 现代设置风格
 *   - 子页面通过 Fragment 回退栈管理
 *   - 平台 PreferenceFragment（系统应用可直接使用，无需 androidx 依赖）
 */
package com.android.zephyr.parts;

import android.app.Activity;
import android.app.Fragment;
import android.os.Bundle;

public class SettingsActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (savedInstanceState == null) {
            getFragmentManager().beginTransaction()
                    .replace(android.R.id.content, new ZephyrPartsFragment())
                    .commit();
        }
    }

    /**
     * 由 ZephyrPartsFragment 调用，跳转到子模块 Fragment。
     */
    public void navigateToSubFragment(Fragment fragment) {
        getFragmentManager().beginTransaction()
                .replace(android.R.id.content, fragment)
                .addToBackStack(null)
                .setTransition(android.app.FragmentTransaction.TRANSIT_FRAGMENT_OPEN)
                .commit();
    }
}
