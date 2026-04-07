using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;

namespace TimeCapsule.API.Services;

public class FcmNotificationService : IFcmNotificationService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<FcmNotificationService> _logger;
    private readonly bool _firebaseReady;

    public FcmNotificationService(IServiceScopeFactory scopeFactory, ILogger<FcmNotificationService> logger, IConfiguration config)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;

        // Firebase is optional — if no service account path is configured the service
        // gracefully skips sending. This prevents the app from crashing during local dev
        // before Firebase is set up.
        var serviceAccountPath = config["Firebase:ServiceAccountPath"];
        if (string.IsNullOrWhiteSpace(serviceAccountPath) || !File.Exists(serviceAccountPath))
        {
            _logger.LogWarning("Firebase service account not configured. Push notifications disabled. " +
                               "Set Firebase:ServiceAccountPath in appsettings.json to enable.");
            _firebaseReady = false;
            return;
        }

        try
        {
            if (FirebaseApp.DefaultInstance == null)
            {
                FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromFile(serviceAccountPath)
                });
            }
            _firebaseReady = true;
            _logger.LogInformation("Firebase initialized successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Firebase. Push notifications disabled.");
            _firebaseReady = false;
        }
    }

    public async Task SendChatNotificationAsync(Guid receiverId, string senderName, string messagePreview)
    {
        if (!_firebaseReady) return;

        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == receiverId);
        if (user == null || string.IsNullOrWhiteSpace(user.FcmToken))
        {
            _logger.LogDebug("No FCM token for receiver {ReceiverId} — skipping push.", receiverId);
            return;
        }

        // Truncate preview to 100 chars so the notification body is concise.
        var preview = messagePreview.Length > 100
            ? messagePreview[..97] + "..."
            : messagePreview;

        var message = new Message
        {
            Token = user.FcmToken,
            Notification = new Notification
            {
                Title = senderName,
                Body = preview,
            },
            Android = new AndroidConfig
            {
                Priority = Priority.High,
                Notification = new AndroidNotification
                {
                    ChannelId = "chat_channel",
                    Sound = "default",
                    ClickAction = "FLUTTER_NOTIFICATION_CLICK",
                }
            },
            Data = new Dictionary<string, string>
            {
                ["type"] = "chat",
                ["senderId"] = receiverId.ToString(), // used by Flutter to open correct chat
            }
        };

        try
        {
            var messageId = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation("FCM sent to {ReceiverId}: {MessageId}", receiverId, messageId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FCM send failed for receiver {ReceiverId}", receiverId);
        }
    }
}
