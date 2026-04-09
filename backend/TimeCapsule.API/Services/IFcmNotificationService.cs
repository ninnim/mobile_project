namespace TimeCapsule.API.Services;

public interface IFcmNotificationService
{
    /// <summary>
    /// Sends a push notification to the receiver if they have an FCM token registered.
    /// Safe to call even when Firebase is not configured — it will log a warning and skip.
    /// </summary>
    Task SendChatNotificationAsync(Guid receiverId, Guid senderId, string senderName, string messagePreview);
}
