package cm.iutdouala.boutik_ecole

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        creerCanalNotifications()
    }

    // Canal par défaut des notifications push (référencé dans AndroidManifest.xml) : sans lui, Android 8+ utilise un canal de priorité moyenne.
    private fun creerCanalNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val canal = NotificationChannel("boutik_notifications", "Notifications Boutik-École", NotificationManager.IMPORTANCE_HIGH)
        canal.description = "Messages, commandes, paiements et alertes de votre compte."
        manager.createNotificationChannel(canal)
    }
}
