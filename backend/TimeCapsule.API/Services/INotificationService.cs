namespace TimeCapsule.API.Services;

public class NotificationDto
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid ActorId { get; set; }
    public string ActorName { get; set; } = string.Empty;
    public string? ActorProfilePictureUrl { get; set; }
    public string Type { get; set; } = string.Empty;
    public Guid? ReferenceId { get; set; }
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; }
}

public interface INotificationService
{
    Task<List<NotificationDto>> GetNotificationsAsync(Guid userId, int page, int pageSize);
    Task<int> GetUnreadCountAsync(Guid userId);
    Task MarkAsReadAsync(Guid userId, Guid notificationId);
    Task MarkAllAsReadAsync(Guid userId);
    Task CreateNotificationAsync(Guid userId, Guid actorId, string type, string message, Guid? referenceId = null);
    Task DeleteNotificationAsync(Guid userId, Guid notificationId);
}
