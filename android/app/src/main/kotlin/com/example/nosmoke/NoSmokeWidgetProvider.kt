package com.example.nosmoke

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Виджет «дни без сигарет» + кнопка SOS. Данные приходят из Flutter (home_widget). */
class NoSmokeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.nosmoke_widget).apply {
                setTextViewText(R.id.widget_title, widgetData.getString("title", null) ?: "NoSmoke")
                setTextViewText(R.id.widget_value, widgetData.getString("value", null) ?: "—")
                setTextViewText(R.id.widget_unit, widgetData.getString("unit", null) ?: "")
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.getString("subtitle", null) ?: "Открой приложение",
                )
                // Нажатие на виджет открывает приложение, на SOS — экран SOS.
                setOnClickPendingIntent(
                    R.id.widget_container,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setOnClickPendingIntent(
                    R.id.widget_sos,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("nosmoke://sos"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
