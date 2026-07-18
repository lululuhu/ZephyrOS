/*
 * ZephyrWallpapers — WallpaperPickerActivity
 * 展示 6 张原创壁纸供用户选择.
 */
package com.android.zephyr.wallpapers;

import android.app.Activity;
import android.app.WallpaperManager;
import android.content.Intent;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.Toast;

public class WallpaperPickerActivity extends Activity {

    // 原创壁纸资源 ID 列表
    private static final int[] WALLPAPERS = new int[]{
            R.drawable.wallpaper_breeze,
            R.drawable.wallpaper_grove,
            R.drawable.wallpaper_steam,
            R.drawable.wallpaper_dewdrop,
            R.drawable.wallpaper_horizon,
            R.drawable.wallpaper_mint,
    };

    private static final int[] WALLPAPER_NAMES = new int[]{
            R.string.wallpaper_breeze,
            R.string.wallpaper_grove,
            R.string.wallpaper_steam,
            R.string.wallpaper_dewdrop,
            R.string.wallpaper_horizon,
            R.string.wallpaper_mint,
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        GridView grid = new GridView(this);
        grid.setNumColumns(2);
        grid.setPadding(32, 32, 32, 32);
        grid.setHorizontalSpacing(32);
        grid.setVerticalSpacing(32);
        grid.setGravity(Gravity.CENTER);
        grid.setAdapter(new WallpaperAdapter());

        setContentView(grid);
    }

    private class WallpaperAdapter extends BaseAdapter {
        @Override
        public int getCount() {
            return WALLPAPERS.length;
        }

        @Override
        public Object getItem(int position) {
            return WALLPAPERS[position];
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            ImageView iv;
            if (convertView instanceof ImageView) {
                iv = (ImageView) convertView;
            } else {
                iv = new ImageView(parent.getContext());
                int size = (parent.getWidth() > 0 ? parent.getWidth() / 2 : 480) - 48;
                iv.setLayoutParams(new GridView.LayoutParams(size, size * 1920 / 1080));
                iv.setScaleType(ImageView.ScaleType.FIT_CENTER);
                iv.setPadding(8, 8, 8, 8);
                iv.setBackgroundResource(0xFFFFFFFF);
            }

            final int resId = WALLPAPERS[position];
            Drawable d = getResources().getDrawable(resId, getTheme());
            iv.setImageDrawable(d);
            iv.setContentDescription(getString(WALLPAPER_NAMES[position]));

            iv.setOnClickListener(v -> applyWallpaper(resId,
                    WALLPAPER_NAMES[position]));

            return iv;
        }
    }

    private void applyWallpaper(int resId, int nameRes) {
        WallpaperManager wm = WallpaperManager.getInstance(this);
        try {
            // 仅设主屏壁纸
            wm.setResource(resId);
            Toast.makeText(this,
                    getString(R.string.zephyr_wallpaper_apply) + ": " + getString(nameRes),
                    Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Toast.makeText(this, "Failed: " + e.getMessage(),
                    Toast.LENGTH_LONG).show();
        }
    }
}
