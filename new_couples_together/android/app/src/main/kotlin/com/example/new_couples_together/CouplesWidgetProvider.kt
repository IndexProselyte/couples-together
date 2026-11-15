package com.example.new_couples_together

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class CouplesWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.widget_layout)

        // Days counter
        val days = widgetData.getString("days", "0") ?: "0"
        views.setTextViewText(R.id.widget_days, days)

        // Mood label
        val mood = widgetData.getString("mood", "") ?: ""
        views.setTextViewText(R.id.widget_mood, if (mood.isNotEmpty()) "♥ $mood" else "")

        // Couple photo
        val imagePath = widgetData.getString("image_path", null)
        if (imagePath != null) {
            val imgFile = java.io.File(imagePath)
            if (imgFile.exists()) {
                val bitmap = BitmapFactory.decodeFile(imagePath)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, roundCrop(bitmap, 56))
                    views.setViewVisibility(R.id.widget_image, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_image, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.widget_image, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.widget_image, View.GONE)
        }

        // Tap → open app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pendingIntent = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /** Center-crops src to a square and rounds corners at ~15% radius. */
    private fun roundCrop(src: Bitmap, sizeDp: Int): Bitmap {
        val size = minOf(src.width, src.height)
        val x = (src.width - size) / 2
        val y = (src.height - size) / 2
        val cropped = Bitmap.createBitmap(src, x, y, size, size)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
        val radius = size * 0.15f
        canvas.drawRoundRect(rect, radius, radius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(cropped, 0f, 0f, paint)
        return output
    }
}
