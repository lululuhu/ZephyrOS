/*
 * ZephyrWallpapers — WallpaperPreviewActivity
 * 全屏预览选定壁纸.
 */
package com.android.zephyr.wallpapers;

import android.app.Activity;
import android.os.Bundle;
import android.view.WindowManager;
import android.widget.ImageView;

public class WallpaperPreviewActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        int resId = getIntent().getIntExtra("wallpaper_res",
                R.drawable.wallpaper_breeze);

        ImageView iv = new ImageView(this);
        iv.setScaleType(ImageView.ScaleType.FIT_CENTER);
        iv.setImageResource(resId);
        setContentView(iv);

        // 全屏沉浸
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS);
    }
}
